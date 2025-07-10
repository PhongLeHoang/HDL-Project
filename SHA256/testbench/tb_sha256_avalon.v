`timescale 1ns / 1ps
`default_nettype none
module tb_sha256_avalon();
    localparam CLOCK_CYCLE = 10;
    localparam TIMEOUT = 15000;
    localparam BLOCK_BASE = 8'h00;
    localparam CTRL_BASE = 8'h10;
    localparam DIGEST_BASE = 8'h80;
    localparam START_LAST_BLOCK = 32'h1;
    localparam START_BLOCK = 32'h2;
    localparam NUMBER_OF_SINGLE_BLOCK = 70;
    localparam NUMBER_OF_DOUBLE_BLOCK = 20;
    localparam NUMBER_OF_TRIPLE_BLOCK = 10;

    localparam DONE = 0;
    localparam DIGEST_UPDATE = 3;

    reg iClk;
    reg iReset_n;
    reg iChipSelect_n;
    reg iRead_n;
    reg iWrite_n;
    reg [7:0] iAddress;
    reg [31:0] iData;
    wire [31:0] oData;

    integer n_pass, n_fail;
    integer i_timeout, i_run, i_write, i_read;
    reg[511:0] block;
    reg[255:0] digest;

    integer file_testcase, file_expected_result;
//======================================================
// Clock generation & Timeout counter
//======================================================
    initial begin
        iClk = 0;
        forever #5 iClk = ~iClk; // 10 ns clock period
    end
    initial begin
        for(i_timeout = 0; i_timeout < TIMEOUT; i_timeout = i_timeout + 1) begin
            @ (posedge iClk);
        end
        $strobe("TIMEOUT!");
        @ (posedge iClk);
        $stop;
    end
//======================================================
// Open files for test cases and expected results
//======================================================
    initial begin
        $display("============ Starting the simulation ============");
        file_testcase = $fopen("testcase.hex", "r");
        if(!file_testcase) begin
            $display("Cannot open file (testcase.hex)");
            $stop;
        end
        file_expected_result = $fopen("expected_result.hex", "r");
        if(!file_expected_result) begin
            $display("Cannot open file (expected_result.hex)");
            $stop;
        end
    end
//======================================================
// DUT connection
//======================================================
    sha256_avalon_slave DUT(
        .iClk(iClk),
        .iReset_n(iReset_n),
        .iChipSelect_n(iChipSelect_n),
        .iWrite_n(iWrite_n),
        .iRead_n(iRead_n),
        .iAddress(iAddress),
        .iData(iData),
        .oData(oData)
    );
//======================================================
// Starting the simulation | main testbench
//======================================================
    initial begin
        iReset_n = 0;
        n_pass = 0;
        n_fail = 0;
        # (2*CLOCK_CYCLE);
        iReset_n = 1;
        iChipSelect_n = 0;
        tSingle_block_hashing();
        # (2*CLOCK_CYCLE);
        tDouble_block_hashing();
        # (2*CLOCK_CYCLE);
        tTriple_block_hashing();
        # (2*CLOCK_CYCLE);
        tDisplay_result();
        $fclose(file_testcase);
        $fclose(file_expected_result);
        $stop;
    end
//======================================================
// Single block hashing
//======================================================
    task tSingle_block_hashing;
    begin
         $display("SINGLE BLOCK HASHING");
        for(i_run = 0; i_run < NUMBER_OF_SINGLE_BLOCK; i_run = i_run + 1) begin
            $display("SINGLE BLOCK - RUNTIME:%3d", i_run + 1);
            tWrite_block(); // Read block from file & write to registers
            tSend_start_signal();
            tSend_last_block_signal();           
            tWait_for_done();
            tRead_and_check_digest();
        end
    end
    endtask
//======================================================
// Double block hashing
//======================================================
    task tDouble_block_hashing;
    begin
         $display("DOUBLE BLOCK HASHING");
        for(i_run = 0; i_run < NUMBER_OF_DOUBLE_BLOCK; i_run = i_run + 1) begin
            $display("DOUBLE BLOCK - RUNTIME:%3d", i_run + 1);
            tWrite_block();
            tSend_start_signal();
            // BLOCK 1
            tWrite_block(); 
            tWait_for_digest_update();
            tSend_last_block_signal();
            // BLOCK 2 | LAST BLOCK
            tWait_for_done();
            tRead_and_check_digest();
        end
    end
    endtask
//======================================================
// Triple block hashing
//======================================================
    task tTriple_block_hashing;
    begin
         $display("TRIPLE BLOCK HASHING");
        for(i_run = 0; i_run < NUMBER_OF_TRIPLE_BLOCK; i_run = i_run + 1) begin
            $display("TRIPLE BLOCK - RUNTIME:%3d", i_run + 1);
            tWrite_block();
            tSend_start_signal();
            // BLOCK 1
            tWrite_block(); 
            tWait_for_digest_update();
            // BLOCK 2
            tWrite_block(); 
            tWait_for_digest_update();
            tSend_last_block_signal();
            // BLOCK 3 | LAST BLOCK
            tWait_for_done();
            tRead_and_check_digest();
        end
    end
    endtask
//======================================================
// Start hashing: Read block from file & write to registers
//======================================================
    task tWrite_block;
    begin
        if($fscanf(file_testcase, "%h\n", block)) begin
            $display("Read file successful: data = %h", block);
            // Write the block to the DUT
            for(i_write = 0; i_write < 16; i_write = i_write + 1) begin
                tWrite(block[511:480], BLOCK_BASE, i_write);
                block = block << 32;
            end
        end
        else begin
            $display("Cannot read file");
        end
    end
    endtask
//======================================================
// Read digest
//======================================================
    task tRead_and_check_digest;
    begin
        if($fscanf(file_expected_result, "%h\n", digest)) begin
            $display("Read file successful: data = %h", digest);
            for(i_read = 0; i_read < 8; i_read = i_read + 1) begin
                tCheck(DIGEST_BASE, i_read, digest[255:224]);
                digest = digest << 32;
            end
            $display("Digest check done!");
        end
        else begin
            $display("Cannot read file");
        end
    end
    endtask
//======================================================
// Send last block signal
//======================================================
    task tSend_last_block_signal;
    begin
        tWrite(START_LAST_BLOCK, CTRL_BASE, 0);
        @ (posedge iClk);
    end
    endtask
//======================================================
// Send start signal
//======================================================
    task tSend_start_signal;
    begin
        tWrite(START_BLOCK, CTRL_BASE, 0);
        @ (posedge iClk);
    end
    endtask
//======================================================
// Display result
//======================================================
    task tDisplay_result;
    begin
        $display("============ Simulation finished ============");
        $display("Pass: %3d, Fail: %3d", n_pass, n_fail);
        if(n_fail == 0) begin
            $display("All test cases passed!");
        end
        else begin
            $display("Some test cases failed!");
        end
    end
    endtask
//======================================================
// Write to registers
//======================================================
    task tWrite;
    input [31:0] data;
    input [7:0] base;
    input [3:0] offset;
    begin
        iData = data;
        iAddress = base + offset;
        iWrite_n = 1'b0;
        $display("Write: iData = %8h, iAddress =%2d", iData, iAddress);
        @ (posedge iClk);
        iWrite_n = 1'b1;
    end
    endtask
//======================================================
// Wait for done signal
//======================================================
    task tWait_for_done;
    begin
        iAddress = CTRL_BASE;
        iRead_n = 1'b0;
        @ (posedge oData[DONE]);
        $display("Done signal received!");
        iRead_n = 1'b1;
        @ (posedge iClk);
    end
    endtask
//======================================================
// Wait for digest update signal
//======================================================
    task tWait_for_digest_update;
    begin
        iAddress = CTRL_BASE;
        iRead_n = 1'b0;
        @ (posedge oData[DIGEST_UPDATE]);
        $display("Done signal received!");
        iRead_n = 1'b1;
        @ (posedge iClk);
    end
    endtask
//======================================================
// Check the digest
//======================================================
    task tCheck;
    input [7:0] base;
    input [3:0] offset;
    input [31:0] digest;
    begin
        iAddress = base + offset;
        iRead_n = 1'b0;
        @ (posedge iClk);
        $display("Read: oData = %8h, iAddress =%2h", oData, iAddress);
        if(oData == digest) begin
            $display("Digest match!");
            n_pass = n_pass + 1;
        end
        else begin
            $display("Digest mismatch!");
            n_fail = n_fail + 1;
        end
        iRead_n = 1'b1;
    end
    endtask
//======================================================
// Waveform generation
//======================================================
    initial begin
        $dumpfile("tb_sha256_avalon.vcd");
        $dumpvars(0, tb_sha256_avalon);
    end
//======================================================
endmodule