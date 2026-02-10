timescale 1ns / 1ps
module tb_siso();
    reg clk, rst, si;
    wire so;
    siso uut(clk, rst, si, so);
    initial begin clk = 0; forever #5 clk = ~clk; end
    initial begin
        rst = 1; si = 0; #10 rst = 0;
        #10 si = 1; #10 si = 0; #10 si = 1; #10 si = 1;
        #40 $finish;
    end
endmodule