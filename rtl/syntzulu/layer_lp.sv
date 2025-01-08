`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03.04.2023 11:05:04
// Design Name: 
// Module Name: layer_lp
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


module layer_lp
    #(
    parameter WIDTH = 25,
    parameter NEURON = 256,   
	parameter LAYERS = 4,
    parameter WEIGHTS_FILE_1 = "weights_1.txt",
	parameter WEIGHTS_FILE_2 = "weights_2.txt",
    parameter [13:0] current_decay_1 = 4096 - 4096,
	parameter [13:0] current_decay_2 = 4096 - 4096,
	parameter [13:0] current_decay_3 = 4096 - 4096,
	parameter [13:0] current_decay_4 = 4096 - 4096,
    parameter [13:0] voltage_decay_1 = 4096 - 415,
	parameter [13:0] voltage_decay_2 = 4096 - 415,
	parameter [13:0] voltage_decay_3 = 4096 - 415,
	parameter [13:0] voltage_decay_4 = 4096 - 415,
    parameter [WIDTH-1:0]  threshold_1 = 6,
    parameter [WIDTH-1:0]  threshold_2 = 6,
    parameter [WIDTH-1:0]  threshold_3 = 6,
    parameter [WIDTH-1:0]  threshold_4 = 6,
    parameter WEIGHT_DEPTH = 8192
    )
    (
    input clk, rst,
    input en,
    input [3:0] spike_in,
    input active_group_in,

	input [clogb2(WEIGHT_DEPTH-1)-1:0] weight_rd_addr,
	input acc_clear, acc_clear_and_go,
	output convolution_pipe_full,    
	input [clogb2(LAYERS-1)-1:0] layer_id,

    output valid,
    output [1:0] spike_out,
    output active_group_out,
    output reg valid_potential,
    output signed [WIDTH-1:0] neuron_lp_voltage,
	output integrated_neuron,
    
    input [7:0] weight_mem_L1_wren,
    input [clogb2(WEIGHT_DEPTH-1)-1:0] weight_mem_L1_wr_addr,
    input [16-1:0] weight_mem_L1_data_in,
    output [16-1:0] weight_mem_L1_data_out,
    input weight_mem_L1_ena,
    input [7:0] weight_mem_L2_wren,
    input [clogb2(WEIGHT_DEPTH-1)-1:0] weight_mem_L2_wr_addr,
    input [16-1:0] weight_mem_L2_data_in,
    output [16-1:0] weight_mem_L2_data_out,
    input weight_mem_L2_ena,
	output [7:0] weight_debug,
	output weight_en_debug
    );

assign weight_en_debug = en;
assign weight_debug = weight_rd_addr[7:0];//weights_out_1[7:0];

/////////////////////////////////////////////////////////////////
//               _       _     _                               //
// __      _____(_) __ _| |__ | |_   _ __ ___   ___ _ __ ___   //
// \ \ /\ / / _ \ |/ _` | '_ \| __| | '_ ` _ \ / _ \ '_ ` _ \  //
//  \ V  V /  __/ | (_| | | | | |_  | | | | | |  __/ | | | | | //
//   \_/\_/ \___|_|\__, |_| |_|\__| |_| |_| |_|\___|_| |_| |_| //
//                 |___/                                       //
/////////////////////////////////////////////////////////////////   

localparam WEIGHT = 8;  

wire [15:0] weights_out_1;   
wire [15:0] weights_out_2;   

SPRAM_singlePort_readFirst
#(
  .RAM_WIDTH(16),                  // Specify RAM data width
  .RAM_DEPTH(WEIGHT_DEPTH),             // Specify RAM depth (number of entries)
  .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
  .INIT_FILE(WEIGHTS_FILE_1)             // Specify name/location of RAM initialization file if using one (leave blank if not)
  )
weight_mem_1
 (
  .addra(weight_mem_L1_wr_addr),      // Port A address bus, driven by axi bus
  .addrb(weight_rd_addr),          // Port B address bus, it goes in the accumulator
  .dina(weight_mem_L1_data_in),       // Port A RAM input data, driven by axi bus
  //.dinb({64{1'b0}}),                        // write port PL side not used
  .clk(clk),                       // Clock
  .wea(weight_mem_L1_wren[0]),           // Port A write enable
  //.web(1'b0),                      // write port PL side not used
  .ena(weight_mem_L1_ena),         // Port A RAM Enable, for additional power savings, disable port when not in use
  .enb(1'b1),                      // Port B RAM Enable, for additional power savings, disable port when not in use
  .rst(rst),                       // Port A and B output reset (does not affect memory contents)
  //.regcea(1'b1),                   // Port A output register enable
  .regceb(1'b1),                   // Port B output register enable
  
  //.douta(weights_mem_ctrl_ext_1),    // Port B RAM output data
  .doutb(weights_out_1)              // Port B RAM output data
    );

SPRAM_singlePort_readFirst
#(
  .RAM_WIDTH(16),                  // Specify RAM data width
  .RAM_DEPTH(WEIGHT_DEPTH),             // Specify RAM depth (number of entries)
  .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
  .INIT_FILE(WEIGHTS_FILE_2)             // Specify name/location of RAM initialization file if using one (leave blank if not)
  )
weight_mem_2
 (
  .addra(weight_mem_L2_wr_addr),      // Port A address bus, driven by axi bus
  .addrb(weight_rd_addr),          // Port B address bus, it goes in the accumulator
  .dina(weight_mem_L2_data_in),       // Port A RAM input data, driven by axi bus
  //.dinb({64{1'b0}}),                        // write port PL side not used
  .clk(clk),                       // Clock
  .wea(weight_mem_L2_wren[0]),           // Port A write enable
  //.web(1'b0),                      // write port PL side not used
  .ena(weight_mem_L2_ena),                      // Port A RAM Enable, for additional power savings, disable port when not in use
  .enb(1'b1),                      // Port B RAM Enable, for additional power savings, disable port when not in use
  .rst(rst),                       // Port A and B output reset (does not affect memory contents)
  //.regcea(1'b1),                   // Port A output register enable
  .regceb(1'b1),                   // Port B output register enable
  
  //.douta(weights_mem_ctrl_ext_2),    // Port B RAM output data
  .doutb(weights_out_2)              // Port B RAM output data
    );

wire signed [31:0] weights;
assign weights = {weights_out_1,weights_out_2};

///////////////////////////////////////////////////////////
//                            _       _   _              //
//   ___ ___  _ ____   _____ | |_   _| |_(_) ___  _ __   //
//  / __/ _ \| '_ \ \ / / _ \| | | | | __| |/ _ \| '_ \  //
// | (_| (_) | | | \ V / (_) | | |_| | |_| | (_) | | | | //
//  \___\___/|_| |_|\_/ \___/|_|\__,_|\__|_|\___/|_| |_| //
//  _____                               _ _              //
//    __/  __      __ __  __  ___ _ __ (_) | _____       //
//  \ \    \ \ /\ / / \ \/ / / __| '_ \| | |/ / _ \      //
//  / /__   \ V  V /   >  <  \__ \ |_) | |   <  __/      //
//  _____\   \_/\_/   /_/\_\ |___/ .__/|_|_|\_\___|      //
//                               |_|                     //
///////////////////////////////////////////////////////////

// Spikes and weights are convolved: multiplied (by logic-and) and accumulated (5-way accumulator)

wire [2*(WEIGHT+1)-1:0] stimulus;

conv
    #(
    .WEIGHTS(4),          // Number of addends
    .DATA_WIDTH(WEIGHT)   // Width of the Adders
    )
 conv_i
(
    .clk(clk), .rst(rst), .en(en), .acc_clear_and_go(acc_clear_and_go), .acc_clear(acc_clear),
    .weights_in(weights),
    .spikes(spike_in),
    
    .out(stimulus),
    .valid(convolution_pipe_full)
    );

//////////////////////////////////////////////
//     _   _                                //
//    | \ | | ___ _   _ _ __ ___  _ __      //
//    |  \| |/ _ \ | | | '__/ _ \| '_ \     //
//    | |\  |  __/ |_| | | | (_) | | | |    //
//    |_| \_|\___|\__,_|_|  \___/|_| |_|    //
//    ___                  _   ____  ____   //
//   |  _|  __ _ _ __   __| | / ___||  _ \  //
//   | |   / _` | '_ \ / _` | \___ \| | | | //
//  _| |  | (_| | | | | (_| |  ___) | |_| | //
// |___|   \__,_|_| |_|\__,_| |____/|____/  //
//                                          //
//////////////////////////////////////////////

neuron_lp 
    #(.DEPTH(NEURON),.WIDTH(WIDTH),.WEIGHT(WEIGHT),.LAYERS(LAYERS))
 neuron_lp_i
    (
    .clk(clk), .rst(rst), .en(acc_clear_and_go),
    .current_decay_1(current_decay_1), .voltage_decay_1(voltage_decay_1), .threshold_1(threshold_1),
    .current_decay_2(current_decay_2), .voltage_decay_2(voltage_decay_2), .threshold_2(threshold_2),
	.current_decay_3(current_decay_3), .voltage_decay_3(voltage_decay_3), .threshold_3(threshold_3),
    .current_decay_4(current_decay_4), .voltage_decay_4(voltage_decay_4), .threshold_4(threshold_4),    
	.synaptic_current(stimulus),
    .layer_id(layer_id),
    
    .valid(valid),
    .spike_p(spike_out),
    .active_group(active_group_out),
    .voltage_ready(integrated_neuron),
    .voltage(neuron_lp_voltage)
    );


////////////////////////////
//  _               ____  //
// | | ___   __ _  |___ \ //
// | |/ _ \ / _` |   __)  //
// | | (_) | (_| |  / __/ //
// |_|\___/ \__, | |_____ //
//          |___/         //
////////////////////////////
   
//  The following function calculates the address width based on specified RAM depth
function integer clogb2;
  input integer depth;
    for (clogb2=0; depth>0; clogb2=clogb2+1)
      depth = depth >> 1;
endfunction      

function integer max;
  input integer a,b;
    if (a>b)
      max = a;
    else
      max = b;
endfunction 
    
endmodule

