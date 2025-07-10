`timescale 1ns / 1ps
`default_nettype none

module tb_sha256_axi4_lite();
    localparam CLOCK_CYCLE = 10;
    localparam TIMEOUT = 25000;

    localparam MSG_REG_BASE = 8'h00;
    localparam CTRL_REG = 8'h10;
    localparam DIGEST_REG_BASE = 8'h11;

    localparam START_BLOCK     = 32'h2;
    localparam START_LAST_BLOCK = 32'h1;

    localparam NUMBER_OF_SINGLE_BLOCK = 70;
    localparam NUMBER_OF_DOUBLE_BLOCK = 20;
    localparam NUMBER_OF_TRIPLE_BLOCK = 10;

    localparam DONE = 0; // index for done signal
    localparam DIGEST_UPDATE = 3; // index for digest update signal

    reg ACLK;
    reg ARESETn;

    // Write Address Channel
    reg        AWVALID;
    wire       AWREADY;
    reg [4:0]  AWADDR;

    // Write Data Channel
    reg        WVALID;
    wire       WREADY;
    reg [31:0] WDATA;

    // Write Response Channel
    wire       BVALID;
    reg        BREADY;
    wire [1:0] BRESP;

    // Read Address Channel
    reg        ARVALID;
    wire       ARREADY;
    reg [4:0]  ARADDR;

    // Read Data Channel
    wire       RVALID;
    reg        RREADY;
    wire [31:0] RDATA;
    wire [1:0] RRESP;

    reg [511:0] block;
    reg [255:0] digest;
    integer file_testcase, file_expected_result;
    integer i_write, i_read;
    integer n_pass, n_fail, i_run;
    integer i_timeout;
    // Clock generation
    initial begin
        ACLK = 0;
        forever #5 ACLK = ~ACLK;
    end

    // Timeout
    initial begin
        for (i_timeout = 0; i_timeout < TIMEOUT; i_timeout = i_timeout + 1) begin
            @(posedge ACLK);
        end
        $display("TIMEOUT!");
        $stop;
    end

    // DUT instantiation
    sha256_axi4_lite_slave DUT (
        .ACLK(ACLK),
        .ARESETn(ARESETn),
        .AWVALID(AWVALID),
        .AWREADY(AWREADY),
        .AWADDR(AWADDR),
        .WVALID(WVALID),
        .WREADY(WREADY),
        .WDATA(WDATA),
        .BVALID(BVALID),
        .BREADY(BREADY),
        .BRESP(BRESP),
        .ARVALID(ARVALID),
        .ARREADY(ARREADY),
        .ARADDR(ARADDR),
        .RVALID(RVALID),
        .RREADY(RREADY),
        .RDATA(RDATA),
        .RRESP(RRESP)
    );

    initial begin
        $display("============ Starting AXI4-Lite SHA-256 Simulation ============");
        file_testcase = $fopen("testcase.hex", "r");
        if (!file_testcase) begin
            $display("Cannot open file testcase.hex");
            $stop;
        end
        file_expected_result = $fopen("expected_result.hex", "r");
        if (!file_expected_result) begin
            $display("Cannot open file expected_result.hex");
            $stop;
        end

        ARESETn = 0;
        AWVALID = 0; WVALID = 0;
        BREADY = 1;
        ARVALID = 0; RREADY = 1;
        n_pass = 0; n_fail = 0;

        #20;
        ARESETn = 1;
        #20;

        tRun_single_block();
        #20;
        tRun_double_block();
        #20;
        tRun_triple_block();
        #20;

        tDisplay_result();
        $fclose(file_testcase);
        $fclose(file_expected_result);
        $stop;
    end

    // Write task
    task tWrite;
        input [4:0] addr;
        input [31:0] data;
        begin
            @(posedge ACLK);
            AWADDR = addr;
            WDATA = data;
            AWVALID = 1;
            WVALID = 1;
            wait (BVALID);
            @(posedge ACLK);
            AWVALID = 0;
            WVALID = 0;
        end
    endtask

    // Read task
    task tRead;
        input [4:0] addr;
        output [31:0] data;
        begin
            @(posedge ACLK);
            ARADDR = addr;
            ARVALID = 1;
            RREADY = 1;
            wait (RVALID);
            data = RDATA;
            @(posedge ACLK);
            ARVALID = 0;
            RREADY = 0;
        end
    endtask

    // Write 512-bit block
    task tWrite_block;
        begin
            if ($fscanf(file_testcase, "%h\n", block)) begin
                $display("Read block from file: %h", block);
                for (i_write = 0; i_write < 16; i_write = i_write + 1) begin
                    tWrite(MSG_REG_BASE + i_write, block[511:480]);
                    block = block << 32;
                end
            end else begin
                $display("Failed to read test vector");
            end
        end
    endtask

    // Send start and last block signals
    task tSend_start;
        begin
            tWrite(CTRL_REG, START_BLOCK);
        end
    endtask

    task tSend_last_block;
        begin
            tWrite(CTRL_REG, START_LAST_BLOCK);
        end
    endtask
    // Wait for done signal
    task tWait_for_done;
        reg [31:0] readdata;
        reg done_signal;
        begin
            done_signal = 0;
            while(!done_signal) begin
                tRead(CTRL_REG, readdata);
                done_signal = readdata[DONE];
            end
            $display("Done signal received");
        end
    endtask
    task tWait_for_digest_update;
        reg [31:0] readdata;
        reg digest_update_signal;
        begin
            digest_update_signal = 0;
            while(!digest_update_signal) begin
                tRead(CTRL_REG, readdata);
                digest_update_signal = readdata[DIGEST_UPDATE];
            end
            $display("Digest update signal received");
        end
    endtask
    // Read and check digest
    task tCheck_digest;
        reg [31:0] value;
        reg wrong_flag;
        begin
            wrong_flag = 0;
            if ($fscanf(file_expected_result, "%h\n", digest)) begin
                $display("Expected digest: %h", digest);
                for (i_read = 0; i_read < 8; i_read = i_read + 1) begin
                    tRead(DIGEST_REG_BASE + i_read, value);
                    if (value === digest[255:224]) begin
                        $display("Digest[%0d] matched: %h", i_read, value);
                    end else begin
                        $display("Digest[%0d] mismatch: %h != %h", i_read, value, digest[255:224]);
                        wrong_flag = 1;
                    end
                    digest = digest << 32;
                end
                if (wrong_flag == 0) begin
                    n_pass = n_pass + 1;
                    $display("Test passed (%0d/%0d)", n_pass, n_pass + n_fail);
                end else begin
                    n_fail = n_fail + 1;
                    $display("Test failed (%0d/%0d)", n_pass, n_pass + n_fail);
                end
            end else begin
                $display("Failed to read expected digest");
            end
        end
    endtask

    task tRun_single_block;
        begin
            for (i_run = 0; i_run < NUMBER_OF_SINGLE_BLOCK; i_run = i_run + 1) begin
                $display("SINGLE BLOCK: Test #%0d", i_run + 1);
                tWrite_block();
                tSend_start();
                tSend_last_block();
                tWait_for_done();
                tCheck_digest();
            end
        end
    endtask
    task tRun_double_block;
        begin
            for (i_run = 0; i_run < NUMBER_OF_DOUBLE_BLOCK; i_run = i_run + 1) begin
                $display("DOUBLE BLOCK: Test #%0d", i_run + 1);
                tWrite_block();
                tSend_start();

                tWrite_block();

                tSend_last_block();
                tWait_for_done();
                tCheck_digest();
            end
        end
    endtask
    task tRun_triple_block;
        begin
            for (i_run = 0; i_run < NUMBER_OF_TRIPLE_BLOCK; i_run = i_run + 1) begin
                $display("TRIPLE BLOCK: Test #%0d", i_run + 1);
                tWrite_block();
                tSend_start();

                tWrite_block();

                tWrite_block();

                tSend_last_block();
                tWait_for_done();
                tCheck_digest();
            end
        end
    endtask
    task tDisplay_result;
        begin
            $display("============ Simulation Finished ============");
            if (n_fail == 0) begin
                $display("All tests passed (%0d/%0d)", n_pass, n_pass + n_fail);
            end else begin
                $display("Test failed (%0d/%0d)", n_pass, n_pass + n_fail);
            end
        end
    endtask
    // VCD for waveform
    initial begin
        $dumpfile("tb_sha256_axi4_lite.vcd");
        $dumpvars(0, tb_sha256_axi4_lite);
    end

endmodule
