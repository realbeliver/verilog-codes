`timescale 1ns / 1ps
module tb_pipo();
    reg clk, rst;
    reg [3:0] pi;
    wire [3:0] po;
    pipo uut(clk, rst, pi, po);
    initial begin clk = 0; forever #5 clk = ~clk; end
    initial begin
        rst = 1; pi = 4'b0000; #10 rst = 0;
        #10 pi = 4'b1101; #10 pi = 4'b1010;
        #20 $finish;
    end
endmodule