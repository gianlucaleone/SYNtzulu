`default_nettype none
// 011 gpio
// 010 accelerator

module gpio_accelerator_mux
  (input wire         i_wb_clk,
   input wire  [31:0] i_wb_adr,
   input wire  [31:0] i_wb_dat,
   input wire         i_wb_we,
   input wire         i_wb_cyc,
   output wire [31:0] o_wb_rdt,
   
   //output wire [31:0] o_wb_gpio_adr,
   output wire        o_wb_gpio_dat,
   output wire 	      o_wb_gpio_we,
   output wire 	      o_wb_gpio_cyc,
   input wire         i_wb_gpio_rdt,
   
   output wire [31:0] o_wb_acc_adr,
   output wire [31:0] o_wb_acc_dat,
   output wire 	      o_wb_acc_we,
   output wire 	      o_wb_acc_cyc,
   input wire  [31:0] i_wb_acc_rdt);

   wire s = i_wb_adr[29];

   assign o_wb_rdt = s ? {31'b0, i_wb_gpio_rdt} : i_wb_acc_rdt;

   //assign o_wb_gpio_adr = i_wb_adr;
   assign o_wb_gpio_dat = i_wb_dat[0];
   assign o_wb_gpio_we  = i_wb_we;

   assign o_wb_acc_adr = i_wb_adr;
   assign o_wb_acc_dat = i_wb_dat;
   assign o_wb_acc_we  = i_wb_we;

   assign o_wb_gpio_cyc = i_wb_cyc & s;
   assign o_wb_acc_cyc  = i_wb_cyc & ~s;

endmodule