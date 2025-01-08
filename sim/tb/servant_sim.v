`default_nettype none
module servant_sim
  (input wire	      wb_clk,
   input wire	      wb_rst,
   output wire [31:0] pc_adr,
   output wire	      pc_vld,
   output wire	      q,
   input wire [2:0] buttons);

   parameter memfile = "firmware/exe.hex";
   parameter memsize = 8192;
   parameter with_csr = 1;
   parameter compressed = 0;
   parameter align = compressed;
	
   /*
   reg [1023:0] firmware_file;
   initial
     if ($value$plusargs("firmware=%s", firmware_file)) begin
	$display("Loading RAM from %0s", firmware_file);
	$readmemh(firmware_file, dut.ram.mem);
     end
   */
	
	wire SPI_SS, SPI_MOSI, SPI_MISO, SPI_CLK;

   service   
	`ifndef PSIM	
		#(.SIM(1), .PLL("NONE"),
		   .memfile  (memfile),
		   .memsize  (memsize)
		  )
	`endif
   service_i(	.i_clk(wb_clk),
				.i_rst(wb_rst),
				.led(q),
				.buttons(buttons),
				.o_flash_ss(SPI_SS),
				.o_flash_sck(SPI_CLK),
				.o_flash_mosi(SPI_MOSI),
				.i_flash_miso(SPI_MISO),
				.o_txd()
			); // change con service interface

   //assign pc_adr = dut.wb_ibus_adr;
   //assign pc_vld = dut.wb_ibus_ack;

	spiflash spiflash_i(
	.csb(SPI_SS),
	.clk(SPI_CLK),
	.io0(SPI_MOSI), // MOSI
	.io1(SPI_MISO), // MISO
	.io2(),
	.io3()
);

endmodule
