//spi master module for flash reading (N25Q032A)
module spi_master(
	 input wire clk,
	 input wire reset,
	 output reg SPI_SCK,
	 output SPI_SS,
	 output reg SPI_MOSI,
	 input wire SPI_MISO,
	 input en,
	 input [23:0] addr,
	 output reg valid,
	 output reg end_transaction,
	 input wire rd_ack, 
	 output reg [7:0] rd_data,
	 input wire [17:0] words_to_read,
	 input read_req,
	 input [7:0] wr_data
	);

	//states
	parameter [2:0] IDLE = 0, SEND_CMD = 1, SEND_ADDR= 2, READ_FLASH= 3, WAIT_ACK = 4, SEND_WREN_CMD = 5, WRITE_FLASH = 6;

	reg [2:0] counter_clk;
	reg [17:0] counter_send; //64 max
	reg [2:0] state;
	reg [23:0] read_addr_reg;
	reg [7:0] wr_data_reg;
	reg [7:0] read_cmd;
	reg [7:0] write_cmd;
	reg [7:0] write_en_cmd;
	reg [7:0] cmd;
	reg spi_ss_reg;
	reg read_req_r;
	reg [17:0] words_to_read_reg;
	reg [17:0] words_to_read_reg_sub0, words_to_read_reg_sub1;

	assign SPI_SS = spi_ss_reg;

	/*initial begin
		SPI_SCK = 0;
		valid = 0;

		counter_clk = 0;
		counter_send = 0;
		state = IDLE;
		read_addr_reg = 0;
		end_transaction <= 0;

		//bunch of commands to read status registers as well as the flash from the datasheet
		read_cmd = 8'h03; //read
		write_en_cmd = 8'h06; // page program
		write_cmd = 8'h02; // page program

		SPI_MOSI = 0;
		spi_ss_reg = 1; //active low
		rd_data = 0;
		
		words_to_read_reg <= 0;
	end*/

	always @(posedge clk)
	begin
		if(reset == 1) begin
			state <= IDLE;
		end else begin
			case (state)
				IDLE : begin //wait for an address to be written
					spi_ss_reg <= 1; //un select slave

					// signals from initial
					SPI_SCK <= 0;
					valid <= 0;
					counter_clk <= 0;
					counter_send <= 0;
					//read_addr_reg <= 0;
					end_transaction <= 0;
						//bunch of commands to read status registers as well as the flash from the datasheet
					read_cmd <= 8'h03; //read
					write_en_cmd <= 8'h06; // page program
					write_cmd <= 8'h02; // page program

					SPI_MOSI <= 0;
					spi_ss_reg <= 1; //active low
					rd_data <= 0;
					
					// words_to_read_reg <= 0;
					// end signals from initial

					if(en == 1) begin
						read_addr_reg <= addr;
						wr_data_reg <= wr_data;
						state <= read_req?SEND_CMD:SEND_WREN_CMD; //go directly to the sending of the READ command
						cmd <= read_req?read_cmd:write_cmd;
						read_req_r <= read_req;
						words_to_read_reg <= words_to_read;
					end
				end

				//send a wake up command to the flash, not needed when only reading the flash
				//skipped here
				SEND_WREN_CMD : begin
					counter_clk <= counter_clk + 1;
					spi_ss_reg <= 0;

					if(counter_clk == 3'b000)begin
						SPI_MOSI <= write_en_cmd[7]; //MSB
						SPI_SCK <= 0;
					end

					if(counter_clk >= 3'b001) begin
						SPI_SCK <= 1;
						write_en_cmd[7:0] <= {write_en_cmd[6:0], write_en_cmd[7]};
						counter_clk <= 0;
						counter_send <= counter_send + 1;
						if(counter_send == 7) begin
							spi_ss_reg <= 1;
							state <= SEND_CMD;
							counter_send <= 0;
						end
					end

				end

				//send the read command (8 bit)
				SEND_CMD : begin
					counter_clk <= counter_clk + 1;
					spi_ss_reg <= 0;

					if(counter_clk == 3'b000)begin
						SPI_SCK <= 0;
						SPI_MOSI <= cmd[7]; //MSB
					end

					if(counter_clk >= 3'b001) begin
						SPI_SCK <= 1;
						cmd[7:0] <= {cmd[6:0], cmd[7]};
						counter_clk <= 0;
						counter_send <= counter_send + 1;
						if(counter_send == 7) begin
							state <= SEND_ADDR;
							counter_send <= 0;
						end
					end

				end

				//send the 24bit address we want to read from
				SEND_ADDR : begin
					counter_clk <= counter_clk + 1;
					spi_ss_reg <= 0; //slave is selected

					if(counter_clk == 3'b000) begin
						SPI_MOSI <= read_addr_reg[23]; //MSB
						SPI_SCK <= 0;
					end

					if(counter_clk == 3'b001) begin
						SPI_SCK <= 1;
					end

					if(counter_clk == 3'b010) begin
						SPI_SCK <= 0;
						read_addr_reg[23:0] <= {read_addr_reg[22:0], read_addr_reg[23]};
						counter_clk <= 0;
						counter_send <= counter_send + 1;
						if(counter_send == 23) begin
							state <= read_req_r?READ_FLASH:WRITE_FLASH;
							words_to_read_reg_sub0 <= words_to_read_reg;
							counter_send <= 0;
							
						end
					end
				end

				//read the actual flash value (32bit)
				READ_FLASH: begin
					counter_clk <= counter_clk + 1;
					SPI_MOSI <= 0;
					spi_ss_reg <= 0; //slave is selected
					valid = 0; // init

					if(counter_clk == 3'b000) begin
						SPI_SCK <= 1;
						words_to_read_reg_sub1 <= words_to_read_reg_sub0-1;
						
					end

					if(counter_clk == 3'b001) begin
						SPI_SCK <= 0;
						rd_data[7:0] <= {rd_data[6:0], SPI_MISO};
						counter_clk <= 0;
						counter_send <= counter_send + 1;
						if(counter_send[2:0] == 7) begin
							valid <= 1;
							if(counter_send == /* words_to_read_reg-1 */words_to_read_reg_sub1) begin
								counter_send <= 0;
								state <= WAIT_ACK;
								spi_ss_reg <= 1; //un select slave
							end
						end
						else valid <= 0;
					end

				end
				


				//now that the data is saved, wait for the next read request
				WAIT_ACK: begin
					spi_ss_reg <= 1; //un select slave
					end_transaction <= 1;
					valid <= 0;
					if(rd_ack == 1) begin
						state <= IDLE;
						end_transaction <= 0;
					end
				end
				default: begin
					state <= IDLE;
				end
			endcase

		end
	end
endmodule
