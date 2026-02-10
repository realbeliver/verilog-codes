`timescale 1ns / 1ps
module universal_shift_reg (
    input clk,
    input rst,
    input [1:0] s,
    input [3:0] p_in,
    input s_in_left,
    input s_in_right,
    output reg [3:0] q
);
    always @(posedge clk) begin
        if (rst)
            q <= 4'b0000;
        else begin
            case (s)
                2'b00: q <= q;
                2'b01: q <= {s_in_right, q[3:1]};
                2'b10: q <= {q[2:0], s_in_left};
                2'b11: q <= p_in;
                default: q <= q;
            endcase
        end
    end
endmodule