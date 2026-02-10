`timescale 1ns / 1ps
module pipo (input clk, rst, input [3:0] pi, output reg [3:0] po);
    always @(posedge clk) begin
        if (rst) po <= 4'b0000;
        else     po <= pi;
    end
endmodule