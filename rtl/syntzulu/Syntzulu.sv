`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10.11.2022 18:17:57
// Design Name: 
// Module Name: spike_decoder
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


module Syntzulu
#(

	parameter ENCODING_BYPASS = 0,
    parameter CHANNELS = 128,
    parameter ORDER = 2,
    parameter WINDOW = 8192,
    parameter REF_PERIOD = 16,
    parameter DW = 15,
    
    parameter WIDTH = 16,
    
	parameter MAX_SYNAPSES = 256,
	parameter MAX_NEURONS = 256,

    parameter INPUT_SPIKE_1 = 128, 
    parameter NEURON_1 = 64,  
    parameter WEIGHTS_FILE_1 = "weights_1.txt",
    parameter [13:0] current_decay_1 = 4096 - 4096,
    parameter [13:0] voltage_decay_1 = 4096 - 415,
    parameter [WIDTH-1:0] threshold_1 = 6,
    
    parameter INPUT_SPIKE_2 = NEURON_1,
    parameter NEURON_2 = 128,
    parameter WEIGHTS_FILE_2 = "weights_2.txt",
    parameter [13:0] current_decay_2 = 4096 - 4096,
    parameter [13:0] voltage_decay_2 = 4096 - 424,
    parameter [WIDTH-1:0] threshold_2 = 6,
    
    parameter INPUT_SPIKE_3 = NEURON_2, 
    parameter NEURON_3 = 64,  
    parameter WEIGHTS_FILE_3 = "weights_1.txt",
    parameter [13:0] current_decay_3 = 4096 - 4096,
    parameter [13:0] voltage_decay_3 = 4096 - 415,
    parameter [WIDTH-1:0] threshold_3 = 6,
    
    parameter INPUT_SPIKE_4 = NEURON_3,
    parameter NEURON_4 = 8,
    parameter WEIGHTS_FILE_4 = "weights_2.txt",
    parameter [13:0] current_decay_4 = 4096 - 4096,
    parameter [13:0] voltage_decay_4 = 4096 - 424,
    parameter [WIDTH-1:0] threshold_4 = 6,
    
    parameter WEIGHT_DEPTH_12 = 8192,
    parameter WEIGHT_DEPTH_34 = 8192
)
(
    input clk_enc, clk_snn, rst,
    input en,
    input signed [15:0] data_in,
    input detect,
	input encoding_bypass,
    
    output valid,
    output signed [WIDTH-1:0] v,
    output signed [WIDTH-1:0] f1,
    output signed [WIDTH-1:0] f2,
    output signed [WIDTH-1:0] f3,
    output signed [WIDTH-1:0] f4,

    output signed [WIDTH-1:0] neuron_lp_voltage,
	output integrated_neuron,

    // weight mem 1
    input [7:0] weight_mem_L1_wren,
    input [clogb2(WEIGHT_DEPTH_12-1)-1:0] weight_mem_L1_wr_addr,
    input [16-1:0] weight_mem_L1_data_in,
    output [16-1:0] weight_mem_L1_data_out,
    input weight_mem_L1_ena,

    // weight mem 2
    input [7:0] weight_mem_L2_wren,
    input [clogb2(WEIGHT_DEPTH_12-1)-1:0] weight_mem_L2_wr_addr,
    input [16-1:0] weight_mem_L2_data_in,
    output [16-1:0] weight_mem_L2_data_out,
    input weight_mem_L2_ena,

    // weight mem 3
    input [7:0] weight_mem_L3_wren,
    input [clogb2(WEIGHT_DEPTH_34-1)-1:0] weight_mem_L3_wr_addr,
    input [16-1:0] weight_mem_L3_data_in,
    output [16-1:0] weight_mem_L3_data_out,
    input weight_mem_L3_ena,

    // weight mem 4
    input [7:0] weight_mem_L4_wren,
    input [clogb2(WEIGHT_DEPTH_34-1)-1:0] weight_mem_L4_wr_addr,
    input [16-1:0] weight_mem_L4_data_in,
    output [16-1:0] weight_mem_L4_data_out,
    input weight_mem_L4_ena,
	
	//spike mem 1 & 2
	output wire [7:0] o_spike_mem_dat,
	input wire [7:0] i_spike_mem_adr,
	input wire [1:0] i_spike_mem_rd_en,	
	input wire [1:0] i_spike_mem_wr_en,
	input wire [3:0] i_spike_mem_dat,
	// sample mem
	output wire [15:0] o_sample_mem_dat,	
	input wire [7:0] i_sample_mem_adr,
	input wire       i_sample_mem_rd_en,	 
	input wire        i_sample_mem_wr_en,
	input wire [15:0] i_sample_mem_dat,
	// # layers and channels
	input wire [clogb2(MAX_SYNAPSES-1)-1:0] snn_input_channels, 
	input wire [clogb2(MAX_NEURONS-1)-1:0] neuron_1, neuron_2, neuron_3, neuron_4, 
	/*neuron_5, neuron_6, neuron_7, neuron_8,*/
	input wire [2:0] layers,
	// output buffer access
	input output_buffer_ren,
	input [7:0] output_buffer_addr,
	output [31:0] output_buffer_out
    );

 localparam SPIKE  = 4;

/////////////////////////////////////////////////////////////////////////// 
//  _____ _   _  ____ ___  ____ ___ _   _  ____   ____  _     ___ _____  //
// | ____| \ | |/ ___/ _ \|  _ \_ _| \ | |/ ___| / ___|| |   / _ \_   _| //
// |  _| |  \| | |  | | | | | | | ||  \| | |  _  \___ \| |  | | | || |   //
// | |___| |\  | |__| |_| | |_| | || |\  | |_| |  ___) | |__| |_| || |   //
// |_____|_| \_|\____\___/|____/___|_| \_|\____| |____/|_____\___/ |_|   //
//                                                                       //                                    
///////////////////////////////////////////////////////////////////////////
    
 wire [SPIKE-1:0] spike_bin;
 wire valid_bin;
 wire active_group_out_bin;

encoding_slot #(
	.BYPASS(ENCODING_BYPASS),    
	.CHANNELS(CHANNELS),
    .ORDER(ORDER),
    .WINDOW(WINDOW),
    .REF_PERIOD(REF_PERIOD),
    .DW(DW)
)
encoding_slot_i
(
    clk_enc, rst,
    en,
    data_in,
    detect,

    spike_bin,
    valid_bin,
    active_group_out_bin,

	valid_potential,
	
	o_sample_mem_dat,	
	i_sample_mem_adr,
	i_sample_mem_rd_en,
	i_sample_mem_wr_en,
	i_sample_mem_dat,	
	encoding_bypass
    );   

//////////////////////////////////////////////
//                                          //
//  ____        _ _    _                    //
// / ___| _ __ (_) | _(_)_ __   __ _        //
// \___ \| '_ \| | |/ / | '_ \ / _` |       //
//  ___) | |_) | |   <| | | | | (_| |       //
// |____/| .__/|_|_|\_\_|_| |_|\__, |       //
//       |_|                   |___/        //
//  _   _                      _            //
// | \ | | ___ _   _ _ __ __ _| |           //
// |  \| |/ _ \ | | | '__/ _` | |           //
// | |\  |  __/ |_| | | | (_| | |           //
// |_| \_|\___|\__,_|_|  \__,_|_|           //
//  _   _      _                      _     //
// | \ | | ___| |___      _____  _ __| | __ //
// |  \| |/ _ \ __\ \ /\ / / _ \| '__| |/ / //
// | |\  |  __/ |_ \ V  V / (_) | |  |   <  //
// |_| \_|\___|\__| \_/\_/ \___/|_|  |_|\_\ //
//                                          //
//                                          //
//////////////////////////////////////////////

wire valid_potential;
wire [SPIKE-1:0] spike_out_snn;
wire valid_spike;

snn_lp
    #(
    .WIDTH(WIDTH),
    
	.MAX_SYNAPSES(MAX_SYNAPSES),
	.MAX_NEURONS(MAX_SYNAPSES),

    .INPUT_SPIKE_1(INPUT_SPIKE_1), 
    .NEURON_1(NEURON_1),   
    .WEIGHTS_FILE_1(WEIGHTS_FILE_1),
    .current_decay_1(current_decay_1),
    .voltage_decay_1(voltage_decay_1),
    .threshold_1(threshold_1),
    
    .INPUT_SPIKE_2(INPUT_SPIKE_2),
    .NEURON_2(NEURON_2),
    .WEIGHTS_FILE_2(WEIGHTS_FILE_2),
    .current_decay_2(current_decay_2),
    .voltage_decay_2(voltage_decay_2),
    .threshold_2(threshold_2),
    
    .INPUT_SPIKE_3(INPUT_SPIKE_3), 
    .NEURON_3(NEURON_3),   
    .WEIGHTS_FILE_3(WEIGHTS_FILE_3),
    .current_decay_3(current_decay_3),
    .voltage_decay_3(voltage_decay_3),
    .threshold_3(threshold_3),
    
    .INPUT_SPIKE_4(INPUT_SPIKE_4),
    .NEURON_4(NEURON_4),
    .WEIGHTS_FILE_4(WEIGHTS_FILE_4),
    .current_decay_4(current_decay_4),
    .voltage_decay_4(voltage_decay_4),
    .threshold_4(threshold_4),
    
    .WEIGHT_DEPTH_12(WEIGHT_DEPTH_12),
    .WEIGHT_DEPTH_34(WEIGHT_DEPTH_34)
    )
snn_lp_i
    (
    clk_snn, rst,
    valid_bin,
    spike_bin,
    active_group_out_bin,
    
    valid_potential, 	
	valid_spike,
    spike_out_snn,
	integrated_neuron,
        
    weight_mem_L1_wren,
    weight_mem_L1_wr_addr,
    weight_mem_L1_data_in,
    weight_mem_L1_data_out,
    weight_mem_L1_ena,
    weight_mem_L2_wren,
    weight_mem_L2_wr_addr,
    weight_mem_L2_data_in,
    weight_mem_L2_data_out,
    weight_mem_L2_ena,
    weight_mem_L3_wren,
    weight_mem_L3_wr_addr,
    weight_mem_L3_data_in,
    weight_mem_L3_data_out,
    weight_mem_L3_ena,
    weight_mem_L4_wren,
    weight_mem_L4_wr_addr,
    weight_mem_L4_data_in,
    weight_mem_L4_data_out,
    weight_mem_L4_ena,
	o_spike_mem_dat,
	i_spike_mem_adr,
	i_spike_mem_rd_en,
	i_spike_mem_wr_en,
	i_spike_mem_dat,
	snn_input_channels, 
	neuron_1, neuron_2, neuron_3, neuron_4, 
	layers,
	output_buffer_ren,
	output_buffer_addr,
	output_buffer_out
    );    

///////////////////////////////////////////////////////////////////////////
//   ____  _____ ____ ___  ____ ___ _   _  ____   ____  _     ___ _____  //
//  |  _ \| ____/ ___/ _ \|  _ \_ _| \ | |/ ___| / ___|| |   / _ \_   _| //
//  | | | |  _|| |  | | | | | | | ||  \| | |  _  \___ \| |  | | | || |   //
//  | |_| | |__| |__| |_| | |_| | || |\  | |_| |  ___) | |__| |_| || |   //
//  |____/|_____\____\___/|____/___|_| \_|\____| |____/|_____\___/ |_|   //
//                                                                       //
///////////////////////////////////////////////////////////////////////////
 
assign valid = valid_potential;
   
//  The following function calculates the address width based on specified RAM depth
function integer clogb2;
  input integer depth;
    for (clogb2=0; depth>0; clogb2=clogb2+1)
      depth = depth >> 1;
endfunction   
    
endmodule
