`timescale 1ns / 1ps
module sipo (input clk, rst, si, output [3:0] po);
    reg [3:0] q;
    always @(posedge clk) begin
        if (rst) q <= 4'b0000;
        else     q <= {q[2:0], si};
    end
    assign po = q;
endmodule