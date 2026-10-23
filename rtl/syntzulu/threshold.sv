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

module threshold # (
    parameter CHANNELS = 128,
    parameter WINDOW = 8192,
    parameter DW = 15
) 
(
    input clk, rst, en,
    input [DW-1:0] enhanced_data,
    
    output [DW-1:0] threshold,
    output reg valid
);

localparam THRESHOLD_GAIN = 4;
localparam THRESHOLD_GAIN_L2 = 2;

reg [clogb2(WINDOW-1) -1 : 0] current_time;

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
            
////////////////////////////////////////////////////
//  _   _                   _           _     _  //
// | |_| |__  _ __ ___  ___| |__   ___ | | __| | //
// | __| '_ \| '__/ _ \/ __| '_ \ / _ \| |/ _` | //
// | |_| | | | | |  __/\__ \ | | | (_) | | (_| | //
//  \__|_| |_|_|  \___||___/_| |_|\___/|_|\__,_| //
//  _ __ ___   ___ _ __ ___   ___  _ __ _   _    //
// | '_ ` _ \ / _ \ '_ ` _ \ / _ \| '__| | | |   //
// | | | | | |  __/ | | | | | (_) | |  | |_| |   //
// |_| |_| |_|\___|_| |_| |_|\___/|_|   \__, |   //
//                                      |___/    //
///////////////////////////////////////////////////

wire [DW-1:0] threshold_in;

BRAM_singlePort_readFirst
#(
  .RAM_WIDTH(DW),         // Specify RAM data width
  .RAM_DEPTH(CHANNELS),             // Specify RAM depth (number of entries)
  .RAM_PERFORMANCE("LOW_LATENCY"),  // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
  .INIT_FILE("sim/mem/ieeg/thr.txt")             // Specify name/location of RAM initialization file if using one (leave blank if not)
  )
threshold_mem
 (
  .addra(r_channel_cnt),           // Port A address bus, driven by axi bus
  .addrb(channel_cnt),             // Port B address bus, it goes in the accumulator
  .dina(threshold_in),             // Port A RAM input data, driven by axi bus
  .clk(clk),                       // Clock
  .wea(valid),                     // Port A write enable
  .ena(valid),                     // Port A RAM Enable, for additional power savings, disable port when not in use
  .enb(1'b1),                      // Port B RAM Enable, for additional power savings, disable port when not in use
  .rst(rst),                       // Port A and B output reset (does not affect memory contents)
  .regceb(1'b1),                   // Port B output register enable
  
  .doutb(threshold)                // Port B RAM output data
);       

///////////////////////////////////////////////////                                              
//  _ __   _____      __                         //
// | '_ \ / _ \ \ /\ / /                         //
// | | | |  __/\ V  V /                          //
// |_| |_|\___| \_/\_/                           //
//  _   _                   _           _     _  //
// | |_| |__  _ __ ___  ___| |__   ___ | | __| | //
// | __| '_ \| '__/ _ \/ __| '_ \ / _ \| |/ _` | //
// | |_| | | | | |  __/\__ \ | | | (_) | | (_| | //
//  \__|_| |_|_|  \___||___/_| |_|\___/|_|\__,_| //
//  _ __ ___   ___ _ __ ___   ___  _ __ _   _    //
// | '_ ` _ \ / _ \ '_ ` _ \ / _ \| '__| | | |   //
// | | | | | |  __/ | | | | | (_) | |  | |_| |   //
// |_| |_| |_|\___|_| |_| |_|\___/|_|   \__, |   //
//                                      |___/    //
//                                               //
///////////////////////////////////////////////////                                               

(* use_dsp = "yes" *)
wire [DW + clogb2(WINDOW-1) - 1:0] updated_thr;
wire [DW + clogb2(WINDOW-1) - 1:0] future_threshold;

BRAM_singlePort_readFirst
#(
  .RAM_WIDTH(DW + clogb2(WINDOW-1)), // Specify RAM data width
  .RAM_DEPTH(CHANNELS),                        // Specify RAM depth (number of entries)
  .RAM_PERFORMANCE("LOW_LATENCY"),             // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
  .INIT_FILE("")                               // Specify name/location of RAM initialization file if using one (leave blank if not)
  )
new_threshold_mem
 (
  .addra(r_channel_cnt),           // Port A address bus, driven by axi bus
  .addrb(channel_cnt),             // Port B address bus, it goes in the accumulator
  .dina(updated_thr),              // Port A RAM input data, driven by axi bus
  .clk(clk),                       // Clock
  .wea(valid),                     // Port A write enable
  .ena(valid),                     // Port A RAM Enable, for additional power savings, disable port when not in use
  .enb(1'b1),                      // Port B RAM Enable, for additional power savings, disable port when not in use
  .rst(rst),                       // Port A and B output reset (does not affect memory contents)
  .regceb(1'b1),                   // Port B output register enable
  
  .doutb(future_threshold)                // Port B RAM output data
);     

///////////////////////////////////////////////////
//  _   _                   _           _     _  //
// | |_| |__  _ __ ___  ___| |__   ___ | | __| | //
// | __| '_ \| '__/ _ \/ __| '_ \ / _ \| |/ _` | //
// | |_| | | | | |  __/\__ \ | | | (_) | | (_| | //
//  \__|_| |_|_|  \___||___/_| |_|\___/|_|\__,_| //
//                        _       _              //
//        _   _ _ __   __| | __ _| |_ ___        //
//       | | | | '_ \ / _` |/ _` | __/ _ \       //
//       | |_| | |_) | (_| | (_| | ||  __/       //
//        \__,_| .__/ \__,_|\__,_|\__\___|       //
//             |_|                               //
///////////////////////////////////////////////////

reg signed [DW-1:0] r_enhanced_data;
always @(posedge clk)
    if(rst)
        r_enhanced_data <= 0;
    else 
        r_enhanced_data <= enhanced_data;

assign updated_thr = (current_time == 0)? r_enhanced_data : future_threshold + r_enhanced_data;

////////////////////////////////////////////////////////////////////
//           _           _                 _   _                  //
// __      _(_)_ __   __| | _____      __ | |_(_)_ __ ___   ___   //
// \ \ /\ / / | '_ \ / _` |/ _ \ \ /\ / / | __| | '_ ` _ \ / _ \  //
//  \ V  V /| | | | | (_| | (_) \ V  V /  | |_| | | | | | |  __/  //
//   \_/\_/ |_|_| |_|\__,_|\___/ \_/\_/    \__|_|_| |_| |_|\___|  //
//                                                                //
//                                                                //
////////////////////////////////////////////////////////////////////

always @(posedge clk)
    if(rst)
        current_time <= 0;
    else
        if(en && (channel_cnt == (CHANNELS - 1)))
            current_time <= current_time + 1'b1;

///////////////////////////////////////////////////////
//                _ _         _                _     //
// __      ___ __(_) |_ ___  | |__   __ _  ___| | __ //
// \ \ /\ / / '__| | __/ _ \ | '_ \ / _` |/ __| |/ / //
//  \ V  V /| |  | | ||  __/ | |_) | (_| | (__|   <  //
//   \_/\_/ |_|  |_|\__\___| |_.__/ \__,_|\___|_|\_\ //
//                                                   //
///////////////////////////////////////////////////////

wire [DW-1:0] updated_thr_shift;
wire [DW-1:0] updated_thr_shift_pos;
wire [DW + clogb2(WINDOW-1) - 1:0] updated_thr_shift_neg1;
wire [DW-1:0] updated_thr_shift_neg2;
assign updated_thr_shift_pos = updated_thr[DW + clogb2(WINDOW-1) - 1 : clogb2(WINDOW-1)];
assign updated_thr_shift_neg1 = ~updated_thr+1'b1;
assign updated_thr_shift_neg2 = updated_thr_shift_neg1[DW + clogb2(WINDOW-1) - 1 : clogb2(WINDOW-1)];
assign updated_thr_shift = updated_thr[DW + clogb2(WINDOW-1) - 1]?updated_thr_shift_neg2:updated_thr_shift_pos;
assign threshold_in = (current_time == WINDOW-1)? updated_thr_shift : threshold;

always @(posedge clk)
    if (rst)
      valid <= 0;
    else
      valid <= en;
      
             
//  The following function calculates the address width based on specified RAM depth
function integer clogb2;
  input integer depth;
    for (clogb2=0; depth>0; clogb2=clogb2+1)
      depth = depth >> 1;
endfunction 

endmodule
