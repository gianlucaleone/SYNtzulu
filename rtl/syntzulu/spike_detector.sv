`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10.11.2022 15:01:08
// Design Name: 
// Module Name: spike_detector
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


module spike_detector #(
    parameter CHANNELS = 128,
    parameter ORDER = 2,
    parameter WINDOW = 8192,
    parameter REF_PERIOD = 1024,
    parameter DW = 15
)

(
    input clk, rst,
    input en,
    input signed [DW-1:0] data_in,
    
    output [3:0] spike,
    output valid,
    output active_group,
    input detect
    );

////////////////////////////////////////////////////
//  __  __                                        //
// |  \/  | ___  __ _ _ __                        //
// | |\/| |/ _ \/ _` | '_ \                       //
// | |  | |  __/ (_| | | | |                      //
// |_|  |_|\___|\__,_|_| |_|                      //
//  ____                           _              //
// |  _ \ ___ _ __ ___   _____   _(_)_ __   __ _  //
// | |_) / _ \ '_ ` _ \ / _ \ \ / / | '_ \ / _` | //
// |  _ <  __/ | | | | | (_) \ V /| | | | | (_| | //
// |_| \_\___|_| |_| |_|\___/ \_/ |_|_| |_|\__, | //
//  _____ _ _ _                            |___/  //
// |  ___(_) | |_ ___ _ __                        //
// | |_  | | | __/ _ \ '__|                       //
// |  _| | | | ||  __/ |                          //
// |_|   |_|_|\__\___|_|                          //
//                                                //
////////////////////////////////////////////////////

wire signed [DW-1:0] enhanced_data;
wire valid_mean_removing_filter;
    
mean_removing_filter_bram_implementation #(
        .CHANNELS(CHANNELS), 
        .ORDER(ORDER),
        .DW(DW)
  )
mean_removing_filter_i        
        (
        clk, 
        rst, 
        en, 
        data_in,
        enhanced_data,
        valid_mean_removing_filter
        );    

////////////////////////////////////////////////////
//  _   _                   _           _     _   //
// | |_| |__  _ __ ___  ___| |__   ___ | | __| |  //
// | __| '_ \| '__/ _ \/ __| '_ \ / _ \| |/ _` |  //
// | |_| | | | | |  __/\__ \ | | | (_) | | (_| |  //
//  \__|_| |_|_|  \___||___/_| |_|\___/|_|\__,_|  //
//                                                //
////////////////////////////////////////////////////

wire signed [DW-1:0] threshold;
wire threshold_ready;
                                               
threshold # (    
    .CHANNELS(CHANNELS),    
    .WINDOW(WINDOW),   
    .DW(DW)
) 
threshold_i
(
    clk, rst, valid_mean_removing_filter,
    enhanced_data,
    
    threshold,
    threshold_ready
);

// to be sinchronous with threshold and threshold_ready
reg signed [DW-1:0] r_enhanced_data;
always @(posedge clk)
    if(rst)
        r_enhanced_data <= 0;
    else
        r_enhanced_data <= enhanced_data;

/////////////////////////////////////////////////
//  ____       _            _   _              //
// |  _ \  ___| |_ ___  ___| |_(_) ___  _ __   //
// | | | |/ _ \ __/ _ \/ __| __| |/ _ \| '_ \  //
// | |_| |  __/ ||  __/ (__| |_| | (_) | | | | //
// |____/ \___|\__\___|\___|\__|_|\___/|_| |_| //
//                                             //
/////////////////////////////////////////////////

wire s_spike; // serial spike
wire detection_valid;

detection # (
    .CHANNELS(CHANNELS),
    .REF_PERIOD(REF_PERIOD),
    .DW(DW)
) 
detector_i
(
    clk, rst, threshold_ready,
    r_enhanced_data,
    threshold,
    detect,
    
    s_spike,
    detection_valid
);

////////////////////////////////////////
//                _       _           //
//  ___  ___ _ __(_) __ _| |          //
// / __|/ _ \ '__| |/ _` | |          //
// \__ \  __/ |  | | (_| | |          //
// |___/\___|_|  |_|\__,_|_|          //
//            ____                    //
//           |___ \                   //
//             __) |                  //
//            / __/                   //
//           |_____|      _ _      _  //
//  _ __   __ _ _ __ __ _| | | ___| | //
// | '_ \ / _` | '__/ _` | | |/ _ \ | //
// | |_) | (_| | | | (_| | | |  __/ | //
// | .__/ \__,_|_|  \__,_|_|_|\___|_| //
// |_|                                //
//                                    //
////////////////////////////////////////

s2p #(4) s2p_i (clk, rst, detection_valid, s_spike, spike, valid, active_group);    


endmodule









