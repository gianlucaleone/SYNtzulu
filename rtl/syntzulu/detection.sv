`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Eolab
// Engineer: Gianluca Leone
// 
// Create Date: 08.11.2022 11:04:18
// Design Name: SNN-based decoder accelerator
// Module Name: layer
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

module detection # (
    parameter CHANNELS = 128,
    parameter REF_PERIOD = 16,
    parameter DW = 15
) 
(
    input clk, rst, en,
    input signed [DW-1:0] enhanced_data,
    input signed [DW-1:0] threshold,
    input detect,
    
    output spike,
    output reg valid
);

///////////////////////////////////////////
//      _                            _   //
//   ___| |__   __ _ _ __  _ __   ___| | //
//  / __| '_ \ / _` | '_ \| '_ \ / _ \ | //
// | (__| | | | (_| | | | | | | |  __/ | //
//  \___|_| |_|\__,_|_| |_|_| |_|\___|_| //
//                        _              //
//   ___ ___  _   _ _ __ | |_ ___ _ __   //
//  / __/ _ \| | | | '_ \| __/ _ \ '__|  //
// | (_| (_) | |_| | | | | ||  __/ |     //
//  \___\___/ \__,_|_| |_|\__\___|_|     //
//                                       //              
///////////////////////////////////////////

reg [clogb2(CHANNELS-1)-1:0] channel_cnt, r_channel_cnt;
always @(posedge clk)
    if (rst) begin
        channel_cnt <= 0;
        r_channel_cnt <= 0;
      end
    else begin 
        if(en) 
            channel_cnt <= channel_cnt + 1'b1;  
        r_channel_cnt <= channel_cnt;
      end
            
////////////////////////////////////////////////////////////////
//  ____       __                _                            //
// |  _ \ ___ / _|_ __ __ _  ___| |_ ___  _ __ _   _          //
// | |_) / _ \ |_| '__/ _` |/ __| __/ _ \| '__| | | |         //
// |  _ <  __/  _| | | (_| | (__| || (_) | |  | |_| |         //
// |_| \_\___|_| |_|  \__,_|\___|\__\___/|_|   \__, |         //
//                  _           _              |___/          //
//  _ __   ___ _ __(_) ___   __| |  _ __ ___   ___ _ __ ___   //
// | '_ \ / _ \ '__| |/ _ \ / _` | | '_ ` _ \ / _ \ '_ ` _ \  //
// | |_) |  __/ |  | | (_) | (_| | | | | | | |  __/ | | | | | //
// | .__/ \___|_|  |_|\___/ \__,_| |_| |_| |_|\___|_| |_| |_| //
// |_|                                                        //
////////////////////////////////////////////////////////////////

wire [clogb2(REF_PERIOD-1)-1:0] ref_time;
wire [clogb2(REF_PERIOD-1)-1:0] mem_data_in;

BRAM_singlePort_readFirst
#(
  .RAM_WIDTH(clogb2(REF_PERIOD-1)), // Specify RAM data width
  .RAM_DEPTH(CHANNELS),             // Specify RAM depth (number of entries)
  .RAM_PERFORMANCE("LOW_LATENCY"),  // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
  .INIT_FILE("")                    // Specify name/location of RAM initialization file if using one (leave blank if not)
  )
ref_period_mem
 (
  .addra(r_channel_cnt),           // Port A address bus, driven by axi bus
  .addrb(channel_cnt),             // Port B address bus, it goes in the accumulator
  .dina(mem_data_in),              // Port A RAM input data, driven by axi bus
  .clk(clk),                       // Clock
  .wea(valid),                     // Port A write enable
  .ena(valid),                     // Port A RAM Enable, for additional power savings, disable port when not in use
  .enb(1'b1),                      // Port B RAM Enable, for additional power savings, disable port when not in use
  .rst(rst),                       // Port A and B output reset (does not affect memory contents)
  .regceb(1'b1),                   // Port B output register enable
  
  .doutb(ref_time)                 // Port B RAM output data
);       

/////////////////////////////////////////////////
//  ____       _            _   _              //
// |  _ \  ___| |_ ___  ___| |_(_) ___  _ __   //
// | | | |/ _ \ __/ _ \/ __| __| |/ _ \| '_ \  //
// | |_| |  __/ ||  __/ (__| |_| | (_) | | | | //
// |____/ \___|\__\___|\___|\__|_|\___/|_| |_| //
//                                             //
/////////////////////////////////////////////////

wire spike_internal;   
wire [DW+2-1:0] threshold_4;         
assign threshold_4 = {threshold,2'b0};
assign spike_internal = (enhanced_data > threshold_4) && en && detect;    

reg r_spike_internal;
always @(posedge clk)
    if (rst)
        r_spike_internal <= 0;
    else 
        r_spike_internal <= spike_internal;

assign spike = (ref_time == 0) && r_spike_internal; 

// feeding back the refractory period memory  
wire [clogb2(REF_PERIOD-1)-1:0] ref_time_updated;
assign ref_time_updated = ref_time == 9 ? 0: ref_time + 1'b1;
assign mem_data_in = r_spike_internal || (ref_time != 0)? ref_time_updated : 0;

always @(posedge clk)
    if (rst)
      valid <= 0;
    else
      valid <= en & detect;

            
//  The following function calculates the address width based on specified RAM depth
function integer clogb2;
  input integer depth;
    for (clogb2=0; depth>0; clogb2=clogb2+1)
      depth = depth >> 1;
endfunction 

endmodule
