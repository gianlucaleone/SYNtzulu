`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 28.10.2022 16:14:22
// Design Name: 
// Module Name: adder_simd
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

// This module describes SIMD Inference 
// 4 small adders can be packed into signle DSP block

// Note : SV constructs are used, Compile this with System Verilog Mode


// Apply this attribute on the module definition
(* use_dsp = "simd" *)
module adder_simd
    #(
    parameter N = 2,    // Number of Adders
    parameter W = 15   // Width of the Adders
    )
    (
    input clk, en,
    input [W-1:0] a_0, a_1,
    input [W-1:0] b_0, b_1,
    output reg signed [W:0] out_0,
    output reg signed [W:0] out_1
    );


                   
integer i;
logic signed [W-1:0] a_r [N-1:0];
logic signed [W-1:0] b_r [N-1:0];

always @ (posedge clk)
     if(en)
      begin 
      a_r[0] <= a_0;
      b_r[0] <= b_0;
      out_0 <= a_r[0] + b_r[0];
      a_r[1] <= a_1;
      b_r[1] <= b_1;
      out_1 <= a_r[1] + b_r[1];
      end   

endmodule
