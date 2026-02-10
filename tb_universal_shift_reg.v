timescale 1ns / 1ps
module tb_universal_shift_reg();
    reg clk, rst, s_in_left, s_in_right;
    reg [1:0] s;
    reg [3:0] p_in;
    wire [3:0] q;

    universal_shift_reg uut (clk, rst, s, p_in, s_in_left, s_in_right, q);

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst = 1; s = 2'b00; p_in = 4'b1011; s_in_left = 1; s_in_right = 0; #10;
        rst = 0; 
        s = 2'b11; #10; // Parallel Load 1011
        s = 2'b10; #10; // Shift Left -> 0111
        s = 2'b01; #10; // Shift Right -> 0011
        s = 2'b00; #10; // Hold -> 0011
        #20 $finish;
    end
endmodule
