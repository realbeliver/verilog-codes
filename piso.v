`timescale 1ns / 1ps
module piso (input clk, rst, load, input [3:0] pi, output so);
    reg [3:0] q;
    always @(posedge clk) begin
        if (rst) q <= 4'b0000;
        else if (load) q <= pi;
        else q <= {q[2:0], 1'b0};
    end
    assign so = q[3];
endmodule