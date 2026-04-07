// ---------------------------------------------------------------------------
// 15-bit Carry Lookahead Adder core (bitwise G/P and explicit carry chain)
// ---------------------------------------------------------------------------
module cla_15bit (
    input  logic [14:0] a,
    input  logic [14:0] b,
    input  logic        cin,
    output logic [14:0] sum,
    output logic        cout
);
    logic [14:0] g;
    logic [14:0] p;
    logic [15:0] c;

    assign g = a & b;
    assign p = a ^ b;

    assign c[0]  = cin;
    assign c[1]  = g[0]  | (p[0]  & c[0]);
    assign c[2]  = g[1]  | (p[1]  & c[1]);
    assign c[3]  = g[2]  | (p[2]  & c[2]);
    assign c[4]  = g[3]  | (p[3]  & c[3]);
    assign c[5]  = g[4]  | (p[4]  & c[4]);
    assign c[6]  = g[5]  | (p[5]  & c[5]);
    assign c[7]  = g[6]  | (p[6]  & c[6]);
    assign c[8]  = g[7]  | (p[7]  & c[7]);
    assign c[9]  = g[8]  | (p[8]  & c[8]);
    assign c[10] = g[9]  | (p[9]  & c[9]);
    assign c[11] = g[10] | (p[10] & c[10]);
    assign c[12] = g[11] | (p[11] & c[11]);
    assign c[13] = g[12] | (p[12] & c[12]);
    assign c[14] = g[13] | (p[13] & c[13]);
    assign c[15] = g[14] | (p[14] & c[14]);

    assign sum  = p ^ c[14:0];
    assign cout = c[15];
endmodule

// ---------------------------------------------------------------------------
// 14-bit structural right barrel shifter (1/2/4/8 stages)
// ---------------------------------------------------------------------------
module barrel_shifter_14bit (
    input  logic [13:0] in_data,
    input  logic [3:0]  shift,
    output logic [13:0] out_data
);
    logic [13:0] s1;
    logic [13:0] s2;
    logic [13:0] s4;

    assign s1 = shift[0] ? {1'b0, in_data[13:1]} : in_data;
    assign s2 = shift[1] ? {2'b00, s1[13:2]}     : s1;
    assign s4 = shift[2] ? {4'b0000, s2[13:4]}   : s2;

    always_comb begin
        if (shift[3]) begin
            out_data = {8'b0, s4[13:8]};
        end else begin
            out_data = s4;
        end
    end
endmodule

// ---------------------------------------------------------------------------
// 14-bit leading-zero detector (tree-like pair selection)
// ---------------------------------------------------------------------------
module lzd_14bit (
    input  logic [13:0] in_data,
    output logic [3:0]  lz_count,
    output logic        is_zero
);
    logic [1:0] sel_pair;
    logic [3:0] base;

    always_comb begin
        is_zero  = (in_data == 14'b0);
        lz_count = 4'd14;
        sel_pair = 2'd0;
        base     = 4'd0;

        if (!is_zero) begin
            if (in_data[13:12] != 2'b00) begin
                sel_pair = in_data[13:12];
                base     = 4'd0;
            end else if (in_data[11:10] != 2'b00) begin
                sel_pair = in_data[11:10];
                base     = 4'd2;
            end else if (in_data[9:8] != 2'b00) begin
                sel_pair = in_data[9:8];
                base     = 4'd4;
            end else if (in_data[7:6] != 2'b00) begin
                sel_pair = in_data[7:6];
                base     = 4'd6;
            end else if (in_data[5:4] != 2'b00) begin
                sel_pair = in_data[5:4];
                base     = 4'd8;
            end else if (in_data[3:2] != 2'b00) begin
                sel_pair = in_data[3:2];
                base     = 4'd10;
            end else begin
                sel_pair = in_data[1:0];
                base     = 4'd12;
            end

            if (sel_pair[1]) begin
                lz_count = base;
            end else begin
                lz_count = base + 4'd1;
            end
        end
    end
endmodule

// ---------------------------------------------------------------------------
// Normalization block:
//   - overflow-right shift (mant[14]==1)
//   - leading-zero left shift via LZD
//   - exact-zero detection
// ---------------------------------------------------------------------------
module normalize_unit (
    input  logic signed [6:0] exp_in,
    input  logic [14:0]       mant_in,
    output logic signed [6:0] exp_out,
    output logic [13:0]       mant_out,
    output logic              zero_out,
    output logic [3:0]        shift_amt
);
    logic [13:0] mant_no_overflow;
    logic [3:0]  lz_count;
    logic        is_zero;

    lzd_14bit u_lzd (
        .in_data(mant_no_overflow),
        .lz_count(lz_count),
        .is_zero(is_zero)
    );

    always_comb begin
        zero_out          = 1'b0;
        exp_out           = exp_in;
        mant_out          = mant_in[13:0];
        shift_amt         = 4'd0;
        mant_no_overflow  = mant_in[13:0];

        if (mant_in == 15'b0) begin
            zero_out  = 1'b1;
            exp_out   = '0;
            mant_out  = '0;
            shift_amt = 4'd0;
        end else if (mant_in[14]) begin
            exp_out   = exp_in + 7'sd1;
            mant_out  = mant_in[14:1];
            shift_amt = 4'd0;
        end else if (is_zero) begin
            zero_out  = 1'b1;
            exp_out   = '0;
            mant_out  = '0;
            shift_amt = 4'd0;
        end else begin
            shift_amt = lz_count;
            mant_out  = mant_no_overflow << lz_count;
            exp_out   = exp_in - $signed({3'b000, lz_count});
        end
    end
endmodule

// ---------------------------------------------------------------------------
// SEM20 pipelined adder top
//   S1: unpack
//   S2: align
//   S3: add/sub (CLA)
//   S4: normalize
//   S5: pack
// ---------------------------------------------------------------------------
module sem20_adder_top (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        valid_in,
    input  logic [19:0] a,
    input  logic [19:0] b,
    output logic        valid_out,
    output logic [19:0] result,
    output logic [3:0]  dbg_exp_diff,
    output logic [13:0] dbg_m_big,
    output logic [13:0] dbg_m_small_shifted,
    output logic [14:0] dbg_cla_a,
    output logic [14:0] dbg_cla_b,
    output logic [14:0] dbg_cla_sum,
    output logic [3:0]  dbg_norm_shift
);
    // S1 regs
    logic        s1_valid;
    logic        s1_sign_a, s1_sign_b;
    logic signed [6:0] s1_exp_a, s1_exp_b;
    logic [13:0] s1_mant_a, s1_mant_b;

    // S2 regs
    logic        s2_valid;
    logic        s2_sign_big, s2_sign_small;
    logic signed [6:0] s2_exp_big;
    logic [13:0] s2_mant_big, s2_mant_small_shifted;
    logic [3:0]  s2_exp_diff;

    // S3 regs
    logic        s3_valid;
    logic        s3_sign_res;
    logic signed [6:0] s3_exp;
    logic [14:0] s3_sum;
    logic [14:0] s3_cla_a, s3_cla_b;

    // S4 regs
    logic        s4_valid;
    logic        s4_sign_res;
    logic signed [6:0] s4_exp_norm;
    logic [13:0] s4_mant_norm;
    logic        s4_zero;
    logic [3:0]  s4_shift_amt;

    logic [13:0] s2_shifted_small_comb;
    logic [3:0]  s2_shift_amt_comb;
    logic signed [6:0] exp_delta_abs;
    logic [14:0] s3_cla_a_comb, s3_cla_b_comb;
    logic        s3_cla_cin_comb, s3_sign_res_comb;
    logic [14:0] cla_sum_comb;
    logic        cla_cout_comb;
    logic signed [6:0] norm_exp_comb;
    logic [13:0] norm_mant_comb;
    logic        norm_zero_comb;
    logic [3:0]  norm_shift_comb;
    logic [5:0]  s5_exp_field;
    logic        s5_force_zero;

    barrel_shifter_14bit u_align_shifter (
        .in_data ((s1_exp_a >= s1_exp_b) ? s1_mant_b : s1_mant_a),
        .shift   (s2_shift_amt_comb),
        .out_data(s2_shifted_small_comb)
    );

    cla_15bit u_cla (
        .a   (s3_cla_a_comb),
        .b   (s3_cla_b_comb),
        .cin (s3_cla_cin_comb),
        .sum (cla_sum_comb),
        .cout(cla_cout_comb)
    );

    normalize_unit u_norm (
        .exp_in   (s3_exp),
        .mant_in  (s3_sum),
        .exp_out  (norm_exp_comb),
        .mant_out (norm_mant_comb),
        .zero_out (norm_zero_comb),
        .shift_amt(norm_shift_comb)
    );

    // Exponent difference and alignment shift amount generation
    always_comb begin
        if (s1_exp_a >= s1_exp_b) begin
            exp_delta_abs = s1_exp_a - s1_exp_b;
        end else begin
            exp_delta_abs = s1_exp_b - s1_exp_a;
        end

        if (exp_delta_abs > 7'sd13) begin
            s2_shift_amt_comb = 4'd14;
        end else begin
            s2_shift_amt_comb = exp_delta_abs[3:0];
        end
    end

    // CLA operand/sign preparation for same-sign add or opposite-sign subtract
    always_comb begin
        s3_cla_a_comb    = 15'b0;
        s3_cla_b_comb    = 15'b0;
        s3_cla_cin_comb  = 1'b0;
        s3_sign_res_comb = s2_sign_big;

        if (s2_sign_big == s2_sign_small) begin
            s3_cla_a_comb    = {1'b0, s2_mant_big};
            s3_cla_b_comb    = {1'b0, s2_mant_small_shifted};
            s3_cla_cin_comb  = 1'b0;
            s3_sign_res_comb = s2_sign_big;
        end else if (s2_mant_big >= s2_mant_small_shifted) begin
            s3_cla_a_comb    = {1'b0, s2_mant_big};
            s3_cla_b_comb    = ~{1'b0, s2_mant_small_shifted};
            s3_cla_cin_comb  = 1'b1;
            s3_sign_res_comb = s2_sign_big;
        end else begin
            s3_cla_a_comb    = {1'b0, s2_mant_small_shifted};
            s3_cla_b_comb    = ~{1'b0, s2_mant_big};
            s3_cla_cin_comb  = 1'b1;
            s3_sign_res_comb = s2_sign_small;
        end
    end

    // Final pack exponent handling (overflow clamp / underflow-to-zero)
    always_comb begin
        s5_exp_field  = s4_exp_norm[5:0];
        s5_force_zero = 1'b0;

        if (s4_exp_norm > 7'sd31) begin
            s5_exp_field = 6'b01_1111;
        end else if (s4_exp_norm < -7'sd32) begin
            s5_force_zero = 1'b1;
        end
    end

    // Pipeline registers for S1..S5 and debug capture
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s1_valid <= 1'b0;
            s2_valid <= 1'b0;
            s3_valid <= 1'b0;
            s4_valid <= 1'b0;
            valid_out <= 1'b0;
            result <= 20'b0;
            dbg_exp_diff <= '0;
            dbg_m_big <= '0;
            dbg_m_small_shifted <= '0;
            dbg_cla_a <= '0;
            dbg_cla_b <= '0;
            dbg_cla_sum <= '0;
            dbg_norm_shift <= '0;
        end else begin
            // S1: unpack
            s1_valid  <= valid_in;
            s1_sign_a <= a[19];
            s1_sign_b <= b[19];
            s1_exp_a  <= $signed(a[18:13]);
            s1_exp_b  <= $signed(b[18:13]);
            if (a[18:0] == 19'b0) begin
                s1_mant_a <= 14'b0;
            end else begin
                s1_mant_a <= {1'b1, a[12:0]};
            end
            if (b[18:0] == 19'b0) begin
                s1_mant_b <= 14'b0;
            end else begin
                s1_mant_b <= {1'b1, b[12:0]};
            end

            // S2: align
            s2_valid <= s1_valid;
            s2_exp_diff <= s2_shift_amt_comb;
            if (s1_exp_a >= s1_exp_b) begin
                s2_exp_big            <= s1_exp_a;
                s2_sign_big           <= s1_sign_a;
                s2_sign_small         <= s1_sign_b;
                s2_mant_big           <= s1_mant_a;
                s2_mant_small_shifted <= (s2_shift_amt_comb > 4'd13) ? 14'b0 : s2_shifted_small_comb;
            end else begin
                s2_exp_big            <= s1_exp_b;
                s2_sign_big           <= s1_sign_b;
                s2_sign_small         <= s1_sign_a;
                s2_mant_big           <= s1_mant_b;
                s2_mant_small_shifted <= (s2_shift_amt_comb > 4'd13) ? 14'b0 : s2_shifted_small_comb;
            end

            // S3: add/sub (CLA)
            s3_valid <= s2_valid;
            s3_exp   <= s2_exp_big;
            s3_cla_a <= s3_cla_a_comb;
            s3_cla_b <= s3_cla_b_comb;
            s3_sign_res <= s3_sign_res_comb;
            s3_sum <= cla_sum_comb;

            // S4: normalize
            s4_valid     <= s3_valid;
            s4_sign_res  <= s3_sign_res;
            s4_exp_norm  <= norm_exp_comb;
            s4_mant_norm <= norm_mant_comb;
            s4_zero      <= norm_zero_comb;
            s4_shift_amt <= norm_shift_comb;

            // S5: pack
            valid_out <= s4_valid;
            if (s4_zero || s5_force_zero) begin
                result <= 20'b0;
            end else begin
                result[19]    <= s4_sign_res;
                result[18:13] <= s5_exp_field;
                result[12:0]  <= s4_mant_norm[12:0];
            end

            // debug visibility
            dbg_exp_diff        <= s2_exp_diff;
            dbg_m_big           <= s2_mant_big;
            dbg_m_small_shifted <= s2_mant_small_shifted;
            dbg_cla_a           <= s3_cla_a;
            dbg_cla_b           <= s3_cla_b;
            dbg_cla_sum         <= s3_sum;
            dbg_norm_shift      <= s4_shift_amt;
        end
    end
endmodule
