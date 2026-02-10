`timescale 1ns / 1ps
module tb_piso();
    reg clk, rst, load;
    reg [3:0] pi;
    wire so;
    piso uut(clk, rst, load, pi, so);
    initial begin clk = 0; forever #5 clk = ~clk; end
    initial begin
        rst = 1; load = 0; pi = 4'b1011; #10 rst = 0;
        #10 load = 1; #10 load = 0;
        #40 $finish;
    end
endmodule