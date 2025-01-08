`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.02.2024 
// Design Name: 
// Module Name: encoding_slot_ieeg
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
//////////////////////////////////////////////////////////////////////////////////


module encoding_slot_emg
#(
    parameter CHANNELS = 128,
    parameter DW = 8
)
(
    input clk, rst,
    input en,
    input signed [DW-1:0] data_in,
    
    output [3:0] spike_bin,
    output valid_bin,
    output active_group_out_bin
    );

 localparam SPIKE  = 4;
 localparam CHANNELS_L2 = clogb2(CHANNELS-1);

//////////////////////////////////////////////////////////////////////////////////
//   ____       _ _                              _       _       _              //
//  |  _ \  ___| | |_ __ _   _ __ ___   ___   __| |_   _| | __ _| |_ ___  _ __  //
//  | | | |/ _ \ | __/ _` | | '_ ` _ \ / _ \ / _` | | | | |/ _` | __/ _ \| '__| //
//  | |_| |  __/ | || (_| | | | | | | | (_) | (_| | |_| | | (_| | || (_) | |    //
//  |____/ \___|_|\__\__,_| |_| |_| |_|\___/ \__,_|\__,_|_|\__,_|\__\___/|_|    //
//                                                                              //
//////////////////////////////////////////////////////////////////////////////////

/*
module delta_modulator #(
    parameter WIDTH = 16
    )
(
  input wire clk,           // Clock input
  input wire rst,           // Reset input
  input wire en,
  input wire signed [WIDTH-1:0] samples, // Analog input samples (8-bit resolution)
  input wire [WIDTH-1:0] delta, 
  output reg pos_spike, neg_spike,     // Delta modulation output
  output reg valid
);
*/

wire [1:0] dm_spike;
wire pos_spike, neg_spike;
wire dm_valid;

delta_modulator_multichannel #(.CHANNELS(CHANNELS),.WIDTH(DW)) 
	delta_modulator_1 (.clk(clk),.rst(rst),.en(en),.samples(data_in),.pos_spike(pos_spike),.neg_spike(neg_spike),.valid(dm_valid));

// 2-to-4 bits
wire ag1,ag2;
wire [1:0] s2p_out_1, s2p_out_2;
s2p #(.P(2)) s2p_1 ( .clk(clk), .rst(rst), .en(dm_valid), .spike_s(pos_spike),.spike_p(s2p_out_1),.valid(valid_bin), .active_group(ag1));
s2p #(.P(2)) s2p_2 ( .clk(clk), .rst(rst), .en(dm_valid), .spike_s(neg_spike),.spike_p(s2p_out_2),.valid(), .active_group(ag2));
assign active_group_out_bin = ag1 | ag2;
assign spike_bin = {s2p_out_1[1],s2p_out_2[1],s2p_out_1[0],s2p_out_2[0]};

//  The following function calculates the address width based on specified RAM depth
function integer clogb2;
  input integer depth;
    for (clogb2=0; depth>0; clogb2=clogb2+1)
      depth = depth >> 1;
endfunction   

endmodule

