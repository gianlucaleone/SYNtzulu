`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10.11.2022 18:17:57
// Design Name: 
// Module Name: encoding
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


module encoding_slot
#(
	parameter BYPASS = 0,
    parameter CHANNELS = 128,
    parameter ORDER = 2,
    parameter WINDOW = 8192,
    parameter REF_PERIOD = 16,
    parameter DW = 15
)
(
    input clk, rst,
    input en,
    input signed [15:0] data_in,
    input detect,
    
    output reg [3:0] spike_bin,
    output reg valid_bin,
    output reg active_group_out_bin,

	input inference_done,

	output wire [15:0] o_sample_mem_dat,	
	input wire [clogb2(CHANNELS-1)-1:0] i_sample_mem_adr,
	input wire       i_sample_mem_rd_en,
	input wire i_sample_mem_wr_en,
	input wire [15:0] i_sample_mem_dat,

	input wire bypass
    );

wire signed [DW-1:0] data_out_buffer;
wire input_buffer_valid;

input_buffer
	#(

	.CHANNELS(CHANNELS),
	.DW(DW)
	)
input_buffer_i
	(
	.clk(clk), .rst(rst),
	.en(en),
	.data_in(data_in),
	
	.valid(input_buffer_valid),
	.data_out(data_out_buffer),

	.external_access_en(i_sample_mem_rd_en),
	.external_addr(i_sample_mem_adr),	
	.external_data_out(o_sample_mem_dat),
	.external_access_wren(i_sample_mem_wr_en),
	.external_data_in(i_sample_mem_dat)
	);

wire [3:0] spike_bin_int;
wire valid_bin_int;
wire active_group_out_bin_int;


`ifdef IEEG

	////////////////////////////////////////////////// 
	//   _____                     _ _              //
	//  | ____|_ __   ___ ___   __| (_)_ __   __ _  //
	//  |  _| | '_ \ / __/ _ \ / _` | | '_ \ / _` | //
	//  | |___| | | | (_| (_) | (_| | | | | | (_| | //
	//  |_____|_| |_|\___\___/ \__,_|_|_| |_|\__, | //
	//                                       |___/  //
	//   ____  _       _     _ _____ _____ ____     //
	//  / ___|| | ___ | |_  (_) ____| ____/ ___|    //
	//  \___ \| |/ _ \| __| | |  _| |  _|| |  _     //
	//   ___) | | (_) | |_  | | |___| |__| |_| |    //
	//  |____/|_|\___/ \__| |_|_____|_____\____|    //
	//                                              //
	//////////////////////////////////////////////////                                        

	 encoding_slot_ieeg #(
		.CHANNELS(CHANNELS),
		.ORDER(ORDER),
		.WINDOW(WINDOW),
		.REF_PERIOD(REF_PERIOD),
		.DW(DW)
	)
	encoding_slot_ieeg_i
	(
		clk, rst,
		input_buffer_valid,
		data_out_buffer,
		detect,

		spike_bin_int,
		valid_bin_int,
		active_group_out_bin_int
		);   

`endif

`ifdef EMG

	 encoding_slot_emg #(
		.CHANNELS(CHANNELS),
		.DW(DW)
	)
	encoding_slot_emg_i
	(
		clk, rst,
		input_buffer_valid,
		data_out_buffer,

		spike_bin_int,
		valid_bin_int,
		active_group_out_bin_int
		);  

`endif

///////////////////////////////////////////
//    ______   ______   _    ____ ____   //
//   | __ ) \ / /  _ \ / \  / ___/ ___|  //
//   |  _ \\ V /| |_) / _ \ \___ \___ \  //
//   | |_) || | |  __/ ___ \ ___) |__) | //
//   |____/ |_| |_| /_/   \_\____/____/  //
//                                       //
///////////////////////////////////////////

generate
	if(BYPASS)
		always @(posedge clk) 
				begin
					spike_bin <= spike_bin_int;
					valid_bin <= valid_bin_int;
					active_group_out_bin <= active_group_out_bin_int;
				end
	else
		always @(posedge clk) 
			if(bypass)
				begin
					spike_bin <= data_out_buffer[3:0];
					valid_bin <= input_buffer_valid;
					active_group_out_bin <= |data_out_buffer[3:0];
				end
			else
				begin
					spike_bin <= spike_bin_int;
					valid_bin <= valid_bin_int;
					active_group_out_bin <= active_group_out_bin_int;
				end	
endgenerate

//  The following function calculates the address width based on specified RAM depth
function integer clogb2;
  input integer depth;
    for (clogb2=0; depth>0; clogb2=clogb2+1)
      depth = depth >> 1;
endfunction   
    
endmodule
