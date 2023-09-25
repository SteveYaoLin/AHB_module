//------------------------------------------------------------------------------
// File                     : sram_ctrl_if.v
// Author                   : TG
// Key Words                :
// Modification History     :
//      Date        By        Version        Change Description
//      2021-12-06  TG        1.0            original
//
// Editor                   : VSCode, Tab Size(4)
// Description              :
//
//------------------------------------------------------------------------------
`timescale 1ns / 1ps

module sram_ctrl_if #( 
    parameter                       AHB_DWIDTH = 32,
    parameter                       ADD_WIDTH = 11,
    parameter                       SYNC_RESET = 0
)
(
    //----------------------------------
    // IO Declarations
    //----------------------------------
    // Inputs
    input                           HCLK,
    input                           HRESETN,

    input                           ahbsram_req,
    input                           ahbsram_write,
    input [2:0]                     ahbsram_size,
    input [ADD_WIDTH-1:0]           ahbsram_addr,
    input [AHB_DWIDTH-1:0]          ahbsram_wdata,
    
    // Outputs
    output                          sramahb_ack,
    output reg [AHB_DWIDTH-1: 0]    sramahb_rdata
);

    //----------------------------------
    // Local Parameter Declarations
    //----------------------------------
    // State Machine parameters
    localparam                      S_IDLE = 2'b00;
    localparam                      S_WR = 2'b01;
    localparam                      S_RD = 2'b10;

    //----------------------------------
    // Variable Declarations
    //----------------------------------
    reg [3:0]                       sram_wen_mem;
    reg [1:0]                       sramcurr_state;
    reg [1:0]                       sramnext_state;
    reg                             sram_wen;
    reg                             sram_ren;
    reg                             sramahb_ack_int;
    reg                             sram_ren_d;
    reg                             sram_done;   
    wire [AHB_DWIDTH-1:0]           ram_rdata;

    wire                            aresetn;
    wire                            sresetn; 

    //----------------------------------
    // Start of Main Code
    //----------------------------------
    assign aresetn = (SYNC_RESET == 1) ? 1'b1 : HRESETN;
    assign sresetn = (SYNC_RESET == 1) ? HRESETN : 1'b1;

    // Current State generation
    always @(posedge HCLK or negedge aresetn) 
    begin
        if ((aresetn == 1'b0) || (sresetn == 1'b0)) begin
            sramcurr_state <= S_IDLE;
        end
        else begin
            sramcurr_state <= sramnext_state;
        end
    end
    
    // Next State and output decoder logic
    always @(*) 
    begin
        sramahb_ack_int = 1'b0;
        sram_wen = 1'b0;
        sram_ren = 1'b0;
        sramnext_state = sramcurr_state;
        case (sramcurr_state)
            S_IDLE : begin
                if (ahbsram_req == 1'b1) begin
                    if (ahbsram_write == 1'b1) begin
                        sramnext_state = S_WR;           
                        sram_wen = 1'b1;
                    end
                    else begin
                        sram_ren = 1'b1;
                        sramnext_state = S_RD;           
                    end
                end
            end

            S_WR : begin
                if (sram_done == 1'b1) begin
                    sramnext_state = S_IDLE;
                    sramahb_ack_int = 1'b1;
                end
            end
            
            S_RD : begin
                if (sram_done == 1'b1) begin
                    sramnext_state = S_IDLE;
                    sramahb_ack_int = 1'b1;
                end
            end

            default : begin
                sramnext_state = S_IDLE;
            end
        endcase     
    end
    
    always @(*) 
    begin
        sram_wen_mem = 4'b0000;
        if (ahbsram_size == 3'b010) begin
            sram_wen_mem = {4{sram_wen}};
        end
        else if (ahbsram_size == 3'b001) begin
            case (ahbsram_addr[1])
                1'b0 : begin
                    sram_wen_mem[0] = sram_wen;
                    sram_wen_mem[1] = sram_wen;
                    sram_wen_mem[2] = 1'b0;
                    sram_wen_mem[3] = 1'b0;
                end
                1'b1 : begin
                    sram_wen_mem[0] = 1'b0;
                    sram_wen_mem[1] = 1'b0;
                    sram_wen_mem[2] = sram_wen;
                    sram_wen_mem[3] = sram_wen;
                end
            endcase      
        end     
        else if (ahbsram_size == 3'b000) begin
            case (ahbsram_addr[1:0])
                2'b00 : begin
                    sram_wen_mem[0] = sram_wen;
                    sram_wen_mem[1] = 1'b0;
                    sram_wen_mem[2] = 1'b0;
                    sram_wen_mem[3] = 1'b0;
                end
                2'b01 : begin
                    sram_wen_mem[0] = 1'b0;
                    sram_wen_mem[1] = sram_wen;
                    sram_wen_mem[2] = 1'b0;
                    sram_wen_mem[3] = 1'b0;
                end
                2'b10 : begin
                    sram_wen_mem[0] = 1'b0;
                    sram_wen_mem[1] = 1'b0;
                    sram_wen_mem[2] = sram_wen;
                    sram_wen_mem[3] = 1'b0;
                end
                2'b11 : begin
                    sram_wen_mem[0] = 1'b0;
                    sram_wen_mem[1] = 1'b0;
                    sram_wen_mem[2] = 1'b0;
                    sram_wen_mem[3] = sram_wen;
                end
            endcase       
        end
        else begin
            sram_wen_mem = {4{sram_wen}};
        end             
    end

    // SRAM Instantiations
    sram_model #(
        .SYNC_RESET                 (SYNC_RESET),
        .ADDR_WIDTH                 (ADD_WIDTH)
    )
    u_sram_model (
        .writedata                  (ahbsram_wdata),
        .readdata                   (ram_rdata[31:0]),
        .wren                       (sram_wen_mem),
        .rden                       (sram_ren),
        .writeaddr                  (ahbsram_addr[ADD_WIDTH-1:2]),
        .readaddr                   (ahbsram_addr[ADD_WIDTH-1:2]),
        .clk                        (HCLK),
        .resetn                     (HRESETN)
    );

    always @(posedge HCLK or negedge aresetn) 
    begin
        if ((aresetn == 1'b0) || (sresetn == 1'b0)) begin
            sramahb_rdata <= 32'h0;
        end
        else if (sram_ren_d == 1'b1) begin
            sramahb_rdata <= ram_rdata;
        end
        else begin
            sramahb_rdata <= sramahb_rdata;
        end
    end

    always @(posedge HCLK or negedge aresetn) 
    begin
        if ((aresetn == 1'b0) || (sresetn == 1'b0)) begin
            sram_ren_d <= 32'h0;
        end
        else begin
            sram_ren_d <= sram_ren;
        end
    end

    // Generate the SRAM done when the SRAM wren/rden is done
    always @(posedge HCLK or negedge aresetn) 
    begin
        if ((aresetn == 1'b0) || (sresetn == 1'b0)) begin
            sram_done <= 1'b0;
        end
        else if (sram_wen || sram_ren) begin
            sram_done <= 1'b1;
        end
        else begin
            sram_done <= 1'b0;
        end
    end

    // Generate the SRAM ack 
    assign sramahb_ack = sramahb_ack_int;

endmodule
