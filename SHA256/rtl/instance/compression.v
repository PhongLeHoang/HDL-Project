`default_nettype none
module compression(
    input wire          clk,
    input wire          reset_n,
    input wire          init,
    input wire          ready,
    input wire          digest_update,
    input wire          done,
    input wire   [31:0] W_i,
    input wire   [31:0] K_i,
    output wire [255:0] digest
);
//================================================================
// Khá»Ÿi táº¡o & cáº­p nháº­t H0
//================================================================
    localparam H_constant_0 = 32'h6a09e667;
    localparam H_constant_1 = 32'hbb67ae85;
    localparam H_constant_2 = 32'h3c6ef372;
    localparam H_constant_3 = 32'ha54ff53a;
    localparam H_constant_4 = 32'h510e527f;
    localparam H_constant_5 = 32'h9b05688c;
    localparam H_constant_6 = 32'h1f83d9ab;
    localparam H_constant_7 = 32'h5be0cd19;

    reg [31:0] H0;
    reg [31:0] H1;
    reg [31:0] H2;
    reg [31:0] H3;
    reg [31:0] H4;
    reg [31:0] H5;
    reg [31:0] H6;
    reg [31:0] H7;
    reg [31:0] a_i;
    reg [31:0] b_i;
    reg [31:0] c_i;
    reg [31:0] d_i;
    reg [31:0] e_i;
    reg [31:0] f_i;
    reg [31:0] g_i;
    reg [31:0] h_i;

    reg [31:0] CH, Maj, Sigma0, Sigma1, temp1, temp2;

    always @* begin
        Sigma1 =    {e_i[ 5:0], e_i[31: 6]}^
                    {e_i[10:0], e_i[31:11]}^
                    {e_i[24:0], e_i[31:25]};
        Sigma0 =    {a_i[ 1:0], a_i[31: 2]}^
                    {a_i[12:0], a_i[31:13]}^
                    {a_i[21:0], a_i[31:22]};
        Maj    =    (a_i & b_i) ^ (a_i & c_i) ^ (b_i & c_i);
        CH     =    (e_i & f_i) ^ (~e_i & g_i);
        temp1   =     h_i + K_i + W_i + CH + Sigma1;
        temp2   =     Sigma0 + Maj;
    end

    always @ (posedge clk, negedge reset_n) begin
        if(!reset_n) begin
            H0 <= 32'h0;
            H1 <= 32'h0;
            H2 <= 32'h0;
            H3 <= 32'h0;
            H4 <= 32'h0;
            H5 <= 32'h0;
            H6 <= 32'h0;
            H7 <= 32'h0;
            a_i <= 0;
            b_i <= 0;
            c_i <= 0;
            d_i <= 0;
            e_i <= 0;
            f_i <= 0;
            g_i <= 0;
            h_i <= 0;
        end
        else begin
            if(init) begin // Khá»Ÿi táº¡o giÃ¡ trá»‹ háº±ng sá»‘ H0
                H0 <= H_constant_0;
                H1 <= H_constant_1;
                H2 <= H_constant_2;
                H3 <= H_constant_3;
                H4 <= H_constant_4;
                H5 <= H_constant_5;
                H6 <= H_constant_6;
                H7 <= H_constant_7;
                a_i <= H_constant_0;
                b_i <= H_constant_1;
                c_i <= H_constant_2;
                d_i <= H_constant_3;
                e_i <= H_constant_4;
                f_i <= H_constant_5;
                g_i <= H_constant_6;
                h_i <= H_constant_7;
            end
            if(digest_update) begin // cáº­p nháº­t H0 cho trÆ°á»ng há»£p message Ä‘Æ°á»£c chia lÃ m nhiá»u block
                H0 <= H0 + a_i;
                H1 <= H1 + b_i;
                H2 <= H2 + c_i;
                H3 <= H3 + d_i;
                H4 <= H4 + e_i;
                H5 <= H5 + f_i;
                H6 <= H6 + g_i;
                H7 <= H7 + h_i;
                a_i <= H0 + a_i;
                b_i <= H1 + b_i;
                c_i <= H2 + c_i;
                d_i <= H3 + d_i;
                e_i <= H4 + e_i;
                f_i <= H5 + f_i;
                g_i <= H6 + g_i;
                h_i <= H7 + h_i;
            end
            if(ready) begin // thá»±c hiá»‡n hÃ m bÄƒm SHA256 (64 duty cycle)
                a_i <= temp1 + temp2;
                b_i <= a_i;
                c_i <= b_i;
                d_i <= c_i;
                e_i <= d_i + temp1;
                f_i <= e_i;
                g_i <= f_i;
                h_i <= g_i;
            end
        end
    end

    assign digest = (done) ? {H0, H1, H2, H3, H4, H5, H6, H7} : 256'h0;
endmodule