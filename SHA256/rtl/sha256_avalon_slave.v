module sha256_avalon_slave (
    // Avalon MM Slave Interface
    input wire iClk,
    input wire iReset_n,
    input wire iChipSelect_n,
    input wire iWrite_n,
    input wire iRead_n,
    input wire [7:0] iAddress,
    input wire [31:0] iData,
    output reg [31:0] oData
);

    // Internal registers
    wire [255:0] digest;
    wire [511:0] block;        // 16 register x 32-bit = 512 bits
    reg start_reg;                  // Control register bit
    reg last_block_reg;             // Control register bit        
    wire done;
    wire digest_update;
    reg [31:0] devided_block [0:15]; //
    assign block =   {devided_block[15], devided_block[14], devided_block[13], devided_block[12],
                        devided_block[11], devided_block[10], devided_block[ 9], devided_block[ 8],
                        devided_block[ 7], devided_block[ 6], devided_block[ 5], devided_block[ 4],
                        devided_block[ 3], devided_block[ 2], devided_block[ 1], devided_block[ 0]};

    // Control and status registers
    localparam CTRL_REG      = 8'h10;  // Control register (start, last_block)
    
    // Message input registers (16 registers, 32-bit each)
    localparam MSG_REG_BASE  = 8'h00;  // Start address for message registers
    
    // Digest output registers (8 registers, 32-bit each)
    localparam DIGEST_REG_BASE = 8'h80;  // Start address for digest registers
    
    // SHA-256 core instance
    sha256_core IP (
        .clk(iClk),
        .reset_n(iReset_n),
        .start(start_reg),
        .block(block),
        .last_block(last_block_reg),
        .done(done),
        .digest_update(digest_update),
        .digest(digest)
    );
    // Write to registers
    always @(posedge iClk or negedge iReset_n) begin
        if (!iReset_n) begin
            start_reg <= 0;
            last_block_reg <= 0;
            devided_block[0] <= 32'h0;
            devided_block[1] <= 32'h0;
            devided_block[2] <= 32'h0;
            devided_block[3] <= 32'h0;
            devided_block[4] <= 32'h0;
            devided_block[5] <= 32'h0;
            devided_block[6] <= 32'h0;
            devided_block[7] <= 32'h0;
            devided_block[8] <= 32'h0;
            devided_block[9] <= 32'h0;
            devided_block[10] <= 32'h0;
            devided_block[11] <= 32'h0;
            devided_block[12] <= 32'h0;
            devided_block[13] <= 32'h0;
            devided_block[14] <= 32'h0;
            devided_block[15] <= 32'h0;
        end
        else if (!iChipSelect_n && !iWrite_n) begin
            case (iAddress)
                CTRL_REG: begin
                    start_reg <= iData[1];
                    last_block_reg <= iData[0];
                end
                
                // Message registers (16 x 32-bit)
                MSG_REG_BASE + 4'hf: devided_block[0] <= iData;
                MSG_REG_BASE + 4'he: devided_block[1] <= iData;
                MSG_REG_BASE + 4'hd: devided_block[2] <= iData;
                MSG_REG_BASE + 4'hc: devided_block[3] <= iData;
                MSG_REG_BASE + 4'hb: devided_block[4] <= iData;
                MSG_REG_BASE + 4'ha: devided_block[5] <= iData;
                MSG_REG_BASE + 4'h9: devided_block[6] <= iData;
                MSG_REG_BASE + 4'h8: devided_block[7] <= iData;
                MSG_REG_BASE + 4'h7: devided_block[8] <= iData;
                MSG_REG_BASE + 4'h6: devided_block[9] <= iData;
                MSG_REG_BASE + 4'h5: devided_block[10] <= iData;
                MSG_REG_BASE + 4'h4: devided_block[11] <= iData;
                MSG_REG_BASE + 4'h3: devided_block[12] <= iData;
                MSG_REG_BASE + 4'h2: devided_block[13] <= iData;
                MSG_REG_BASE + 4'h1: devided_block[14] <= iData;
                MSG_REG_BASE + 4'h0: devided_block[15] <= iData;
            endcase
        end
        else begin
            start_reg <= 1'b0; // Clear start bit if not writing to control register
        end
    end
    
    // Read from registers
    always @ * begin
        if (!iChipSelect_n && !iRead_n) begin
            case (iAddress)
                CTRL_REG: oData <= {28'b0, digest_update, last_block_reg, start_reg, done};
                
                // Digest registers (8 x 32-bit)
                DIGEST_REG_BASE + 4'h7: oData = digest[31:0];
                DIGEST_REG_BASE + 4'h6: oData = digest[63:32];
                DIGEST_REG_BASE + 4'h5: oData = digest[95:64];
                DIGEST_REG_BASE + 4'h4: oData = digest[127:96];
                DIGEST_REG_BASE + 4'h3: oData = digest[159:128];
                DIGEST_REG_BASE + 4'h2: oData = digest[191:160];
                DIGEST_REG_BASE + 4'h1: oData = digest[223:192];
                DIGEST_REG_BASE + 4'h0: oData = digest[255:224];
                
                default: oData <= 32'b0;
            endcase
        end
        else oData <= 32'b0; // Default output when not reading
    end

endmodule