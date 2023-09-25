//------------------------------------------------------------------------------
// File                     : sram_model.v
// Author                   : TG
// Key Words                :
// Modification History     : 
// Date        By        Version        Change Description
// 2021-12-05  TG        1.0            original
// Editor                   : GVIM, Tab Size(4)
// Description              : FPGA Block Ram/Onchip SRAM.
//  
//------------------------------------------------------------------------------
`timescale 1ns / 1ps

module sram_model #(
    parameter                   SYNC_RESET = 0,
    parameter                   ADDR_WIDTH = 16
)
(
    //----------------------------------
    // IO Declarations
    //----------------------------------
    input [31:0]                writedata,
    output [31:0]               readdata,
    input [3:0]                 wren,
    input                       rden,
    input [ADDR_WIDTH-1:2]      writeaddr,
    input [ADDR_WIDTH-1:2]      readaddr,
    input                       clk,
    input                       resetn
);

    //----------------------------------
    //--Local Parameter Declarations
    //----------------------------------
    localparam                  AWT = ((1<<(ADDR_WIDTH-2))-1);

    //----------------------------------
    // Variable Declarations
    //----------------------------------
    reg [7:0]                   bram0[AWT:0];
    reg [7:0]                   bram1[AWT:0];
    reg [7:0]                   bram2[AWT:0];
    reg [7:0]                   bram3[AWT:0];

    reg [ADDR_WIDTH-3:0]        addr_q1;
    reg                         rden_r = 1'b0;
    wire [31:0]                 readdata_i;

    wire                        aresetn;
    wire                        sresetn;

    //----------------------------------
    // Start of Main Code
    //----------------------------------
    assign aresetn = (SYNC_RESET == 1) ? 1'b1 : resetn;
    assign sresetn = (SYNC_RESET == 1) ? resetn : 1'b1;

    always @(posedge clk)
    begin
        rden_r <= rden;
    end

    // Infer Block RAM 
    always @(posedge clk)
    begin
        if (wren[0])
            bram0[writeaddr] <= writedata[7:0];
        if (wren[1])
            bram1[writeaddr] <= writedata[15:8];
        if (wren[2])
            bram2[writeaddr] <= writedata[23:16];
        if (wren[3])
            bram3[writeaddr] <= writedata[31:24];
    end

    always @(posedge clk)
    begin
        addr_q1 <= readaddr[ADDR_WIDTH-1:2];
    end 

    assign readdata_i = {bram3[addr_q1],bram2[addr_q1],bram1[addr_q1],bram0[addr_q1]};

    assign readdata = rden_r ? readdata_i : {32{1'b0}};

endmodule