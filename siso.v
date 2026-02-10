`timescale 1ns / 1ps
module siso (
    input  CLK,
    input  RST,
    input  SI,
    output SO
);

reg [3:0] Q;

always @(posedge CLK) begin
    if (RST)
        Q <= 4'b0000;
    else
        Q <= {Q[2:0], SI};
end

assign SO = Q[3];

endmodule
