//------------------------------------------------------------------------------
// File                     : ahb_transaction_tasks.v
// Author                   : TG
// Key Words                :
// Modification History     :
//      Date        By        Version        Change Description
//      2022-04-26  TG        1.0            original
//
// Editor                   : VSCode, Tab Size(4)
// Description              : AHB Transaction Tasks.
//
//------------------------------------------------------------------------------
`ifndef __AHB_TRANSACTION_TASKS_V__
`define __AHB_TRANSACTION_TASKS_V__

//-----------------------------------------------------------------------
// AHB Read Task
//-----------------------------------------------------------------------
task ahb_read;
    input [31:0]                address;
    input [2:0]                 size;
    output [31:0]               data;
begin
    @(posedge HCLK);
    HADDR <= #1 address;
    HTRANS <= #1 2'b10; // NONSEQ;
    HBURST <= #1 3'b000; // SINGLE;
    HWRITE <= #1 1'b0; // READ;
    case (size)
        1 : HSIZE <= #1 3'b000; // BYTE;
        2 : HSIZE <= #1 3'b001; // HWORD;
        4 : HSIZE <= #1 3'b010; // WORD;
        default : 
            $display($time,, "ERROR: unsupported transfer size: %d-byte", size);
    endcase
    
    @(posedge HCLK);
    while (HREADY !== 1'b1) @(posedge HCLK);
    HTRANS <= #1 2'b0; // IDLE
    @(posedge HCLK);
    while (HREADY === 0) @(posedge HCLK);
    data = HRDATA; // must be blocking
    if (HRESP != 2'b00) 
        $display($time,, "ERROR: non OK response for read");
    @(posedge HCLK);
end
endtask

//-----------------------------------------------------------------------
// AHB Write Task
//-----------------------------------------------------------------------
task ahb_write;
    input [31:0]                address;
    input [2:0]                 size;
    input [31:0]                data;
begin
    @(posedge HCLK);
    HADDR <= #1 address;
    HTRANS <= #1 2'b10; // NONSEQ
    HBURST <= #1 3'b000; // SINGLE
    HWRITE <= #1 1'b1; // WRITE
    case (size)
        1 : HSIZE <= #1 3'b000; // BYTE
        2 : HSIZE <= #1 3'b001; // HWORD
        4 : HSIZE <= #1 3'b010; // WORD
        default : 
            $display($time,, "ERROR: unsupported transfer size: %d-byte", size);
    endcase
    
    @(posedge HCLK);
    while (HREADY !== 1) @(posedge HCLK);
    HWDATA <= #1 data;
    HTRANS <= #1 2'b0; // IDLE
    @(posedge HCLK);
    while (HREADY === 0) @(posedge HCLK);
    if (HRESP != 2'b00) 
        $display($time,, "ERROR: non OK response write");
    @(posedge HCLK);
end
endtask

//-----------------------------------------------------------------------
// AHB Read Burst Task
//-----------------------------------------------------------------------
task ahb_read_burst;
    input [31:0]                addr;
    input [31:0]                leng;
    
    integer                     i; 
    integer                     ln; 
    integer                     k;
begin
    k = 0;
    @(posedge HCLK);
    HADDR <= #1 addr; 
    addr = addr + 4;
    HTRANS <= #1 2'b10; // NONSEQ
    if (leng >= 16) begin 
        HBURST <= #1 3'b111; // INCR16
        ln = 16; 
    end
    else if (leng >= 8) begin 
        HBURST <= #1 3'b101; // INCR8
        ln = 8; 
    end
    else if (leng >= 4) begin 
        HBURST <= #1 3'b011; // INCR4
        ln = 4; 
    end 
    else begin 
        HBURST <= #1 3'b001; // INCR
        ln = leng; 
    end 
    HWRITE <= #1 1'b0; // READ
    HSIZE <= #1 3'b010; // WORD
    @(posedge HCLK);
    while (HREADY == 1'b0) @(posedge HCLK);
    while (leng > 0) begin
        for (i = 0; i < ln-1; i = i + 1) begin
            HADDR <= #1 addr; 
            addr = addr + 4;
            HTRANS <= #1 2'b11; // SEQ;
            @(posedge HCLK);
            while (HREADY == 1'b0) @(posedge HCLK);
            data_burst[k%1024] <= HRDATA;
            k = k + 1;
        end
        leng = leng - ln;
        if (leng == 0) begin
            HADDR <= #1 0;
            HTRANS <= #1 0;
            HBURST <= #1 0;
            HWRITE <= #1 0;
            HSIZE <= #1 0;
        end 
        else begin
            HADDR <= #1 addr; 
            addr = addr + 4;
            HTRANS <= #1 2'b10; // NONSEQ
            if (leng >= 16) begin 
                HBURST <= #1 3'b111; // INCR16
                ln = 16; 
            end 
            else if (leng >= 8) begin 
                HBURST <= #1 3'b101; // INCR8
                ln = 8; 
            end 
            else if (leng >= 4) begin 
                HBURST <= #1 3'b011; // INCR4
                ln = 4; 
            end 
            else begin 
                HBURST <= #1 3'b001; // INCR1 
                ln = leng; 
            end
            @(posedge HCLK);
            while (HREADY == 0) @(posedge HCLK);
            data_burst[k%1024] = HRDATA; // must be blocking
            k = k + 1;
        end
    end
    @(posedge HCLK);
    while (HREADY == 0) @(posedge HCLK);
    data_burst[k%1024] = HRDATA; // must be blocking
end
endtask

//-----------------------------------------------------------------------
// AHB Write Burst Task
// It takes suitable burst first and then incremental.
//-----------------------------------------------------------------------
task ahb_write_burst;
    input [31:0]                addr;
    input [31:0]                leng;
    integer                     i; 
    integer                     j; 
    integer                     ln;
begin
    j = 0;
    ln = 0;
    @(posedge HCLK);
    while (leng > 0) begin
        HADDR <= #1 addr; 
        addr = addr + 4;
        HTRANS <= #1 2'b10; // NONSEQ
        if (leng >= 16) begin 
            HBURST <= #1 3'b111; // INCR16
            ln = 16; 
        end
        else if (leng >= 8) begin 
            HBURST <= #1 3'b101; // INCR8
            ln = 8; 
        end
        else if (leng >= 4) begin 
            HBURST <= #1 3'b011; // INCR4
            ln = 4; 
        end
        else begin 
            HBURST <= #1 3'b001; // INCR
            ln = leng; 
        end
        HWRITE <= #1 1'b1; // WRITE
        HSIZE <= #1 3'b010; // WORD
        for (i = 0; i < ln-1; i = i + 1) begin
            @(posedge HCLK);
            while (HREADY == 1'b0) @(posedge HCLK);
            HWDATA <= #1 data_burst[(j+i)%1024];
            HADDR <= #1 addr; 
            addr = addr + 4;
            HTRANS <= #1 2'b11; // SEQ;
            while (HREADY == 1'b0) @(posedge HCLK);
        end
        @(posedge HCLK);
        while (HREADY == 0) @(posedge HCLK);
        HWDATA <= #1 data_burst[(j+i)%1024];
        if (ln == leng) begin
            HADDR <= #1 0;
            HTRANS <= #1 0;
            HBURST <= #1 0;
            HWRITE <= #1 0;
            HSIZE <= #1 0;
        end
        leng = leng - ln;
        j = j + ln;
    end
    @(posedge HCLK);
    while (HREADY == 0) @(posedge HCLK);
    if (HRESP != 2'b00) begin // OKAY
        $display($time,, "ERROR: non OK response write");
    end
`ifdef DEBUG
    $display($time,, "INFO: write(%x, %d, %x)", addr, size, data);
`endif
    HWDATA <= #1 0;
    @(posedge HCLK);
end
endtask

`endif