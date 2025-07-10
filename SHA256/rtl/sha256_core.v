module sha256_core(
    input wire clk,
    input wire reset_n,
    input wire start,
    input wire last_block,
    input wire [511:0] block,
    output wire done,
    output wire digest_update,
    output wire [255:0] digest
);
    wire init, ready;
    wire [5:0] round_idx;
    wire [31:0] W_i, K_i;
    localparam [2:0] IDLE_STATE          = 3'd0,
                     INIT_STATE          = 3'd1,
                     PROCESS_STATE       = 3'd2,
                     DIGEST_UPDATE_STATE = 3'd3,
                     DONE_STATE          = 3'd4;
//=================================================================
// Instance of modules ===============================
    counter unit1(
        .clk(clk),
        .reset_n(reset_n),
        .ready(ready),
        .round_idx(round_idx)
    );
    message_schedule unit2(
        .clk       (clk       ),
        .reset_n   (reset_n   ),
        .init (init),
        .ready (ready),
        .digest_update (digest_update),
        .block    (block       ),
        .W_next    (W_i       )
    );
    k_constants unit3(
        .round_idx (round_idx),
        .K         (K_i      )
    );
    compression unit4(
        .clk        (clk            ),
        .reset_n    (reset_n        ),
        .init       (init           ),
        .ready      (ready          ),
        .digest_update (digest_update),
        .done       (done           ),
        .W_i        (W_i            ),
        .K_i        (K_i            ),
        .digest     (digest)
    );
//===========================================================
// FSM ===============================
    reg [2:0] next_state;
    reg [2:0] current_state;

// Tạo các cờ điều khiển từ trạng thái hiện tại & input
    assign init          = (current_state == INIT_STATE);
    assign ready         = (current_state == PROCESS_STATE);
    assign digest_update = (current_state == DIGEST_UPDATE_STATE);
    assign done          = (current_state == DONE_STATE);

    always @* begin
        case(current_state)
            IDLE_STATE: begin
                if(start) begin
                    next_state = INIT_STATE;
                end
                else begin
                    next_state = IDLE_STATE;
                end
            end

            INIT_STATE: begin
                next_state = PROCESS_STATE;
            end
            
            PROCESS_STATE: begin
                if (round_idx == 63) begin
                    next_state = DIGEST_UPDATE_STATE;
                end
                else begin
                    next_state = PROCESS_STATE;
                end
            end
            DIGEST_UPDATE_STATE: begin
                if(last_block) begin
                    next_state = DONE_STATE;
                end
                else begin
                    next_state = PROCESS_STATE;
                end
            end
            DONE_STATE: begin
                if(start) begin
                    next_state = INIT_STATE;
                end
                else begin
                    next_state = DONE_STATE;
                end
            end
            
            default: next_state = IDLE_STATE;
        endcase
    end

    always @(posedge clk or negedge reset_n) begin
        if(!reset_n) begin
            current_state <= IDLE_STATE;
        end
        else begin
            current_state <= next_state;
        end
    end
endmodule