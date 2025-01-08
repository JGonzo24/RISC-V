`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/16/2024 05:28:11 PM
// Design Name: 
// Module Name: ALU_top_module
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module ALU_top_module(
input [31:0] op_1,
input [31:0] op_2,
input [3:0]  alu_fun,
output reg [31:0] result
    );
 
always @(*)
    begin
    case(alu_fun)
    4'b0000: result = op_1 + op_2;
    4'b0001: result = op_1 << op_2[4:0];
    4'b0010: result = $signed(op_1) < $signed(op_2) ? 1 : 0;
    4'b0011: result = op_1 < op_2 ? 1 : 0;
    4'b0100: result = op_1 ^ op_2;
    4'b0101: result = op_1 >> op_2[4:0];
    4'b0110: result = op_1 | op_2;
    4'b0111: result = op_1 & op_2;
    4'b1000: result = op_1 - op_2;
    4'b1001: result = op_1;
    4'b1101: result = $signed(op_1) >>> op_2[4:0];
    endcase
    end
endmodule
