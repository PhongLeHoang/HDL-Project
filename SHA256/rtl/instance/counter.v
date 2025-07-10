`default_nettype none
module counter(
    input wire        clk,
    input wire        reset_n,
    input wire        ready,
    output wire [5:0] round_idx
);
    reg [5:0] round_idx_reg;
    assign round_idx = round_idx_reg;
    reg [5:0] round_idx_next;

    always @* begin
        if(ready) begin
            round_idx_next <= round_idx_reg + 1'b1;
        end
        else begin
            round_idx_next <= 6'd0;
        end 
    end

    always @ (posedge clk, negedge reset_n) begin
        if(!reset_n) begin
            round_idx_reg   <= 6'd0;
        end
        else begin
            round_idx_reg <= round_idx_next;
        end
    end
endmodule