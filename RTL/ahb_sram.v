//------------------------------------------------------------------------------
// File                     : ahb_sram.v
// Author                   : TG
// Key Words                :
// Modification History     :
//      Date        By        Version        Change Description
//      2021-12-05  TG        1.0            original
//
// Editor                   : VSCode, Tab Size(4)
// Description              : Top Module of AHB SRAM Controller.
//
//------------------------------------------------------------------------------
`timescale 1ns / 1ps

module ahb_sram #( 
    parameter                       SYNC_RESET = 1,
    parameter                       AHB_DWIDTH = 32,
    parameter                       AHB_AWIDTH = 32,
    parameter 		            SIZE_IN_BYTES = 2048,
    parameter                       ADD_WIDTH = $clog2(SIZE_IN_BYTES)   
)
(
    //----------------------------------
    // IO Declarations
    //----------------------------------
    // Inputs
    input                           HCLK,
    input                           HRESETN,
    input                           HSEL,
    input                           HREADYIN,
    input [1:0]                     HTRANS,
    input [2:0]                     HBURST,
    input [2:0]                     HSIZE,
    input [AHB_DWIDTH-1:0]          HWDATA,
    input [AHB_AWIDTH-1:0]          HADDR,
    input                           HWRITE,
    // Outputs
    output [AHB_DWIDTH-1:0]         HRDATA,
    output [1:0]                    HRESP,
    output                          HREADYOUT
);

    //----------------------------------
    // Variable Declarations
    //----------------------------------
    wire [ADD_WIDTH-1:0]            HADDR_cal;
    wire [2:0]                      ahbsram_size;
    wire [ADD_WIDTH-1:0]            ahbsram_addr;
    wire [31:0]                     ahbsram_wdata;
    wire                            ahbsram_write;
    wire [31:0]                     sramahb_rdata;
    wire                            sramahb_ack;

    //----------------------------------
    // Start of Main Code
    //----------------------------------
    assign HADDR_cal = HADDR[ADD_WIDTH-1:0];

    // Instantiations
    ahb_sram_if #(
        .AHB_DWIDTH                 (AHB_DWIDTH),
        .AHB_AWIDTH                 (AHB_AWIDTH),
        .ADD_WIDTH                  (ADD_WIDTH), 
        .SYNC_RESET                 (SYNC_RESET)
    )       
    u_ahb_sram_if (        
        .HCLK                       (HCLK),
        .HRESETN                    (HRESETN),
        .HSEL                       (HSEL),
        .HTRANS                     (HTRANS),
        .HBURST                     (HBURST),
        .HWRITE                     (HWRITE),
        .HWDATA                     (HWDATA),
        .HSIZE                      (HSIZE),
        .HADDR                      (HADDR_cal),
        .HREADYIN                   (HREADYIN),
        // From SRAM Control signals
        .sramahb_ack                (sramahb_ack),
        .sramahb_rdata              (sramahb_rdata),
        // Outputs      
        .HREADYOUT                  (HREADYOUT),
        .HRESP                      (HRESP),
        // To SRAM Control signals
        .ahbsram_req                (ahbsram_req),
        .ahbsram_write              (ahbsram_write),
        .ahbsram_wdata              (ahbsram_wdata),
        .ahbsram_size               (ahbsram_size),
        .ahbsram_addr               (ahbsram_addr),
        .HRDATA                     (HRDATA)
    );

    sram_ctrl_if #(
        .ADD_WIDTH                  (ADD_WIDTH),
        .SYNC_RESET                 (SYNC_RESET)
    )       
    u_sram_ctrl_if (     
        .HCLK                       (HCLK),
        .HRESETN                    (HRESETN),
        // From AHB Interface signals
        .ahbsram_req                (ahbsram_req),
        .ahbsram_write              (ahbsram_write),
        .ahbsram_wdata              (ahbsram_wdata),
        .ahbsram_size               (ahbsram_size),
        .ahbsram_addr               (ahbsram_addr),
        // Outputs
        // To AHB Interface signals
        .sramahb_ack                (sramahb_ack),
        .sramahb_rdata              (sramahb_rdata)
    );

endmodule

//------------------------------------------------------------------------------
// File                     : ahb_sram_if.v
// Author                   : TG
// Key Words                :
// Modification History     :
//      Date        By        Version        Change Description
//      2021-12-05  TG        1.0            original
//
// Editor                   : VSCode, Tab Size(4)
// Description              :
//
//------------------------------------------------------------------------------
`timescale 1ns / 1ps

module ahb_sram_if #( 
    parameter                       AHB_DWIDTH = 32,
    parameter                       AHB_AWIDTH = 32,
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
    input                           HSEL,
    input                           HREADYIN,
    input [1:0]                     HTRANS,
    input [2:0]                     HBURST,
    input [2:0]                     HSIZE,
    input [ADD_WIDTH-1:0]           HADDR,
    input [AHB_DWIDTH-1:0]          HWDATA,
    input                           HWRITE,
    input                           sramahb_ack,
    input [AHB_DWIDTH-1:0]          sramahb_rdata,
    // Outputs
    output                          HREADYOUT,
    output [1:0]                    HRESP,
    output reg [AHB_DWIDTH-1:0]     HRDATA,
    
    output                          ahbsram_req,
    output                          ahbsram_write,
    output [AHB_AWIDTH-1:0]         ahbsram_wdata,
    
    output [2:0]                    ahbsram_size,
    output [ADD_WIDTH-1:0]          ahbsram_addr
);

    //----------------------------------
    // Local Parameter Declarations
    //----------------------------------
    // State Machine parameters
    localparam                      IDLE = 2'b00;
    localparam                      AHB_WR = 2'b01;
    localparam                      AHB_RD = 2'b10;

    parameter                       RESP_OKAY = 2'b00;
    parameter                       RESP_ERROR = 2'b01;

    // AHB HTRANS definition
    parameter                       TRN_IDLE = 2'b00;
    parameter                       TRN_BUSY = 2'b01;
    parameter                       TRN_SEQ = 2'b11;
    parameter                       TRN_NONSEQ = 2'b10;

    parameter                       SINGLE = 3'b000;
    parameter                       INCR = 3'b001;
    parameter                       WRAP4 = 3'b010;
    parameter                       INCR4 = 3'b011;
    parameter                       WRAP8 = 3'b100;
    parameter                       INCR8 = 3'b101;
    parameter                       WRAP16 = 3'b110;
    parameter                       INCR16 = 3'b111;

    //----------------------------------
    // Variable Declarations
    //----------------------------------
    reg [1:0]                       HTRANS_d;
    reg [2:0]                       HBURST_d;
    reg [2:0]                       HSIZE_d;
    reg [ADD_WIDTH-1:0]             HADDR_d;
    reg [AHB_DWIDTH-1:0]            HWDATA_d;
    reg                             HWRITE_d;
    reg                             HSEL_d;
    reg                             HREADYIN_d;
    reg [1:0]                       ahbcurr_state;
    reg [1:0]                       ahbnext_state;

    reg                             latchahbcmd;
    reg                             ahbsram_req_int;
    reg                             ahbsram_req_d1;   
    reg [AHB_DWIDTH-1:0]            HWDATA_cal;

    reg [4:0]                       burst_count;
    reg [4:0]                       burst_count_reg;
    reg [4:0]                       count;

    wire                            aresetn;
    wire                            sresetn;

    //----------------------------------
    // Start of Main Code
    //----------------------------------
    assign aresetn = (SYNC_RESET==1) ? 1'b1 : HRESETN;
    assign sresetn = (SYNC_RESET==1) ? HRESETN : 1'b1;

    // Generation of valid AHB Command which triggers the AHB Slave State Machine
    assign validahbcmd = HREADYIN & HSEL & (HTRANS == TRN_NONSEQ);

    // Generation of HRESP
    assign HRESP = RESP_OKAY;

    always @(*) 
    begin
        HWDATA_cal = HWDATA;
    end
    
    // Latch all the AHB signals
    always @(posedge HCLK or negedge aresetn) 
    begin
        if ((aresetn == 1'b0) || (sresetn == 1'b0)) begin
            HADDR_d    <= {20{1'b0}};
            HWDATA_d   <= {32{1'b0}};
            HTRANS_d   <= 2'b00;
            HSIZE_d    <= 2'b00;
            HBURST_d   <= 3'b000;
            HWRITE_d   <= 1'b0;
            HSEL_d     <= 1'b0;
            HREADYIN_d <= 1'b0;
        end
        else if (HREADYIN == 1'b1 & HSEL == 1'b1 & HREADYOUT == 1'b1) begin
            HADDR_d    <= HADDR;
            HTRANS_d   <= HTRANS;
            HSIZE_d    <= HSIZE;
            HBURST_d   <= HBURST;
            HWRITE_d   <= HWRITE;
            HWDATA_d   <= HWDATA_cal;         
            HSEL_d     <= HSEL;
            HREADYIN_d <= HREADYIN;
        end
    end
    
    // Current State generation
    always @(posedge HCLK or negedge aresetn) 
    begin
        if ((aresetn == 1'b0) || (sresetn == 1'b0)) begin
            ahbcurr_state <= IDLE;
        end
        else begin
            ahbcurr_state <= ahbnext_state;
        end
    end
    
    // Next State and output decoder logic
    always @(*) 
    begin
        latchahbcmd = 1'b0;
        ahbsram_req_int = 1'b0;
        ahbnext_state = ahbcurr_state;
        
        case (ahbcurr_state)
            IDLE : begin
                if (HREADYIN == 1'b1 && HSEL == 1'b1 && ((HTRANS == TRN_NONSEQ) || HTRANS == TRN_SEQ)) begin
                    latchahbcmd = 1'b1;
                    if (HWRITE == 1'b1) begin
                        ahbnext_state = AHB_WR;           
                    end 
                    else begin
                        ahbnext_state = AHB_RD;           
                    end
                end 
                else begin
                    ahbnext_state = IDLE;           
                end
            end

            AHB_WR : begin
                latchahbcmd = 1'b0;
                ahbsram_req_int = 1'b1;
                
                if (sramahb_ack == 1'b1) begin
                    if (count == burst_count_reg) begin
                        ahbnext_state = IDLE;
                    end 
                    else begin
                        ahbsram_req_int = 1'b0;
                    end
                end

            end
            
            AHB_RD : begin
                latchahbcmd = 1'b0;
                ahbsram_req_int = 1'b1;
                if (sramahb_ack == 1'b1) begin
                    ahbnext_state = IDLE;
                end
            end

            default : begin
                ahbnext_state = IDLE;
            end
        endcase  
    end

    // LOGIC FOR BURST COUNT
    always @(*) 
    begin
        burst_count = burst_count_reg;
        if (HSEL == 1'b1  && HTRANS == TRN_NONSEQ && HREADYIN == 1'b1 && HREADYOUT == 1'b1) begin
            case (HBURST)
                SINGLE : 
                    burst_count = 5'b00001;
                WRAP4,INCR4 : 
                    burst_count = 5'b00100;
                WRAP8,INCR8 : 
                    burst_count = 5'b01000;
                WRAP16,INCR16 : 
                    burst_count = 5'b10000;
                default : 
                    burst_count = 4'b0001;
            endcase
        end
    end

    always @(posedge HCLK or negedge aresetn) 
    begin
        if ((aresetn == 1'b0) || (sresetn == 1'b0)) begin
            burst_count_reg <= 'h0;
        end 
        else begin
            burst_count_reg <= burst_count;
        end
    end

    always @(posedge HCLK or negedge aresetn) 
    begin
        if ((aresetn == 1'b0) || (sresetn == 1'b0)) begin
            count <= 5'h0;
        end 
        else begin
            if (count == burst_count_reg) begin
                count <= 5'h0;
            end 
            else if (ahbsram_req == 1'b1) begin
                count <= count + 1'b1;
            end 
            else begin
                count <= count;
            end
        end
    end

    assign HREADYOUT = !ahbsram_req_int;
    
    // Generation of signals required for SRAM
    assign ahbsram_write = ahbsram_req ? HWRITE_d : 1'b0;   
    assign ahbsram_wdata = HWDATA;     
    assign ahbsram_addr = ahbsram_req ? HADDR_d : HADDR_d;     
    assign ahbsram_size = ahbsram_req ? HSIZE_d : HSIZE_d;  
 
    always @(posedge HCLK or negedge aresetn) 
    begin
        if ((aresetn == 1'b0) || (sresetn == 1'b0)) begin
            ahbsram_req_d1 <= 1'b0;
        end
        else begin
            ahbsram_req_d1 <= ahbsram_req_int;
        end
    end

    // Generate the request to the SRAM contol logic when there is AHB read or write request
    assign ahbsram_req = ahbsram_req_int & !ahbsram_req_d1; 

    // HRDATA generation   
    always @(*) 
    begin
        if (HREADYOUT && HREADYIN) begin
            HRDATA = sramahb_rdata;
        end  
        else begin
            HRDATA = sramahb_rdata;
        end
    end

endmodule
