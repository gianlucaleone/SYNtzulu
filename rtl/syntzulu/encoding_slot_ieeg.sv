`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.02.2024 
// Design Name: 
// Module Name: encoding_slot_ieeg
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


module encoding_slot_ieeg
#(
    parameter CHANNELS = 128,
    parameter ORDER = 2,
    parameter WINDOW = 8192,
    parameter REF_PERIOD = 16,
    parameter DW = 15
)
(
    input clk, rst,
    input en,
    input signed [DW-1:0] data_in,
    input detect,
    
    output [3:0] spike_bin,
    output valid_bin,
    output active_group_out_bin
    );

 localparam SPIKE  = 4;

//////////////////////////////////////////////
//  ____        _ _                         //
// / ___| _ __ (_) | _____                  //
// \___ \| '_ \| | |/ / _ \                 //
//  ___) | |_) | |   <  __/                 //
// |____/| .__/|_|_|\_\___|                 //
//  ____ |_|   _            _               //
// |  _ \  ___| |_ ___  ___| |_ ___  _ __   //
// | | | |/ _ \ __/ _ \/ __| __/ _ \| '__|  //
// | |_| |  __/ ||  __/ (__| || (_) | |     //
// |____/ \___|\__\___|\___|\__\___/|_|     //
//                                          //
//////////////////////////////////////////////                                        
    
 wire [SPIKE-1:0] spike_sd;
 wire valid_sd;
 wire active_group_sd;

 spike_detector #(
    .CHANNELS(CHANNELS),
    .ORDER(ORDER),
    .WINDOW(WINDOW),
    .REF_PERIOD(REF_PERIOD),
    .DW(DW)
)
spike_detector_i
(
    clk, rst,
    en,
    data_in,
    
    spike_sd,
    valid_sd,
    active_group_sd,
    detect
    );   

/////////////////////////////////////////
//  ____        _ _                    //
// / ___| _ __ (_) | _____             //
// \___ \| '_ \| | |/ / _ \            //
//  ___) | |_) | |   <  __/            //
// |____/| .__/|_|_|\_\___|            //
//       |_|                           //
//  _     _             _              //
// | |__ (_)_ __  _ __ (_)_ __   __ _  //
// | '_ \| | '_ \| '_ \| | '_ \ / _` | //
// | |_) | | | | | | | | | | | | (_| | //
// |_.__/|_|_| |_|_| |_|_|_| |_|\__, | //
//                              |___/  //
/////////////////////////////////////////

spike_binning
#(
    .CHANNELS(CHANNELS),
    .SPIKE(SPIKE)
)
spike_binning_i
    (
    clk, rst,
    valid_sd,
    spike_sd,
    active_group_sd,
    
    spike_bin,
    valid_bin,
    active_group_out_bin
    );

endmodule
