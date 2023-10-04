//------------------------------------------------------------------------------
// File                     : ahb_master.v
// Author                   : TG
// Key Words                :
// Modification History     :
//      Date        By        Version        Change Description
//      2022-04-26  TG        1.0            original
//
// Editor                   : VSCode, Tab Size(4)
// Description              : AHB Master Simulation Model.
//
//------------------------------------------------------------------------------
`timescale 1ns / 1ps

`define SINGLE_TEST
`define BURST_TEST

module ahb_master #( 
    //----------------------------------
    // Paramter Declarations
    //----------------------------------
    parameter                           START_ADDR = 0,
    parameter                           DEPTH_IN_BYTES = 32'h100,
    parameter                           END_ADDR = START_ADDR+DEPTH_IN_BYTES-1
)
(
    //----------------------------------
    // IO Declarations
    //----------------------------------
    input wire                          HRESETn,        
    input wire                          HCLK,
    output reg [31:0]                   HADDR,
    output reg [1:0]                    HTRANS,
    output reg                          HWRITE,
    output reg [2:0]                    HSIZE,
    output reg [2:0]                    HBURST,
    output reg [31:0]                   HWDATA,
    input wire [31:0]                   HRDATA,
    input wire [1:0]                    HRESP,
    input wire                          HREADY
);

    //----------------------------------
    // Variable Declarations
    //----------------------------------
    reg [31:0]                          data_burst[0:1023];

    //----------------------------------
    // Start of Main Code
    //----------------------------------
    initial begin
        HADDR = 0;
        HTRANS = 0;
        HWRITE = 0;
        HSIZE = 0;
        HBURST = 0;
        HWDATA = 0;
        while(HRESETn === 1'bx) @(posedge HCLK);
        while(HRESETn === 1'b1) @(posedge HCLK);
        while(HRESETn === 1'b0) @(posedge HCLK);
    `ifdef SINGLE_TEST
        repeat(3) @(posedge HCLK);
        memory_test(START_ADDR, END_ADDR, 1);
        memory_test(START_ADDR, END_ADDR, 2);
        memory_test(START_ADDR, END_ADDR, 4);
    `endif
    `ifdef BURST_TEST
        repeat(5) @(posedge HCLK);
        memory_test_burst(START_ADDR, END_ADDR, 1);
        memory_test_burst(START_ADDR, END_ADDR, 2);
        memory_test_burst(START_ADDR, END_ADDR, 4);
        memory_test_burst(START_ADDR, END_ADDR, 6);
        memory_test_burst(START_ADDR, END_ADDR, 8);
        memory_test_burst(START_ADDR, END_ADDR, 10);
        memory_test_burst(START_ADDR, END_ADDR, 16);
        memory_test_burst(START_ADDR, END_ADDR, 32);
        memory_test_burst(START_ADDR, END_ADDR, 64);
        memory_test_burst(START_ADDR, END_ADDR, 128);
        memory_test_burst(START_ADDR, END_ADDR, 255);
        repeat(5) @(posedge HCLK);
    `endif
        $finish(2);
    end
    
    //-----------------------------------------------------------------------
    // Single transfer test 
    //-----------------------------------------------------------------------
    task memory_test;
        input [31:0]                start; // start address
        input [31:0]                finish; // end address
        input [2:0]                 size; // data size: 1, 2, 4
        
        integer                     i; 
        integer                     error;
        reg [31:0]                  data; 
        reg [31:0]                  gen; 
        reg [31:0]                  got;
        reg [31:0]                  reposit[START_ADDR:END_ADDR];
    begin
        $display("%m: read-after-write test with %d-byte access", size);
        error = 0;
        gen = $random(7);
        for (i = start; i < (finish-size+1); i = i + size) begin
            gen = $random & ~32'b0;
            data = align(i, gen, size);
            ahb_write(i, size, data);
            ahb_read(i, size, got);
            got = align(i, got, size);
            if (got !== data) begin
                $display("[%10d] %m A:%x D:%x, but %x expected", $time, i, got, data);
                error = error + 1;
            end
        end
        if (error == 0)
            $display("[%10d] %m OK: from %x to %x", $time, start, finish);

        $display("%m read-all-after-write-all with %d-byte access", size);
        error = 0;
        gen = $random(1);
        for (i = start; i < (finish-size+1); i = i + size) begin
            gen = {$random} & ~32'b0;
            data = align(i, gen, size);
            reposit[i] = data;
            ahb_write(i, size, data);
        end
        for (i = start; i < (finish-size+1); i = i + size) begin
            data = reposit[i];
            ahb_read(i, size, got);
            got = align(i, got, size);
            if (got !== data) begin
                $display("[%10d] %m A:%x D:%x, but %x expected", $time, i, got, data);
                error = error + 1;
            end
        end
        if (error == 0)
            $display("[%10d] %m OK: from %x to %x", $time, start, finish);
    end
    endtask
    
    //-----------------------------------------------------------------------
    // Burst transfer test 
    //-----------------------------------------------------------------------
    task memory_test_burst;
        input [31:0]                start; // start address
        input [31:0]                finish; // end address
        input [7:0]                 leng; // burst length
        
        integer                     i; 
        integer                     j; 
        integer                     k; 
        integer                     r; 
        integer                     error;
        reg [31:0]                  data; 
        reg [31:0]                  gen; 
        reg [31:0]                  got;
        reg [31:0]                  reposit[0:1023];
        integer                     seed;
    begin
        $display("%m: read-all-after-write-all burst test with %d-beat access", leng);
        error = 0;
        seed  = 111;
        gen = $random(seed);
        k = 0;
        if (finish > (start+leng*4)) begin
            for (i = start; i < (finish-(leng*4)+1); i = i + leng*4) begin
                for (j = 0; j < leng; j = j + 1) begin
                    data_burst[j] = $random;
                    reposit[j+k*leng] = data_burst[j];
                end
                @(posedge HCLK);
                ahb_write_burst(i, leng);
                k = k + 1;
            end
            gen = $random(seed);
            k = 0;
            for (i = start; i < (finish-(leng*4)+1); i = i + leng*4) begin
                @(posedge HCLK);
                ahb_read_burst(i, leng);
                for (j = 0; j < leng; j = j + 1) begin
                    if (data_burst[j] != reposit[j+k*leng]) begin
                        error = error+1;
                        $display("%m A=%hh D=%hh, but %hh expected",i+j*leng, data_burst[j], reposit[j+k*leng]);
                    end
                end
                k = k + 1;
                r = $random & 8'h0F;
                repeat(r) @(posedge HCLK);
            end
            if (error == 0)
                $display("%m %d-length burst read-after-write OK: from %hh to %hh",leng, start, finish);
        end 
        else begin
            $display("%m %d-length burst read-after-write from %hh to %hh ???",leng, start, finish);
        end
    end
    endtask
    
    //-----------------------------------------------------------------------
    // As AMBA AHB bus uses non-justified data bus scheme, data should be
    // aligned according to the address.
    //-----------------------------------------------------------------------
    function [31:0] align;
        input [ 1:0]                addr;
        input [31:0]                data;
        input [ 2:0]                size; // num of bytes
    begin
    `ifdef BIG_ENDIAN
        case (size)
            1 : 
                case (addr[1:0])
                    0 : align = data & 32'hFF00_0000;
                    1 : align = data & 32'h00FF_0000;
                    2 : align = data & 32'h0000_FF00;
                    3 : align = data & 32'h0000_00FF;
                endcase                
                                       
            2 :                        
                case (addr[1])         
                    0 : align = data & 32'hFFFF_0000;
                    1 : align = data & 32'h0000_FFFF;
                endcase
                
            4 : 
                align = data&32'hFFFF_FFFF;
            default : 
                $display($time,,"%m ERROR %d-byte not supported for size", size);
        endcase
    `else
        case (size)
            1 : 
                case (addr[1:0])
                    0 : align = data & 32'h0000_00FF;
                    1 : align = data & 32'h0000_FF00;
                    2 : align = data & 32'h00FF_0000;
                    3 : align = data & 32'hFF00_0000;
                endcase
                
            2 : 
                case (addr[1])
                    0 : align = data & 32'h0000_FFFF;
                    1 : align = data & 32'hFFFF_0000;
                endcase
                
            4 : 
                align = data&32'hFFFF_FFFF;
            default : 
                $display($time,,"%m ERROR %d-byte not supported for size", size);
        endcase
    `endif
    end
    endfunction

    `include "./test/ahb_transaction_tasks.v"
endmodule
