`timescale 1ns / 1ps
module bidir_shift_reg (
    input clk,
    input rst,
    input dir,
    input si,
    output reg [3:0] q
);
    always @(posedge clk) begin
        if (rst)
            q <= 4'b0000;
        else if (dir)
            q <= {q[2:0], si};
        else
            q <= {si, q[3:1]};
    end
endmodule