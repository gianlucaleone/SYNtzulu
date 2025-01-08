`default_nettype none
module servant_clock_gen
  	(
	input wire  i_clk,
	input wire  i_rst,
	output wire o_clk,
	output wire o_half_clk,
	output wire o_slow_clk,
	output wire o_rst,
	output wire o_rst_gfcm,
	input wire bypass,
	input wire low_power_mode
	);

	parameter SIM = 0;
	parameter DOUBLE_CLOCK = 0;
	parameter DIVR = 4'b0000;
	parameter DIVF = 7'b0110100;
	parameter DIVQ = 7'b0110100;
	parameter HFOSC = "0'b01";

	localparam RESET_LENGTH = 12;
	reg [RESET_LENGTH-1:0] rst_reg = 0;
	always @(posedge o_half_clk)
		rst_reg <= {rst_reg[RESET_LENGTH-2:0],1'b1};
	assign o_rst = ~rst_reg[RESET_LENGTH-1];
	assign o_rst_gfcm = ~rst_reg[2];

	generate 
		if(SIM) begin
		
			if(DOUBLE_CLOCK)
				begin
					assign o_half_clk = i_clk | ~low_power_mode;

					reg spi_clk_reg = 0;
					always  #15.5 spi_clk_reg <= !spi_clk_reg | ~low_power_mode;
					assign o_clk = spi_clk_reg | ~low_power_mode;
				end
			else // single clock
				begin
					assign o_half_clk = i_clk | ~low_power_mode;
					assign o_clk = i_clk | ~low_power_mode;
				end

			reg slow_clk_reg = 0;
			always #37200 slow_clk_reg <= !slow_clk_reg;
			assign o_slow_clk = slow_clk_reg;

		 end
		else begin // not sim

			if(DOUBLE_CLOCK) 
				begin
					SB_PLL40_2F_PAD
						pll
							(
							.PACKAGEPIN (i_clk),
							.PLLOUTCOREA(o_clk),
							.PLLOUTCOREB(o_half_clk),
							.RESETB(1'b1),
							.BYPASS(bypass),
							.LATCHINPUTVALUE(low_power_mode)
							);

							//\\ Fin=12, Fout=45;
							defparam pll.DIVR = DIVR;
							defparam pll.DIVF = DIVF;
							defparam pll.DIVQ = DIVQ;
							defparam pll.FILTER_RANGE = 3'b001;
							defparam pll.FEEDBACK_PATH = "SIMPLE";
							defparam pll.DELAY_ADJUSTMENT_MODE_FEEDBACK = "FIXED";
							defparam pll.FDA_FEEDBACK = 4'b0000;
							defparam pll.DELAY_ADJUSTMENT_MODE_RELATIVE = "FIXED";
							defparam pll.FDA_RELATIVE = 4'b0000;
							defparam pll.SHIFTREG_DIV_MODE = 2'b00;
							defparam pll.PLLOUT_SELECT_PORTA = "GENCLK";
							defparam pll.PLLOUT_SELECT_PORTB = "GENCLK_HALF";
							//defparam pll.PLLOUT_SELECT = "GENCLK";
							defparam pll.ENABLE_ICEGATE_PORTA = 1'b1;
							defparam pll.ENABLE_ICEGATE_PORTB = 1'b1;
							//defparam pll.ENABLE_ICEGATE = 1'b0;
					end
				else 
					begin // single clock	
						/*
						SB_PLL40_PAD
						pll
							(
							.PACKAGEPIN (i_clk),
							.PLLOUTCORE(o_clk),			
							.RESETB(1'b1),
							.BYPASS(bypass),
							.LATCHINPUTVALUE(low_power_mode)
							);
						
							assign o_half_clk = o_clk;

							//\\ Fin=12, Fout=45;
							defparam pll.DIVR = DIVR;
							defparam pll.DIVF = DIVF;
							defparam pll.DIVQ = DIVQ;
							defparam pll.FILTER_RANGE = 3'b001;
							defparam pll.FEEDBACK_PATH = "SIMPLE";
							defparam pll.DELAY_ADJUSTMENT_MODE_FEEDBACK = "FIXED";
							defparam pll.FDA_FEEDBACK = 4'b0000;
							defparam pll.DELAY_ADJUSTMENT_MODE_RELATIVE = "FIXED";
							defparam pll.FDA_RELATIVE = 4'b0000;
							defparam pll.SHIFTREG_DIV_MODE = 2'b00;
							defparam pll.PLLOUT_SELECT = "GENCLK";
							defparam pll.ENABLE_ICEGATE = 1'b1;
						*/
						
						SB_HFOSC 
						hfosc 
							( 
							.CLKHFEN(low_power_mode), // andrebbe a zero per 100 us ma se a 6 MHz funziona lo stesso
							.CLKHFPU(1'b1), 
							.CLKHF(o_clk) 
							); 

							// synthesis ROUTE_THROUGH_FABRIC= 1 
							//the value can be either 0 or 1 

							// Parameter CLKHF_DIV = "0b00" (default), "0b01", "0b10", "0b11" 
							// 0b00 = 48 MHz, 0b01 = 24 MHz, 0b10 = 12 MHz, 0b11 = 6 MHz		
							defparam hfosc.CLKHF_DIV = HFOSC; 			

							assign o_half_clk = o_clk;
							
					end
				
					SB_LFOSC  u_lf_osc(.CLKLFPU(1'b1), .CLKLFEN(1'b1), .CLKLF(o_slow_clk));

				end
	endgenerate

endmodule
