`timescale 1ns/1ps
`default_nettype none
module tb_sha256_core();
    localparam CLOCK_CYCLE = 10;
    localparam TIMEOUT = 10000;

    localparam NUMBER_OF_SINGLE_BLOCK = 70;
    localparam NUMBER_OF_DOUBLE_BLOCK = 20;
    localparam NUMBER_OF_TRIPLE_BLOCK = 10;

    reg clk;
    reg reset_n;
    reg start;
    reg last_block;
    reg [511:0] block;
    wire [255:0] digest;
    wire done;
    wire digest_update;


    integer i_timeout, i_run;
    integer n_pass, n_fail;
    
    reg[255:0] expected_digest;
    integer file_testcase, file_expected_result;
//=======================================================
// Clock generation & Timeout counter
//=======================================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10 ns clock period
    end
    initial begin
        for(i_timeout = 0; i_timeout < TIMEOUT; i_timeout = i_timeout + 1) begin
            @ (posedge clk);
        end
        $strobe("TIMEOUT!");
        @ (posedge clk);
        $stop;
    end
//=======================================================
// Open files for test cases and expected results
//=======================================================
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
//=======================================================
// DUT instantiation
//=======================================================
    sha256_core dut(
        .clk(clk),
        .reset_n(reset_n),
        .start(start),
        .last_block(last_block),
        .block(block),
        .done(done),
        .digest_update(digest_update),
        .digest(digest)
    );
//=======================================================
// Start the simulation | main testbench
//=======================================================
    initial begin
        reset_n = 0;
        start = 0;
        last_block = 0;
        block = 0;
        n_pass = 0;
        n_fail = 0;
        # (CLOCK_CYCLE * 2);
        reset_n = 1;
        $display("=============== Starting the simulation ================");
        tSingle_block_hashing();
        # (CLOCK_CYCLE * 2);
        tDouble_block_hashing();
        # (CLOCK_CYCLE * 2);
        tTriple_block_hashing();
        # (CLOCK_CYCLE * 2);
        tDisplay_result();
        $fclose(file_testcase);
        $fclose(file_expected_result);
        $stop;
    end
//=======================================================
// Test cases for single block
//=======================================================
    task tSingle_block_hashing();
    begin
        for(i_run = 0; i_run < NUMBER_OF_SINGLE_BLOCK; i_run = i_run + 1) begin
            $display("SINGLE BLOCK HASHING, RUNTIME:%3d", i_run + 1);
            // Read test case from file
            tRead_block_from_file();
            start = 1;
            last_block = 1;
            tWait_for_done();
            tCheck_result();
        end
    end
    endtask
//=======================================================
// Test cases for double block
//=======================================================
    task tDouble_block_hashing();
    begin
        for(i_run = 0; i_run < NUMBER_OF_DOUBLE_BLOCK; i_run = i_run + 1) begin
            $display("DOUBLE BLOCK HASHING, RUNTIME:%3d", i_run + 1);
            // Read test case from file
            tRead_block_from_file();
            start = 1;
            tWait_for_digest_update();
            tRead_block_from_file();
            last_block = 1;
            tWait_for_done();
            tCheck_result();
        end
    end
    endtask
//=======================================================
// Test cases for triple block
//=======================================================
    task tTriple_block_hashing();
    begin
        for(i_run = 0; i_run < NUMBER_OF_TRIPLE_BLOCK; i_run = i_run + 1) begin
            $display("TRIPLE BLOCK HASHING, RUNTIME:%3d", i_run + 1);
            // Read test case from file
            tRead_block_from_file();
            start = 1;
            last_block = 0;
            tWait_for_digest_update();
            tRead_block_from_file();
            tWait_for_digest_update();
            tRead_block_from_file();
            last_block = 1;
            tWait_for_done();
            tCheck_result();
        end
    end
    endtask
//=======================================================
// Read block from file
//=======================================================
    task tRead_block_from_file();
    begin
        if($fscanf(file_testcase, "%h", block)) begin
            // Read expected result from file
            $display("Read file successfully, block = %h", block);
        end else begin
            $display("Error reading test case %d", i_run + 1);
        end
        @ (posedge clk);
    end
    endtask
//=======================================================
// Wait for done signal
//=======================================================
    task tWait_for_done();
    begin
        # (CLOCK_CYCLE);
        start = 0;
        @ (posedge done);
        last_block = 0;
    end
    endtask
//=======================================================
// Wait for done signal
//=======================================================
    task tWait_for_digest_update();
    begin
        # (CLOCK_CYCLE);
        start = 0;
        @ (posedge digest_update);
    end
    endtask
//=======================================================
// Check result
//=======================================================
    task tCheck_result();
    begin
        if($fscanf(file_expected_result, "%h", expected_digest)) begin
            if(digest == expected_digest) begin
                n_pass = n_pass + 1;
                $display("Test case %2d: PASSED", i_run + 1);
                $display("Digest = %h", digest);
            end else begin
                n_fail = n_fail + 1;
                $display("Test case %2d: FAILED", i_run + 1);
                $display("Expected: %h\nGot: %h", expected_digest, digest);
            end
        end else begin
            $display("Error reading file for test case %d", i_run + 1);
        end
    end
    endtask
//=======================================================
// Display result
//=======================================================
    task tDisplay_result();
    begin
        $display("============ Simulation finished ============");
        $display("Total test cases: %3d", NUMBER_OF_SINGLE_BLOCK + NUMBER_OF_DOUBLE_BLOCK + NUMBER_OF_TRIPLE_BLOCK);
        $display("Passed: %3d", n_pass);
        $display("Failed: %3d", n_fail);
        if(n_fail == 0) begin
            $display("All test cases passed!");
        end else begin
            $display("Some test cases failed!");
        end
        @ (posedge clk);
    end
    endtask
//=======================================================
// Waveform generation
//=======================================================
    initial begin
        $dumpfile("tb_sha256_core.vcd");
        $dumpvars(0, tb_sha256_core);
    end
endmodule