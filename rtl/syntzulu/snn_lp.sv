`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03.04.2023 11:05:04
// Design Name: 
// Module Name: snn_lp
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


module snn_lp 
#(
    // neuron arithmetic
    parameter WIDTH = 26,
	// 
	parameter MAX_SYNAPSES  = 256,
	parameter MAX_NEURONS = 256,
	parameter LAYERS = 4,
    // weight mem 1
    parameter INPUT_SPIKE_1 = 128, 
    parameter NEURON_1 = 64,   
    parameter WEIGHTS_FILE_1 = "weights_1.txt",
    parameter [13:0] current_decay_1 = 4096 - 4096,
    parameter [13:0] voltage_decay_1 = 4096 - 415,
    parameter [WIDTH-1:0]  threshold_1 = 6,
    // weight mem 2
    parameter INPUT_SPIKE_2 = 64,
    parameter NEURON_2 = 128,
    parameter WEIGHTS_FILE_2 = "weights_2.txt",
    parameter [13:0] current_decay_2 = 4096 - 4096,
    parameter [13:0] voltage_decay_2 = 4096 - 424,
    parameter [WIDTH-1:0]  threshold_2 = 6,
    // weight mem 3
    parameter INPUT_SPIKE_3 = 128, 
    parameter NEURON_3 = 256,   
    parameter WEIGHTS_FILE_3 = "weights_3.txt",
    parameter [13:0] current_decay_3 = 4096 - 4096,
    parameter [13:0] voltage_decay_3 = 4096 - 415,
    parameter [WIDTH-1:0]  threshold_3 = 6,
    // weight mem 4
    parameter INPUT_SPIKE_4 = 256,
    parameter NEURON_4 = 128,
    parameter WEIGHTS_FILE_4 = "weights_4.txt",
    parameter [13:0] current_decay_4 = 4096 - 4096,
    parameter [13:0] voltage_decay_4 = 4096 - 424,
    parameter [WIDTH-1:0]  threshold_4 = 6,
    
    parameter WEIGHT_DEPTH_12 = 8192,
    parameter WEIGHT_DEPTH_34 = 8192
)
    (
    // input
    input clk, rst,
    input en,
    input [3:0] spike_in,
    input active_group_in,

    // output
    output valid,	
	output valid_spike,
    output [3:0] spike_out,
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

	// # layers and channels
	input wire [clogb2(MAX_SYNAPSES-1)-1:0] snn_input_channels, 
	input wire [clogb2(MAX_NEURONS-1)-1:0] neuron_1, neuron_2, neuron_3, neuron_4, 
	input wire [2:0] layers,

	// output buffer access
	input output_buffer_ren,
	input [7:0] output_buffer_addr,
	output [31:0] output_buffer_out
    );

localparam LAYERS_LOG2 = clogb2(LAYERS-1);
`ifdef CONFIGURABILITY
	localparam TOTAL_NEURONS = 4*MAX_NEURONS; 
`else
	localparam TOTAL_NEURONS = NEURON_1 + NEURON_2 + NEURON_3 + NEURON_4;
`endif

localparam SYN_G1_L2 = clogb2(INPUT_SPIKE_1/4-1);
localparam SYN_G2_L2 = clogb2(INPUT_SPIKE_2/4-1);
localparam SYN_G3_L2 = clogb2(INPUT_SPIKE_3/4-1);
localparam SYN_G4_L2 = clogb2(INPUT_SPIKE_4/4-1);

localparam MAX_LAYER = max4(INPUT_SPIKE_1*NEURON_1,INPUT_SPIKE_2*NEURON_2,INPUT_SPIKE_3*NEURON_3,INPUT_SPIKE_4*NEURON_4)/8;

localparam P1 = clogb2(MAX_LAYER)-clogb2(NEURON_1*INPUT_SPIKE_1/8);
localparam P2 = clogb2(MAX_LAYER)-clogb2(NEURON_2*INPUT_SPIKE_2/8);
localparam P3 = clogb2(MAX_LAYER)-clogb2(NEURON_3*INPUT_SPIKE_3/8);
localparam P4 = clogb2(MAX_LAYER)-clogb2(NEURON_4*INPUT_SPIKE_4/8);

localparam WEIGHT_ADDRESS_SIZE = clogb2(MAX_NEURONS/2-1) + clogb2(MAX_SYNAPSES/4-1) + clogb2(LAYERS-1);

// interconnection signals
wire v1,v2;
wire [1:0] s1,s2;
wire ag1,ag2;

/*
  _     ____            _     _ 
 | |   |  _ \          | |   / |
 | |   | |_) |  _____  | |   | |
 | |___|  __/  |_____| | |___| |
 |_____|_|             |_____|_|
                                
*/    
wire signed [WIDTH-1:0] voltage_1;
layer_lp
    #(
    .WIDTH(WIDTH),
    .NEURON(TOTAL_NEURONS/2),   
	.LAYERS(LAYERS),
    .WEIGHTS_FILE_1(WEIGHTS_FILE_1),
	.WEIGHTS_FILE_2(WEIGHTS_FILE_2),
    .current_decay_1(current_decay_1),
	.current_decay_2(current_decay_2),
	.current_decay_3(current_decay_3),
	.current_decay_4(current_decay_4),
    .voltage_decay_1(voltage_decay_1),
	.voltage_decay_2(voltage_decay_2),
	.voltage_decay_3(voltage_decay_3),
	.voltage_decay_4(voltage_decay_4),
    .threshold_1(threshold_1),
	.threshold_2(threshold_2),
	.threshold_3(threshold_3),
	.threshold_4(threshold_4),    
    .WEIGHT_DEPTH(2**(WEIGHT_ADDRESS_SIZE))
    )
layer_lp_l1_i
    (
    .clk(clk), .rst(rst),
    .en(layer_enable_dd),
    .spike_in(spike_mem_out),
    .active_group_in(),
    
	.weight_rd_addr(weight_rd_addr),
	.acc_clear(layer_integrated), .acc_clear_and_go(convolution_valid),
	.convolution_pipe_full(convolution_pipe_full),    
	.layer_id(layer_counter),

    .valid(v1),
    .spike_out(s1),
    .active_group_out(ag1),
    .integrated_neuron(integrated_neuron_1),
    .neuron_lp_voltage(voltage_1),

   .weight_mem_L1_wren(weight_mem_L1_wren),
   .weight_mem_L1_wr_addr(weight_mem_L1_wr_addr),
   .weight_mem_L1_data_in(weight_mem_L1_data_in),
   .weight_mem_L1_data_out(weight_mem_L1_data_out),
   .weight_mem_L1_ena(weight_mem_L1_ena),
   .weight_mem_L2_wren(weight_mem_L2_wren),
   .weight_mem_L2_wr_addr(weight_mem_L2_wr_addr),
   .weight_mem_L2_data_in(weight_mem_L2_data_in),
   .weight_mem_L2_data_out(weight_mem_L2_data_out),
   .weight_mem_L2_ena(weight_mem_L2_ena)

	//.weight_debug(weight_debug),
	//.weight_en_debug(weight_en_debug)
    );    
/*
  _     ____            _     ____  
 | |   |  _ \          | |   |___ \ 
 | |   | |_) |  _____  | |     __) |
 | |___|  __/  |_____| | |___ / __/ 
 |_____|_|             |_____|_____|
                                    
*/
wire signed [WIDTH-1:0] voltage_2;
layer_lp
    #(
    .WIDTH(WIDTH),
    .NEURON(TOTAL_NEURONS/2),      
	.LAYERS(LAYERS),
    .WEIGHTS_FILE_1(WEIGHTS_FILE_3),
	.WEIGHTS_FILE_2(WEIGHTS_FILE_4),
    .current_decay_1(current_decay_1),
	.current_decay_2(current_decay_2),
	.current_decay_3(current_decay_3),
	.current_decay_4(current_decay_4),
    .voltage_decay_1(voltage_decay_1),
	.voltage_decay_2(voltage_decay_2),
	.voltage_decay_3(voltage_decay_3),
	.voltage_decay_4(voltage_decay_4),
    .threshold_1(threshold_1),
	.threshold_2(threshold_2),
	.threshold_3(threshold_3),
	.threshold_4(threshold_4),    
    .WEIGHT_DEPTH(2**(WEIGHT_ADDRESS_SIZE))
    )
layer_lp_l2_i
    (
    .clk(clk), .rst(rst),
    .en(layer_enable_dd),
    .spike_in(spike_mem_out),
    .active_group_in(),
    
	.weight_rd_addr(weight_rd_addr),
	.acc_clear(layer_integrated), .acc_clear_and_go(convolution_valid),
	.convolution_pipe_full(convolution_pipe_full),    
	.layer_id(layer_counter),    
    
    .valid(v2),
    .spike_out(s2),
    .active_group_out(ag2),
    .neuron_lp_voltage(voltage_2),
	.integrated_neuron(integrated_neuron_2),
    
   .weight_mem_L1_wren(weight_mem_L3_wren),
   .weight_mem_L1_wr_addr(weight_mem_L3_wr_addr),
   .weight_mem_L1_data_in(weight_mem_L3_data_in),
   .weight_mem_L1_data_out(weight_mem_L3_data_out),
   .weight_mem_L1_ena(weight_mem_L3_ena),
   .weight_mem_L2_wren(weight_mem_L4_wren),
   .weight_mem_L2_wr_addr(weight_mem_L4_wr_addr),
   .weight_mem_L2_data_in(weight_mem_L4_data_in),
   .weight_mem_L2_data_out(weight_mem_L4_data_out),
   .weight_mem_L2_ena(weight_mem_L4_ena)
    );  

// converge
wire [3:0] spike12;
//assign spike12 = i_spike_mem_wr_en[1]?i_spike_mem_dat:{s1[1],s2[1],s1[0],s2[0]};
assign spike12 = {s1[1],s2[1],s1[0],s2[0]};
wire valid12; 
assign valid12 = v1 && v2;
assign spike_out = spike12;
/////////////////////////////////////////////////
//    ____                  _                  //
//   / ___|___  _   _ _ __ | |_ ___ _ __ ___   //
//  | |   / _ \| | | | '_ \| __/ _ \ '__/ __|  //
//  | |__| (_) | |_| | | | | ||  __/ |  \__ \  //
//   \____\___/ \__,_|_| |_|\__\___|_|  |___/  //
//											   //
/////////////////////////////////////////////////                                          

// counters definition
reg [LAYERS_LOG2-1:0] layer_counter;
reg [clogb2(MAX_NEURONS/2-1)-1:0] neuron_cnt; 
reg [clogb2(MAX_SYNAPSES/4-1)-1:0] spike_wr_addr;

/////// SPIKE MEMORY WRITE PORT COUNTER /////////////////////////////////////////////////

reg spike_written;
reg [clogb2(LAYERS-1)-1:0] spike_written_counter;
wire [clogb2(MAX_SYNAPSES/4-1)-1:0] SYNAPSES;
`ifdef CONFIGURABILITY
	initial $display("Configurability is defined!");
	assign SYNAPSES = (spike_written_counter==0)?snn_input_channels/4-1:
					  (spike_written_counter==1)?neuron_1/4-1:
					  (spike_written_counter==2)?neuron_2/4-1:
										 neuron_3/4-1; //layer_counter==3
`else
	assign SYNAPSES = (spike_written_counter==0)?INPUT_SPIKE_1/4-1:
					  (spike_written_counter==1)?INPUT_SPIKE_2/4-1:
					  (spike_written_counter==2)?INPUT_SPIKE_3/4-1:
										 INPUT_SPIKE_4/4-1; //layer_counter==3
`endif
// it increases when: 
// 	1. spikes are received from the encoding slots (en is high)
//  2. spikes are produced from the SNN subprocessors layer_lp (v1|v2 is high)
wire spike_cnt_en;
assign spike_cnt_en = (en | v1 & layer_counter != LAYERS-1);
always @(posedge clk)
    if(rst)
        spike_wr_addr <= 0;
    else if (spike_cnt_en)
			if(spike_wr_addr == SYNAPSES)
        		spike_wr_addr <= 0;
			else
				spike_wr_addr <= spike_wr_addr + 1'b1;

// when the spike memory is loaded the inference starts
always @(posedge clk)
    if (rst)
        spike_written <= 0;
    else if( spike_cnt_en && (spike_wr_addr == SYNAPSES) )
            spike_written <= 1;
         else 
            spike_written <= 0;

always @(posedge clk)
    if (rst)
		spike_written_counter <= 0;
	else if(spike_written)
			spike_written_counter <= spike_written_counter +1'b1;

/////// NEURON COUNTER /////////////////////////////////////////////////

wire [clogb2(MAX_NEURONS/2-1)-1:0] NEURON;
`ifdef CONFIGURABILITY
	assign NEURON =   (layer_counter==0)? neuron_1/2-1:
					  (layer_counter==1)? neuron_2/2-1:
					  (layer_counter==2)? neuron_3/2-1:
										  neuron_4/2-1; //layer_counter==3
`else
	assign NEURON =   (layer_counter==0)? NEURON_1/2-1:
					  (layer_counter==1)? NEURON_2/2-1:
					  (layer_counter==2)? NEURON_3/2-1:
										  NEURON_4/2-1; //layer_counter==3
`endif

// neuron_cnt increases when the weights of a neuron are read
wire stream_out_done;
assign stream_out_done = stream_out_done_2 || stream_out_done_1;
always @(posedge clk)
    if(rst)
        neuron_cnt <= 0;
    else if (stream_out_done)
            if (neuron_cnt < NEURON)
                neuron_cnt <= neuron_cnt + 1'b1;
            else
                neuron_cnt <= 0;
                
assign layer_dispatched = stream_out_done && (neuron_cnt == NEURON); 

/////// LAYER COUNTER /////////////////////////////////////////////////
wire inference_done;
always @(posedge clk)
    if (rst)
        layer_counter <= 0;
    else if (layer_integrated)
			if(layer_counter < LAYERS)
        		layer_counter = layer_counter+1'b1;

assign inference_done = (layer_counter == LAYERS) && layer_integrated;

//////////////////////////////////////////////////
//   _        _ __   _______ ____  ____         //
//  | |      / \\ \ / / ____|  _ \/ ___|        //
//  | |     / _ \\ V /|  _| | |_) \___ \        //
//  | |___ / ___ \| | | |___|  _ < ___) |       //
//  |_____/_/   \_\_| |_____|_| \_\____/        //
//    ____ ___  _   _ _____ ____   ___  _       //
//   / ___/ _ \| \ | |_   _|  _ \ / _ \| |      //
//  | |  | | | |  \| | | | | |_) | | | | |      //
//  | |__| |_| | |\  | | | |  _ <| |_| | |___   //
//   \____\___/|_| \_| |_| |_| \_\\___/|_____|  //
//   ____ ___ ____ _   _    _    _     ____     //
//  / ___|_ _/ ___| \ | |  / \  | |   / ___|    //
//  \___ \| | |  _|  \| | / _ \ | |   \___ \    //
//   ___) | | |_| | |\  |/ ___ \| |___ ___) |   //
//  |____/___\____|_| \_/_/   \_\_____|____/    //
//                                              //
//////////////////////////////////////////////////

/////// LAYER ENABLE /////////////////////////////////////////////////
reg layer_enable, layer_enable_d, layer_enable_dd;
always @(posedge clk)
    if (rst)
		layer_enable <= 0;
	else if (stream_out_1 | stream_out_2)
			layer_enable <= 1;
		 else if (stream_out_done && (neuron_cnt == NEURON))
				layer_enable <= 0;

always @(posedge clk)
    if (rst) begin
		layer_enable_d  <= 0;
		layer_enable_dd <= 0;
		end 
	else begin
		layer_enable_d  <= layer_enable;
		layer_enable_dd <= layer_enable_d;
		end

/////// LAYER ACCUMULATOR /////////////////////////////////////////////

wire convolution_valid;

// The conv module valid bit "convolution_pipe_full" is:  en -|_|-|_|-|_|-|_|-|_|- convolution_pipe_full
// By counting the number of clock cycles it is at logic-1, and comparing the value with 
// the number of memory reads per convolution (provided by the stack), it is possible to 
// generate the convolution valid signal "convolution_valid", which is used to: 
//  1. clear the accumulator register
//  2. enable the LIF neuron integration

assign words_to_read = layer_counter[0]? words_to_read_2 : words_to_read_1;

reg [clogb2(MAX_SYNAPSES/4-1)-1:0] convolution_valid_cnt;
always @(posedge clk)
    if (rst)
        convolution_valid_cnt <= 0;
    else if (convolution_pipe_full)
            if(convolution_valid_cnt < words_to_read)
                convolution_valid_cnt <= convolution_valid_cnt + 1'b1;
            else
                convolution_valid_cnt <= 0;
 
assign convolution_valid = (convolution_valid_cnt == words_to_read) && convolution_pipe_full; 

// Moreover, it is necessary to assess when each layer's computation terminates
// to clear the accumulation register

wire integrated_neuron_1, integrated_neuron_2;
assign integrated_neuron = integrated_neuron_1; // integrated_neuron 1 and 2 are the same

reg integrated_neuron_r;
always @(posedge clk)
    if(rst)
        integrated_neuron_r <= integrated_neuron;
    else 
        integrated_neuron_r <= integrated_neuron;

// Integrated neurons counter

reg [clogb2(MAX_NEURONS/2-1)-1:0] integrated_neurons_cnt, integrated_neurons_cnt_d; 
always @(posedge clk)
    if (rst)
        integrated_neurons_cnt <= 0;
    else if(integrated_neuron)
            if(integrated_neurons_cnt < NEURON)
                integrated_neurons_cnt <= integrated_neurons_cnt + 1'b1;
            else 
                integrated_neurons_cnt <= 0;

always @(posedge clk)
    if (rst)
        integrated_neurons_cnt_d <= 0;
    else
        integrated_neurons_cnt_d <= integrated_neurons_cnt;      
  
assign layer_integrated = integrated_neuron_r && (integrated_neurons_cnt_d == NEURON); 

//////////////////////////////
//      _             _     //
//  ___| |_ __ _  ___| | __ //
// / __| __/ _` |/ __| |/ / //
// \__ \ || (_| | (__|   <  //
// |___/\__\__,_|\___|_|\_\ //
//                          //
//////////////////////////////

// it stores the addresses of the active spike groups
// At every neuron integration:
//  - spike_rd_addr = stack_data_out
//  - weight_rd_addr = {neuron_cnt,stack_data_out}
// By doing so only the active groups are read, enabling
// both higher performances and least power wastes

wire stream_out_done_1, stream_out_done_2;
wire stream_out_1, stream_out_2;
wire [clogb2(MAX_SYNAPSES/4-1)-1:0] words_to_read_1, words_to_read_2, words_to_read;
wire empty, empty_1, empty_2;

wire stack_en_1;
assign stack_en_1 = (v1 && v2 && (ag1 || ag2) && layer_counter[0]) || (en & active_group_in);
assign stream_out_1 = (spike_written && ~spike_written_counter[0]) || (stream_out_done_1  && (neuron_cnt != NEURON));
stack
#(
.DATA_WIDTH(clogb2(MAX_SYNAPSES/4-1)),
.DEPTH(MAX_SYNAPSES/4)
 )
stack_1
 (
.clk(clk), .rst(rst),
.din(spike_wr_addr),
.wr_en(stack_en_1), 
.clear(layer_integrated && ~layer_counter[0]),
.stream_out(stream_out_1),

.dout(spike_rd_addr_1),
.done(stream_out_done_1),
.active_entries(words_to_read_1),
.empty(empty_1)
);

wire stack_en_2;
assign stack_en_2 = v1 && v2 && (ag1 || ag2) && ~layer_counter[0];
assign stream_out_2 = (spike_written && spike_written_counter[0]) || (stream_out_done_2 && (neuron_cnt != NEURON));
stack
#(
.DATA_WIDTH(clogb2(MAX_SYNAPSES/4-1)),
.DEPTH(MAX_SYNAPSES/4)
 )
stack_2
 (
.clk(clk), .rst(rst),
.din(spike_wr_addr),
.wr_en(stack_en_2), 
.clear(layer_integrated && layer_counter[0]),
.stream_out(stream_out_2),

.dout(spike_rd_addr_2),
.done(stream_out_done_2),
.active_entries(words_to_read_2),
.empty(empty_2)
);

// stack enable to stream out the rd_address for spike_mem and weight_mem
wire [clogb2(MAX_SYNAPSES/4-1)-1:0] spike_rd_addr;
assign spike_rd_addr = layer_counter[0]?spike_rd_addr_2:spike_rd_addr_1;
assign empty = layer_counter[0]?empty_2:empty_1;

/////////////////////////////////////////////////////  
//            _ _                                  //
//  ___ _ __ (_) | _____   _ __ ___   ___ _ __ ___ //
// / __| '_ \| | |/ / _ \ | '_ ` _ \ / _ \ '_ ` _  //
// \__ \ |_) | |   <  __/ | | | | | |  __/ | | | | //
// |___/ .__/|_|_|\_\___| |_| |_| |_|\___|_| |_| | //
//     |_|                                         //
///////////////////////////////////////////////////// 

wire [3:0] spike_mem_out_1;
wire [clogb2(MAX_SYNAPSES/4-1)-1:0] spike_rd_addr_1;
wire spike_wr_en_1; 

wire [3:0] spike_mem_out_2;
wire [clogb2(MAX_SYNAPSES/4-1)-1:0] spike_rd_addr_2;
wire spike_wr_en_2; 

//assign spike_wr_en_1 = (v1 && v2 &&  layer_counter[0]) || (en & active_group_in) || i_spike_mem_wr_en[0];
assign spike_wr_en_1 = (v1 && v2 &&  layer_counter[0]) || (en & active_group_in);
//assign spike_wr_en_2 = 	v1 && v2 && ~layer_counter[0] || i_spike_mem_wr_en[1]; 
assign spike_wr_en_2 = 	v1 && v2 && ~layer_counter[0];

wire [3:0] spike_mem_in_1;
//assign spike_mem_in_1 = i_spike_mem_wr_en[0]?i_spike_mem_dat:en?spike_in:spike12;
assign spike_mem_in_1 = en ? spike_in : spike12;

wire [clogb2(MAX_SYNAPSES/4-1)-1:0] spike_rd_addr_1_mux, spike_rd_addr_2_mux, spike_wr_addr_mux;
assign spike_rd_addr_1_mux = i_spike_mem_rd_en[0] ? i_spike_mem_adr : spike_rd_addr_1;
assign spike_rd_addr_2_mux = i_spike_mem_rd_en[1] ? i_spike_mem_adr : spike_rd_addr_2;
assign o_spike_mem_dat = {spike_mem_out_2,spike_mem_out_1};
//assign spike_wr_addr_mux = i_spike_mem_wr_en[0] | i_spike_mem_wr_en[1] ? i_spike_mem_adr : spike_wr_addr;
assign spike_wr_addr_mux = spike_wr_addr;


// written when en is 1 and layer is 0
BRAM_singlePort_readFirst #(
  .RAM_WIDTH(4),            
  .RAM_DEPTH(MAX_SYNAPSES/4),             
  .RAM_PERFORMANCE("HIGH_PERFORMANCE"), 
  .INIT_FILE("")          
)
	spike_mem_1
(
  .addra(spike_wr_addr_mux),    
  .addrb(spike_rd_addr_1_mux),  
  .dina(spike_mem_in_1),   
  .clk(clk),      
  .wea(spike_wr_en_1),      
  .ena(spike_wr_en_1),      
  .enb(1'b1),      
  .rst(rst),      
  .regceb(1'b1),
  
  .doutb(spike_mem_out_1)   
    );

BRAM_singlePort_readFirst #(
  .RAM_WIDTH(4),             
  .RAM_DEPTH(MAX_SYNAPSES/4),             
  .RAM_PERFORMANCE("HIGH_PERFORMANCE"), 
  .INIT_FILE("")             
)
	spike_mem_2
(
  .addra(spike_wr_addr_mux),   
  .addrb(spike_rd_addr_2_mux),  
  .dina(spike12),    
  .clk(clk),     
  .wea(spike_wr_en_2),  
  .ena(spike_wr_en_2), 
  .enb(1'b1),      
  .rst(rst),     
  .regceb(1'b1),
  
  .doutb(spike_mem_out_2)   // Port B RAM output data
    );

wire [3:0] spike_mem_out;
assign spike_mem_out = empty?4'b0:layer_counter[0]?spike_mem_out_2:spike_mem_out_1;

// weight_rd_addr concat neuron_cnt and spike_rd_addr 
wire [WEIGHT_ADDRESS_SIZE-1:0] weight_rd_addr;

assign weight_rd_addr = (layer_counter == 0)?{layer_counter, {P1{1'b0}},
											  neuron_cnt[clogb2(NEURON_1/2-1)-1:0], 
											  spike_rd_addr[SYN_G1_L2-1:0]}:
						(layer_counter == 1)?{layer_counter, {P2{1'b0}},
											  neuron_cnt[clogb2(NEURON_2/2-1)-1:0], 
											  spike_rd_addr[SYN_G2_L2-1:0]}:
						(layer_counter == 2)?{layer_counter, {P3{1'b0}},
											  neuron_cnt[clogb2(NEURON_3/2-1)-1:0], 
											  spike_rd_addr[SYN_G3_L2-1:0]}:
	      									 {layer_counter, {P4{1'b0}},
											  neuron_cnt[clogb2(NEURON_4/2-1)-1:0], 
											  spike_rd_addr[SYN_G4_L2-1:0]};
///////////////////////////////////////////
//   ___  _   _ _____ ____  _   _ _____  //
//  / _ \| | | |_   _|  _ \| | | |_   _| //
// | | | | | | | | | | |_) | | | | | |   //
// | |_| | |_| | | | |  __/| |_| | | |   //
//  \___/ \___/  |_| |_|    \___/  |_|   //
//  ____  _   _ _____ _____ _____ ____   //
// | __ )| | | |  ___|  ___| ____|  _ \  //
// |  _ \| | | | |_  | |_  |  _| | |_) | //
// | |_) | |_| |  _| |  _| | |___|  _ <  //
// |____/ \___/|_|   |_|   |_____|_| \_\ //
//                                       //
///////////////////////////////////////////

wire output_buffer_wr_en;
wire [31:0] output_buffer_din;
assign output_buffer_wr_en = integrated_neuron && layer_counter == 3;
assign output_buffer_din = {voltage_2,voltage_1};

BRAM_singlePort_readFirst #(
  .RAM_WIDTH(2*WIDTH),            
  .RAM_DEPTH(NEURON_4/2),             
  .RAM_PERFORMANCE("LOW_LATENCY"), 
  .INIT_FILE("")          
)
	output_buffer
(
  .addra(integrated_neurons_cnt),   //  
  .addrb(output_buffer_addr),  
  .dina(output_buffer_din),   
  .clk(clk),      
  .wea(output_buffer_wr_en),      
  .ena(output_buffer_wr_en),      
  .enb(output_buffer_ren),      
  .rst(rst),      
  .regceb(1'b1),
  
  .doutb(output_buffer_out)   //
    );

`ifdef CONFIGURABILITY	
	assign valid = integrated_neuron_r && integrated_neurons_cnt_d == NEURON && layer_counter == layers-1;	
	assign valid_spike = valid12 && layer_counter == layers-1;
`else 
	assign valid = integrated_neuron_r && integrated_neurons_cnt_d == NEURON && layer_counter == LAYERS-1;	
	assign valid_spike = valid12 && layer_counter == LAYERS-1;
`endif
	

//  The following function calculates the address width based on specified RAM depth
	function integer clogb2;
	  input integer depth;
		for (clogb2=0; depth>0; clogb2=clogb2+1)
		  depth = depth >> 1;
	endfunction 
	
	function integer max;
	  input integer j,k;
		if(j>k)
		  max = j;
	endfunction 	

	function integer max4;
        input integer a, b, c, d;
        begin
            max4 = (a > b ? a : b) > (c > d ? c : d) ? (a > b ? a : b) : (c > d ? c : d);
        end
    endfunction

endmodule
