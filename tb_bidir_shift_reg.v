`timescale 1ns / 1ps
module tb_bidir_shift_reg();
    reg clk, rst, dir, si;
    wire [3:0] q;

    bidir_shift_reg uut (clk, rst, dir, si, q);

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst = 1; dir = 1; si = 1; #10;
        rst = 0; #10; // Shift Left
        si = 0; #10;
        si = 1; #10;
        dir = 0; #10; // Shift Right
        si = 0; #10;
        #20 $finish;
    end
endmodule