`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: Gianluca Leone
// 
// Create Date: 26.01.2024 15:32
// Design Name: 
// Module Name: input_buffer
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


module input_buffer
#(

    parameter CHANNELS = 128,
    parameter DW = 15
)
(
    input clk, rst,
    input en,
    input signed [15:0] data_in,
    
    output reg valid,
    output signed [DW-1:0] data_out,
	
	input external_access_en,
	input [clogb2(CHANNELS-1)-1:0] external_addr,
	output signed [15:0] external_data_out,
	input external_access_wren,
	input signed [15:0] external_data_in
    );

	localparam SIMD = (DW==8)?1:0;
	localparam CHANNELS_INT = SIMD?CHANNELS/2:CHANNELS;

	reg [clogb2(CHANNELS_INT-1)-1:0] pointer;
	reg read_flag;
	
	reg slow_stream_out;
	generate
    if (SIMD) begin
        always @(posedge clk) begin
            if (rst)
                slow_stream_out <= 0;
            else if (read_flag)
                slow_stream_out <= ~slow_stream_out;
        end
    end else begin
        always @(*) begin
            slow_stream_out = 1; // Combinational assignment
        end
    end
	endgenerate

	wire [15:0] data_in_mux;
	assign data_in_mux = external_access_wren ? external_data_in : data_in;
	
	wire wr_en;
	assign wr_en = en | external_access_wren;
	
	wire [15:0] mem_out;

	BRAM_singlePort_readFirst #(
	.RAM_WIDTH(16),
	.RAM_DEPTH(CHANNELS_INT),
	.RAM_PERFORMANCE("LOW_LATENCY"),
	.INIT_FILE("")
	) 
	buffer (
		.addra(adr),
		.addrb(adr),
		.dina(data_in_mux),
		.clk(clk),
		.wea(wr_en),
		.ena(wr_en),
		.enb(1'b1),
		.rst(rst),
		.regceb(1'b1),
		.doutb(mem_out)
	);

	wire [clogb2(CHANNELS_INT-1)-1:0] adr;
	assign adr = external_access_en | external_access_wren ? external_addr : pointer;

	always @(posedge clk)
		if(rst)
			pointer <= 0;
		else if(wr_en)
				if(pointer < CHANNELS_INT)
					pointer <= pointer + 1'b1;
				else
					pointer <= 0;
			 else if(read_flag && slow_stream_out)// if !wr_en
					if(pointer < CHANNELS_INT)
						pointer <= pointer + 1'b1;
					else
						pointer <= 0;
	
	always @(posedge clk)
		if(rst)
			read_flag <= 1'b0;
		else if(wr_en && pointer == CHANNELS_INT-1)
				read_flag <= 1'b1;
				else if(read_flag && slow_stream_out && pointer == CHANNELS_INT-1)
						read_flag <= 1'b0;
					
	always @(posedge clk)
		if(rst) 
			valid <= 0;
		else
			valid <= read_flag;

	generate
		if(SIMD)
			assign data_out = slow_stream_out?mem_out[15:8]:mem_out[7:0];
		else
			assign data_out = mem_out;
	endgenerate

	assign external_data_out = mem_out;
	
	//  The following function calculates the address width based on specified RAM depth
	function integer clogb2;
	  input integer depth;
		for (clogb2=0; depth>0; clogb2=clogb2+1)
		  depth = depth >> 1;
	endfunction   
    
endmodule 
