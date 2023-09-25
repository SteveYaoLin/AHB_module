//------------------------------------------------------------------------------
// File                     : top_tb.v
// Author                   : TG
// Key Words                :
// Modification History     :
//      Date        By        Version        Change Description
//      2022-04-26  TG        1.0            original
//
// Editor                   : VSCode, Tab Size(4)
// Description              : Testbench of AHB SRAM Controller.
//
//------------------------------------------------------------------------------
`timescale 1ns / 1ps

module top_tb();
    //----------------------------------
    // Local Parameter Declarations
    //----------------------------------
    localparam                      AHB_CLK_PERIOD = 5; // Assuming AHB CLK to be 100MHz

    localparam                      SIZE_IN_BYTES =2048;

    //----------------------------------
    // Variable Declarations
    //----------------------------------
    reg                             HCLK = 0;
    wire                            HWRITE;
    wire [1:0]                      HTRANS;
    wire [2:0]                      HSIZE;
    wire [2:0]                      HBURST;
    wire                            HREADYIN;
    wire [31:0]                     HADDR;
    wire [31:0]                     HWDATA;
    wire                            HREADYOUT;
    wire [1:0]                      HRESP;
    wire [31:0]                     HRDATA;
    reg                             HRESETn;

    //----------------------------------
    // Start of Main Code
    //----------------------------------

    //-----------------------------------------------------------------------
    // Generate HCLK
    //-----------------------------------------------------------------------
    always #AHB_CLK_PERIOD
        HCLK <= ~HCLK;
    
    //-----------------------------------------------------------------------
    // Generate HRESETn
    //-----------------------------------------------------------------------    
    initial begin
        HRESETn = 1'b0;
        repeat(5) @(posedge HCLK);
        HRESETn = 1'b1;
    end

    ahb_master #(
        .START_ADDR                 (32'h0),
        .DEPTH_IN_BYTES             (SIZE_IN_BYTES)
    )       
    u_ahb_master (     
        .HRESETn                    (HRESETn),
        .HCLK                       (HCLK),
        .HADDR                      (HADDR),
        .HTRANS                     (HTRANS),
        .HWRITE                     (HWRITE),
        .HSIZE                      (HSIZE),
        .HBURST                     (HBURST),
        .HWDATA                     (HWDATA),
        .HRDATA                     (HRDATA),
        .HRESP                      (HRESP),
        .HREADY                     (HREADYOUT)
    );

    ahb_sram # (
        .AHB_AWIDTH                 (32),
        .AHB_DWIDTH                 (32),
        .SIZE_IN_BYTES              (SIZE_IN_BYTES),
        .SYNC_RESET                 (1)
    ) 
    u_ahb_sram (
        .HCLK                       (HCLK),    
        .HRESETN                    (HRESETn),
        .HSEL                       (1'b1),
        .HWRITE                     (HWRITE),
        .HADDR                      (HADDR),
        .HWDATA                     (HWDATA),
        .HRDATA                     (HRDATA),
        .HSIZE                      (HSIZE),
        .HTRANS                     (HTRANS),
        .HBURST                     (HBURST),
        .HRESP                      (HRESP),
        .HREADYIN                   (1'b1),
        .HREADYOUT                  (HREADYOUT)
    );

`ifdef VCS
    initial begin
        $fsdbDumpfile("top_tb.fsdb");
        $fsdbDumpvars;
    end

    initial begin
    `ifdef DUMP_VPD
        $vcdpluson();
    `endif
    end
`endif

endmodule