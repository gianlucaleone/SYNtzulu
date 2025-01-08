`default_nettype none
`include `CONFIG_PATH
module accelerator_if #(
    parameter WEIGHT_DEPTH_12 = 8192,
    parameter WEIGHT_DEPTH_34 = 8192,
    parameter CHANNELS = 128,
	parameter MAX_NEURONS = 256,
	parameter MAX_SYNAPSES = 256
)
(
	input wire 		   i_wb_clk,
	input wire		   i_wb_rst,

	//from servant_mux, when i_wb_adr[31:30] == 2'b01
	input wire 	[31:0] i_wb_adr,
	input wire 	[31:0] i_wb_dat,
	input wire 		   i_wb_we,
	input wire 		   i_wb_cyc,
	output reg 	[31:0] o_wb_rdt,
	output 		   o_wb_ack,

	// snn
	input wire		   i_snn_valid,
	output output_buffer_ren,
	output [7:0] output_buffer_addr,
	input [31:0] output_buffer_out,
	output wire [31:0] o_snn_adr_w1,
	output wire [31:0] o_snn_adr_w2,
	output wire [31:0] o_snn_adr_w3,
	output wire [31:0] o_snn_adr_w4,
	output wire [ 4:0] o_snn_we,
	output wire [15:0] o_snn_dat,
	output reg  [clogb2(MAX_SYNAPSES-1)-1:0] snn_input_channels, 
	output reg  [clogb2(MAX_NEURONS-1)-1:0] neuron_1, neuron_2, neuron_3, neuron_4, 
	/*neuron_5, neuron_6, neuron_7, neuron_8,*/
	output reg  [2:0] layers,

	// spi
	input  wire [ 7:0] i_spi_dat,
	output wire [23:0] o_spi_adr,
	output wire [31:0] o_spi_siz,

	// ctrl
	input wire		   i_ctrl_clr,
	input wire		   i_ctrl_load1,
	input wire		   i_ctrl_load2,
	input wire 		   i_ctrl_set0,
	input wire		   i_ctrl_snn_we,
	output wire		   o_ctrl_start,

	// uart
	input wire		   i_uart_ready,
	output reg  [ 7:0] o_uart_data,
	output reg		   o_uart_send, 
	output reg		   o_uart_wren,
	output reg 		   o_uart_hp,

	//spike mem 1 & 2
	input wire [7:0] i_spike_mem_dat,
	output wire [7:0] o_spike_mem_adr,
	output wire [1:0] o_spike_mem_rd_en,
	output wire [1:0] o_spike_mem_wr_en,
	output wire [3:0] o_spike_mem_dat,

	// sample mem
	input wire [15:0]  i_sample_mem_dat,	
	output wire [7:0]  o_sample_mem_adr,
	output wire        o_sample_mem_rd_en,
	output wire        o_sample_mem_wr_en,
	output wire [15:0] o_sample_mem_dat,
	
	// encoding bypass
	output reg o_encoding_bypass,

	// gate clocks
	output reg gate_spi, gate_snn, gate_enc, gate_serv, 
	output wire gate_general, 
	input wire timer_irq
	);

	reg [ 7:0] data1, data2;
	reg [23:0] spi_address;
	reg [31:0] snn_address;
	reg [31:0] spi_read_size;
	reg [ 4:0] snn_write_enable;
	reg 	   spi_start;
	reg		   enable_next;
	reg		   uart_send_next;

	wire [31:0] snn_adr;

	reg gate_serv_armed;
	reg gate_general_int;

	initial gate_spi = 0;
	initial gate_snn = 0;
	initial gate_enc = 0;
	initial gate_serv = 0;
	initial gate_serv_armed = 0;
	initial gate_general_int = 0;
	initial snn_valid_rst = 0;
	initial o_uart_hp = 0;
	initial o_uart_data = 0;

	assign gate_general = ~(gate_serv & gate_general_int);

	// bram read requires an extra clock cycle (sample mem) or two (spike mem) 
	// => ack is delayed by 2 c.c if spike mems are accessed, and by 1 c.c. otherwise 
	reg o_wb_ack_int, o_wb_ack_d, o_wb_ack_dd; 
	reg [7:0] i_wb_adr_d;
	always @(posedge i_wb_clk) begin
      o_wb_ack_int <= 1'b0;
	  o_wb_ack_d <= o_wb_ack_int;
	  o_wb_ack_dd <= o_wb_ack_d;
	  i_wb_adr_d <= i_wb_adr[27:20];
      if (i_wb_cyc & !o_wb_ack & !o_wb_ack_d & !o_wb_ack_dd)
	      o_wb_ack_int <= 1'b1;
      if (i_wb_rst) begin
	      o_wb_ack_int <= 1'b0;
		  o_wb_ack_d <= 1'b0;
		  o_wb_ack_dd <= 1'b0;
		  i_wb_adr_d <= 0;
	  end
   end
	
	always @(posedge i_wb_clk, posedge timer_irq)
		if(timer_irq)
			gate_serv <= 1'b0;
		else if(gate_serv_armed) 
				gate_serv <= 1'b1;

	assign o_wb_ack = (i_wb_adr_d == 8'h03 | i_wb_adr_d == 8'h04 | i_wb_adr_d == 8'h05 | i_wb_adr_d == 8'h01) ? o_wb_ack_d : o_wb_ack_int ;	

	assign o_snn_adr_w1 = snn_adr;
	assign o_snn_adr_w2 = snn_adr;
	assign o_snn_adr_w3 = snn_adr;
	assign o_snn_adr_w4 = snn_adr;
	reg snn_valid, snn_valid_rst;
	always @(posedge i_wb_clk) begin
		if(i_wb_rst)
			snn_valid <= 0;
		else if(i_snn_valid)
				 snn_valid <= i_snn_valid;
			 else if(snn_valid_rst)
					snn_valid <= 0;
	end

	assign o_snn_dat		= {data1, data2};
	assign o_spi_adr		= spi_address;
	assign o_spi_siz		= {spi_read_size, 3'b000}; // convert from bytes to bits
	assign o_ctrl_start		= spi_start;
	assign o_snn_we			= snn_write_enable;
	
		
	always @(posedge i_wb_clk)
		if(i_wb_rst)
			o_uart_wren <= 0;
		else
			o_uart_wren <= (i_wb_adr[27:16] == 12'h021) && (i_wb_cyc & i_wb_we & o_wb_ack); // && o_uart_hp

	`ifdef ACCESSIBILITY
		initial $display("ACCESSIBILITY IS DEFINED");

		assign o_spike_mem_adr = i_wb_adr[8:2];
	 	assign o_spike_mem_rd_en[0]  = (i_wb_adr[27:20] == 8'h03) && (i_wb_cyc); // spike mem 1
		assign o_spike_mem_rd_en[1]  = (i_wb_adr[27:20] == 8'h04) && (i_wb_cyc); // spike mem 2
		assign o_spike_mem_wr_en[0]  = (i_wb_adr[27:20] == 8'h03) && (i_wb_cyc && i_wb_we); // spike mem 1
		assign o_spike_mem_wr_en[1]  = (i_wb_adr[27:20] == 8'h04) && (i_wb_cyc && i_wb_we); // spike mem 2
		assign o_spike_mem_dat       = i_wb_dat[3:0];

		assign o_sample_mem_adr =     i_wb_adr[8:2];
		assign o_sample_mem_rd_en  = (i_wb_adr[27:20] == 8'h05) && (i_wb_cyc); // sample mem	
		assign o_sample_mem_wr_en  = (i_wb_adr[27:20] == 8'h05) && (i_wb_cyc && i_wb_we);
		assign o_sample_mem_dat    =  i_wb_dat[15:0];

		assign output_buffer_addr =   i_wb_adr[9:2];
		assign output_buffer_ren  = (i_wb_adr[27:16] == 12'h010) && (i_wb_cyc); // output buffer mem	
	`else
		assign o_spike_mem_rd_en = 0;	
		assign o_spike_mem_wr_en = 0;
		assign o_sample_mem_rd_en = 0;	
		assign o_sample_mem_wr_en = 0;
	`endif

	always @(posedge i_wb_clk) begin
		gate_serv_armed = 0; // auto reset after 1 c.c.
		case (i_wb_adr[27:20])
			//////// SPI ///////
			8'h00: begin								
				case (i_wb_adr[19:16])				
					4'h0: begin	o_wb_rdt <= {8'h0, spi_address};
						if (i_wb_we & i_wb_cyc) begin
							spi_address <= i_wb_dat;
						end
					end	
					4'h1: begin								// snn address
						o_wb_rdt <= snn_address;	
						if (i_wb_we & i_wb_cyc) begin
							snn_address <= i_wb_dat;
						end
					end
					4'h2: begin								// spi read size
						o_wb_rdt <= spi_read_size;
						if (i_wb_we & i_wb_cyc) begin
							spi_read_size <= i_wb_dat;
						end
					end
					4'h3: begin
						o_wb_rdt <= {31'h0, spi_start};		// spi start
					end
				endcase
			end
			//////// OUTPUT BUFFER ///////
			8'h01: begin			
				case (i_wb_adr[19:16])
					
					4'h0: begin							// v
						o_wb_rdt <= output_buffer_out;
					end
					/*
					4'h1: begin							// f1
						o_wb_rdt <= {16'h0, i_snn_f1};
					end
					4'h2: begin							// f2
						o_wb_rdt <= {16'h0, i_snn_f2};
					end
					4'h3: begin							// f3
						o_wb_rdt <= {16'h0, i_snn_f3};
					end
					4'h4: begin							// f4
						o_wb_rdt <= {16'h0, i_snn_f4};
					end
					*/
					4'hf: begin							// valid inference
						o_wb_rdt <= {16'h0, snn_valid}; 
					end
					4'he: begin							// valid inference reset
						o_wb_rdt <= {31'b0,snn_valid_rst};
						if (i_wb_cyc & o_wb_ack) begin
							snn_valid_rst <= i_wb_dat[0];
						end
					end
				endcase
			end
			///////////////////////////////////////////////////////////////////////			
			`ifndef UART_HP //////// UART ///////
			///////////////////////////////////////////////////////////////////////
			8'h02: begin			
				case (i_wb_adr[19:16])
					4'h0: begin										// o_uart_data
						o_wb_rdt <= {24'h0, o_uart_data};
						if (i_wb_cyc & i_wb_we) begin
							o_uart_data <= i_wb_dat;
						end
					end
					4'h1: begin
						o_wb_rdt <= {31'h0, o_uart_send};			// i_uart_send
					end
					4'h2: begin
						o_wb_rdt <= {31'h0, i_uart_ready};			// i_uart_ready
					end 
					4'h3: begin										// o_uart_hp high performance
						o_wb_rdt <= {31'h0, o_uart_hp};
						if (i_wb_cyc & i_wb_we) begin
							o_uart_hp <= i_wb_dat[0];
						end
					end
				endcase
			end

			`endif
		
			///////////////////////////////////////////////////////////////////////
			///////////////////////////////////////////////////////////////////////

			///////////////////////////////////////////////////////////////////////
			`ifdef ACCESSIBILITY
			///////////////////////////////////////////////////////////////////////

			8'h03: begin									// spike_mem_1
				o_wb_rdt <= {28'b0,i_spike_mem_dat[3:0]};	
			end
			8'h04: begin
				o_wb_rdt <= {28'b0,i_spike_mem_dat[7:4]};   // spike_mem_2
			end
			8'h05: begin
				o_wb_rdt <= {16'b0,i_sample_mem_dat};       // sample_mem
			end
			
			//////// ENCODING SETTINGS ///////
			8'h06: begin			
				case (i_wb_adr[19:16])
					4'h0: begin
						if (i_wb_cyc & i_wb_we) 			// encoding bypass
							o_encoding_bypass <= i_wb_dat[0];			
					end
				endcase
			end
			
			`endif
		
			///////////////////////////////////////////////////////////////////////
			///////////////////////////////////////////////////////////////////////
			
			///////////////////////////////////////////////////////////////////////
			`ifdef CONFIGURABILITY
			///////////////////////////////////////////////////////////////////////

			//////// SNN SETTINGS ///////
			8'h07: begin			
				case (i_wb_adr[19:16])
					4'h0: begin
						if (i_wb_cyc & i_wb_we) 			// snn_input_channels
							snn_input_channels <= i_wb_dat[clogb2(MAX_SYNAPSES-1)-1:0];			
					end
					4'h1: begin
						if (i_wb_cyc & i_wb_we) 			// #neuron L1
							neuron_1 <= i_wb_dat[clogb2(MAX_NEURONS-1)-1:0];			
					end
					4'h2: begin
						if (i_wb_cyc & i_wb_we) 			// #neuron L2
							neuron_2 <= i_wb_dat[clogb2(MAX_NEURONS-1)-1:0];			
					end
					4'h3: begin
						if (i_wb_cyc & i_wb_we) 			// #neuron L3
							neuron_3 <= i_wb_dat[clogb2(MAX_NEURONS-1)-1:0];			
					end
					4'h4: begin
						if (i_wb_cyc & i_wb_we) 			// #neuron L4
							neuron_4 <= i_wb_dat[clogb2(MAX_NEURONS-1)-1:0];			
					end

					4'h9: begin
						if (i_wb_cyc & i_wb_we) 			// #layer
							layers <= i_wb_dat[2:0];			
					end			
				endcase
			end

			`endif
			
			///////////////////////////////////////////////////////////////////////
			///////////////////////////////////////////////////////////////////////
			
			///////////////////////////////////////////////////////////////////////
			`ifdef LOW_POWER
			///////////////////////////////////////////////////////////////////////

			//////// GATE CLOCK ///////
			8'h08: begin
					o_wb_rdt <= {27'b0,gate_general_int,gate_serv_armed,gate_enc,gate_snn,gate_spi};
					if (i_wb_cyc & i_wb_we) begin
							gate_spi <= i_wb_dat[0];
							gate_snn <= i_wb_dat[1];
							gate_enc <= i_wb_dat[2];	
							gate_serv_armed = i_wb_dat[3];
							gate_general_int <= i_wb_dat[4];
					end
			end

			`endif
			
			///////////////////////////////////////////////////////////////////////
			///////////////////////////////////////////////////////////////////////

			default: begin
				o_wb_rdt <= 32'h0;
			end

		endcase

		if (i_ctrl_load1) begin							// load data1
			data1 <= i_spi_dat;
		end	

		if (i_ctrl_load2) 							// load data2
			data2 <= i_spi_dat;		
		

		spi_start <= enable_next;
		o_uart_send <= uart_send_next;

	end

	always @(*) begin
		if (i_ctrl_set0) begin							// reset spi_start
			enable_next = 0;
		end
		else if (i_wb_adr[27:16] == 12'h003 && i_wb_we && i_wb_cyc) begin
			enable_next = i_wb_dat[0];
		end
		else begin
			enable_next = spi_start;
		end

		if (i_wb_adr[27:16] == 12'h021 && i_wb_we && i_wb_cyc) begin
			uart_send_next = i_wb_dat;
		end
		else begin
			uart_send_next = 0;
		end
	end

	// combinatorial logic for write enables and addresses for snn
	always @(*) begin
		if (i_ctrl_snn_we) begin
			case (snn_address)
				1: begin
					snn_write_enable = 5'b00001;
				end
				2: begin
					snn_write_enable = 5'b00010;
				end
				3: begin
					snn_write_enable = 5'b00100;
				end
				4: begin
					snn_write_enable = 5'b01000;
				end
				5: begin
					snn_write_enable = 5'b10000;
				end
				default: begin
					snn_write_enable = 5'b00000;
				end
			endcase
		end
		else begin
			snn_write_enable = 5'b00000;
		end
	end

	snn_addr_counter #(
		.DEPTH(max3(WEIGHT_DEPTH_12, WEIGHT_DEPTH_34, CHANNELS))
	)
	snn_addr_counter
	(
		.clk	(i_wb_clk),
		.rst	(i_wb_rst),
		.clr	(i_ctrl_clr),
		.inc	(i_ctrl_snn_we),
		.addr	(snn_adr)
	);

	//  The following function calculates the address width based on specified RAM depth
	function integer clogb2;
	  input integer depth;
		for (clogb2=0; depth>0; clogb2=clogb2+1)
		  depth = depth >> 1;
	endfunction 

	function integer max3;
  		input integer a,b,c;
    		if (a>b)
      			if (a>c)
        			max3 = a;
      			else
        			max3 = c;
    		else if (b>c)
        		max3 = b;
      		else
        		max3 = c;
	endfunction 

endmodule
