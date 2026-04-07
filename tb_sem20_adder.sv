`timescale 1ns/1ps

module tb_sem20_adder;
    // DUT interface
    logic clk;
    logic rst_n;
    logic valid_in;
    logic [19:0] a;
    logic [19:0] b;
    logic valid_out;
    logic [19:0] result;
    logic [3:0]  dbg_exp_diff;
    logic [13:0] dbg_m_big;
    logic [13:0] dbg_m_small_shifted;
    logic [14:0] dbg_cla_a;
    logic [14:0] dbg_cla_b;
    logic [14:0] dbg_cla_sum;
    logic [3:0]  dbg_norm_shift;

    int total_tests;
    int pass_count;
    int fail_count;

    localparam int MAX_TESTS = 8192;
    logic [19:0] exp_mem [0:MAX_TESTS-1];
    logic [19:0] a_mem   [0:MAX_TESTS-1];
    logic [19:0] b_mem   [0:MAX_TESTS-1];
    int unsigned wr_ptr;
    int unsigned rd_ptr;

    sem20_adder_top dut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .a(a),
        .b(b),
        .valid_out(valid_out),
        .result(result),
        .dbg_exp_diff(dbg_exp_diff),
        .dbg_m_big(dbg_m_big),
        .dbg_m_small_shifted(dbg_m_small_shifted),
        .dbg_cla_a(dbg_cla_a),
        .dbg_cla_b(dbg_cla_b),
        .dbg_cla_sum(dbg_cla_sum),
        .dbg_norm_shift(dbg_norm_shift)
    );

    always #5 clk = ~clk;

    // Convert 6-bit SEM exponent field (two's complement) to signed integer
    function automatic int signed exp6_to_int(input logic [5:0] e6);
        exp6_to_int = $signed({e6[5], e6});
    endfunction

    // Clamp integer exponent back into SEM20 representable range [-32, 31]
    function automatic logic [5:0] int_to_exp6(input int e);
        logic signed [6:0] tmp;
        begin
            if (e > 31) begin
                tmp = 7'sd31;
            end else if (e < -32) begin
                tmp = -7'sd32;
            end else begin
                tmp = e;
            end
            int_to_exp6 = tmp[5:0];
        end
    endfunction

    // Decode SEM20 packed number into real value for golden reference math
    function automatic real sem20_to_real(input logic [19:0] x);
        int signed e;
        real frac;
        begin
            if (x == 20'b0) begin
                sem20_to_real = 0.0;
            end else begin
                e = exp6_to_int(x[18:13]);
                frac = 1.0 + (x[12:0] / 8192.0);
                if (x[19]) sem20_to_real = -frac * (2.0 ** e);
                else       sem20_to_real =  frac * (2.0 ** e);
            end
        end
    endfunction

    // Quantize real value back into SEM20 packed representation
    function automatic logic [19:0] real_to_sem20(input real v);
        real av;
        real norm;
        int e;
        int mant;
        logic sign;
        logic [19:0] out;
        begin
            out = 20'b0;
            if ((v < 1e-20) && (v > -1e-20)) begin
                real_to_sem20 = 20'b0;
            end else begin
                sign = (v < 0.0);
                av = sign ? -v : v;

                e = $rtoi($floor($ln(av) / $ln(2.0)));
                norm = av / (2.0 ** e);

                while (norm >= 2.0) begin
                    norm = norm / 2.0;
                    e = e + 1;
                end
                while (norm < 1.0) begin
                    norm = norm * 2.0;
                    e = e - 1;
                end

                mant = $rtoi(((norm - 1.0) * 8192.0) + 0.5);
                if (mant >= 8192) begin
                    mant = 0;
                    e = e + 1;
                end

                out[19]    = sign;
                out[18:13] = int_to_exp6(e);
                out[12:0]  = mant[12:0];
                real_to_sem20 = out;
            end
        end
    endfunction

    // Bit-accurate SEM20 adder reference model (matches DUT arithmetic behavior)
    function automatic logic [19:0] sem20_add_ref(input logic [19:0] aa, input logic [19:0] bb);
        int signed exp_a, exp_b, exp_big, exp_norm;
        logic sign_a, sign_b, sign_big, sign_small, sign_res;
        logic [13:0] mant_a, mant_b, mant_big, mant_small, mant_small_shifted, mant_norm;
        logic [14:0] sum15;
        int diff, sh, lz;
        logic [19:0] out;
        begin
            out = 20'b0;
            sign_a = aa[19];
            sign_b = bb[19];
            exp_a  = exp6_to_int(aa[18:13]);
            exp_b  = exp6_to_int(bb[18:13]);
            mant_a = (aa[18:0] == 19'b0) ? 14'b0 : {1'b1, aa[12:0]};
            mant_b = (bb[18:0] == 19'b0) ? 14'b0 : {1'b1, bb[12:0]};

            if (exp_a >= exp_b) begin
                exp_big   = exp_a;
                sign_big  = sign_a;
                sign_small= sign_b;
                mant_big  = mant_a;
                mant_small= mant_b;
                diff      = exp_a - exp_b;
            end else begin
                exp_big   = exp_b;
                sign_big  = sign_b;
                sign_small= sign_a;
                mant_big  = mant_b;
                mant_small= mant_a;
                diff      = exp_b - exp_a;
            end

            sh = (diff > 13) ? 14 : diff;
            if (sh > 13) mant_small_shifted = 14'b0;
            else         mant_small_shifted = mant_small >> sh;

            if (sign_big == sign_small) begin
                sum15    = {1'b0, mant_big} + {1'b0, mant_small_shifted};
                sign_res = sign_big;
            end else if (mant_big >= mant_small_shifted) begin
                sum15    = {1'b0, mant_big} - {1'b0, mant_small_shifted};
                sign_res = sign_big;
            end else begin
                sum15    = {1'b0, mant_small_shifted} - {1'b0, mant_big};
                sign_res = sign_small;
            end

            if (sum15 == 15'b0) begin
                sem20_add_ref = 20'b0;
            end else begin
                exp_norm = exp_big;
                if (sum15[14]) begin
                    mant_norm = sum15[14:1];
                    exp_norm  = exp_big + 1;
                end else begin
                    mant_norm = sum15[13:0];
                    lz = 0;
                    while ((lz < 14) && (mant_norm[13] == 1'b0)) begin
                        mant_norm = mant_norm << 1;
                        lz = lz + 1;
                    end
                    exp_norm = exp_big - lz;
                end

                if (exp_norm < -32) begin
                    sem20_add_ref = 20'b0;
                end else begin
                    out[19] = sign_res;
                    if (exp_norm > 31) out[18:13] = 6'b01_1111;
                    else               out[18:13] = int_to_exp6(exp_norm);
                    out[12:0] = mant_norm[12:0];
                    sem20_add_ref = out;
                end
            end
        end
    endfunction

    // Drive one transaction and enqueue expected packed result
    task automatic drive_and_queue(input logic [19:0] aa, input logic [19:0] bb);
        real ra;
        real rb;
        logic [19:0] exp;
        begin
            @(posedge clk);
            valid_in <= 1'b1;
            a <= aa;
            b <= bb;

            ra = sem20_to_real(aa);
            rb = sem20_to_real(bb);
            exp = sem20_add_ref(aa, bb);
            exp_mem[wr_ptr] = exp;
            a_mem[wr_ptr]   = aa;
            b_mem[wr_ptr]   = bb;
            wr_ptr = wr_ptr + 1;
            total_tests++;
        end
    endtask

    // Stop input traffic after stimulus generation
    task automatic stop_drive;
        begin
            @(posedge clk);
            valid_in <= 1'b0;
            a <= 20'b0;
            b <= 20'b0;
        end
    endtask

    // Scoreboard check at DUT output (queue head corresponds to current output)
    // Keep pass/fail counters driven from this single process to satisfy xsim.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pass_count <= 0;
            fail_count <= 0;
        end else if (valid_out) begin
            logic [19:0] exp_val;
            logic [19:0] a_val;
            logic [19:0] b_val;
            if (rd_ptr == wr_ptr) begin
                $display("ERROR: Output valid with empty expectation queue");
                fail_count++;
            end else begin
                exp_val = exp_mem[rd_ptr];
                a_val   = a_mem[rd_ptr];
                b_val   = b_mem[rd_ptr];
                rd_ptr  = rd_ptr + 1;
                if (result !== exp_val) begin
                    fail_count++;
                    $display("MISMATCH: A=%h B=%h EXP=%h GOT=%h | dbg_diff=%0d m_big=%h m_small_s=%h cla_a=%h cla_b=%h cla_sum=%h norm_sh=%0d",
                             a_val, b_val, exp_val, result, dbg_exp_diff, dbg_m_big, dbg_m_small_shifted,
                             dbg_cla_a, dbg_cla_b, dbg_cla_sum, dbg_norm_shift);
                end else begin
                    pass_count++;
                end
            end
        end
    end

    // Directed edge/corner patterns
    task automatic run_directed;
        logic [19:0] z;
        begin
            z = 20'b0;
            drive_and_queue(20'b0_000000_0000000000000, 20'b0_000000_0000000000000);
            drive_and_queue(20'b0_000010_1000000000000, 20'b0_000010_0100000000000);
            drive_and_queue(20'b0_011111_1111111111111, 20'b0_000000_1111111111111);
            drive_and_queue(20'b0_000101_1111111111111, 20'b1_000101_1111111111110);
            drive_and_queue(20'b1_000001_0000000000001, 20'b0_000001_0000000000001);
            drive_and_queue(z, 20'b0_000100_1000000000000);
            drive_and_queue(20'b1_000100_1000000000000, z);
        end
    endtask

    // Randomized regression
    task automatic run_random(input int count);
        logic [19:0] ra;
        logic [19:0] rb;
        int i;
        begin
            for (i = 0; i < count; i++) begin
                ra[19]    = $urandom_range(0, 1);
                ra[18:13] = $urandom_range(0, 63);
                ra[12:0]  = $urandom_range(0, 8191);

                rb[19]    = $urandom_range(0, 1);
                rb[18:13] = $urandom_range(0, 63);
                rb[12:0]  = $urandom_range(0, 8191);

                drive_and_queue(ra, rb);
            end
        end
    endtask

    initial begin
        // Reset and initialization
        clk = 1'b0;
        rst_n = 1'b0;
        valid_in = 1'b0;
        a = '0;
        b = '0;
        total_tests = 0;
        wr_ptr = 0;
        rd_ptr = 0;

        $dumpfile("tb_sem20_adder.vcd");
        $dumpvars(0, tb_sem20_adder);

        repeat (3) @(posedge clk);
        rst_n = 1'b1;

        run_directed();
        run_random(2000);
        stop_drive();

        repeat (10) @(posedge clk);

        $display("TOTAL=%0d PASS=%0d FAIL=%0d", total_tests, pass_count, fail_count);
        if ((fail_count == 0) && (pass_count == total_tests)) begin
            $display("PASS");
        end else begin
            $display("FAIL");
        end
        $finish;
    end
endmodule
