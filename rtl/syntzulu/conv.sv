`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03.11.2022 12:02:52
// Design Name: 
// Module Name: conv
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



module conv
    #(
    parameter WEIGHTS = 4,     // Number of addends
    parameter DATA_WIDTH = 15 // Width of the Adders
    )
(
    input clk, rst, en, acc_clear_and_go, acc_clear,
    input signed [WEIGHTS*DATA_WIDTH-1:0] weights_in,
    input [WEIGHTS-1:0] spikes,
    
    output [2*(DATA_WIDTH+1)-1:0] out,
    output valid
    );
    
localparam SUM = WEIGHTS/2;
localparam PIPE = 5; // pipeline stages

wire signed [DATA_WIDTH-1:0] weights [WEIGHTS-1:0];
assign weights[0] = weights_in[DATA_WIDTH-1:0];
assign weights[1] = weights_in[2*DATA_WIDTH-1:DATA_WIDTH];
assign weights[2] = weights_in[3*DATA_WIDTH-1:2*DATA_WIDTH];
assign weights[3] = weights_in[4*DATA_WIDTH-1:3*DATA_WIDTH];

// enable shift
reg [PIPE-1:0] en_shift;
integer i;
always @(posedge clk)
    if (rst)
        en_shift <= 0;
    else
        begin
        en_shift[0] <= en;
        for(i=1;i<PIPE;i=i+1)
            en_shift[i] <= en_shift[i-1];
        end

// weights sorting
wire signed [DATA_WIDTH-1:0] weights_a [SUM-1:0]; 
wire signed [DATA_WIDTH-1:0] weights_b [SUM-1:0];  
assign weights_a[0] = weights[2];
assign weights_a[1] = weights[3];
assign weights_b[0] = weights[0];
assign weights_b[1] = weights[1];
// spike sorting (no that one)
wire [DATA_WIDTH-1:0] spike_a [SUM-1:0]; 
wire [DATA_WIDTH-1:0] spike_b [SUM-1:0]; 
assign spike_a[1] = {(DATA_WIDTH){spikes[WEIGHTS-1]}};     
assign spike_a[0] = {(DATA_WIDTH){spikes[WEIGHTS-2]}};     
assign spike_b[1] = {(DATA_WIDTH){spikes[WEIGHTS-3]}};     
assign spike_b[0] = {(DATA_WIDTH){spikes[WEIGHTS-4]}};     

// conv(weights*spike)
wire [DATA_WIDTH-1:0] anded_weights_a [SUM-1:0];     
wire [DATA_WIDTH-1:0] anded_weights_b [SUM-1:0];     
assign anded_weights_a[0] = weights_a[0] & spike_a[0];
assign anded_weights_a[1] = weights_a[1] & spike_a[1];
assign anded_weights_b[0] = weights_b[0] & spike_b[0];
assign anded_weights_b[1] = weights_b[1] & spike_b[1];

// simd adder
wire signed [DATA_WIDTH:0] double_adder_out [SUM-1:0];
wire double_adder_en;
assign double_adder_en = en | en_shift[0];
adder_simd #(SUM, DATA_WIDTH)
    double_adder
    (
    clk,
    double_adder_en,
    anded_weights_a[0],
    anded_weights_a[1],
    anded_weights_b[0],
    anded_weights_b[1],
    double_adder_out[0],
    double_adder_out[1]
    );

// accumulator
wire [2*(DATA_WIDTH+1)-1:0] acc_out;
accumulator
#(DATA_WIDTH+1)
acc
(
clk,en_shift[1],en_shift[2],en_shift[3],rst,acc_clear_and_go,acc_clear,double_adder_out[0],double_adder_out[1],acc_out
);

            
// output assignment
assign valid = en_shift[PIPE-1];
assign out = valid? acc_out:0;    

endmodule
