`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11.11.2022 10:17:54
// Design Name: 
// Module Name: spike_binning
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


module spike_binning
#(
    parameter CHANNELS = 128,
    parameter SPIKE = 4
)
    (
    input clk, rst,
    input en,
    input [3:0] spike_in,
    input active_group_in,
    
    output [3:0] spike_out,
    output valid,
    output active_group_out
    );
 
 localparam DEPTH = CHANNELS/SPIKE;
 localparam FREQUENCY_RATIO = 10; // Electrode signal frequency is 10 Khz (0.1 ms), binning is 1 ms period

 /////////////////////////////////////////////
 //                                         //
 //    ____ _                            _  //
 //  / ___| |__   __ _ _ __  _ __   ___| |  //
 // | |   | '_ \ / _` | '_ \| '_ \ / _ \ |  //
 // | |___| | | | (_| | | | | | | |  __/ |  //
 //  \____|_| |_|\__,_|_| |_|_| |_|\___|_|  //
 //                        _                //
 //   ___ ___  _   _ _ __ | |_ ___ _ __     //
 //  / __/ _ \| | | | '_ \| __/ _ \ '__|    //
 // | (_| (_) | |_| | | | | ||  __/ |       //
 //  \___\___/ \__,_|_| |_|\__\___|_|       //
 //                                         //
 //                                         //
 /////////////////////////////////////////////
    
 reg [SPIKE:0] spike_mem [DEPTH-1:0];   
 reg [clogb2(DEPTH-1)-1:0] ch_counter;   
 
 always @(posedge clk)
    if(rst)
        ch_counter <= 0;
    else if(en)
        ch_counter <= ch_counter + 1'b1;    
 
 ///////////////////////////////////////////////////////
 //             _ _                                   //
 //  ___ _ __ (_) | _____   _ __ ___   ___ _ __ ___   //
 // / __| '_ \| | |/ / _ \ | '_ ` _ \ / _ \ '_ ` _ \  //
 // \__ \ |_) | |   <  __/ | | | | | |  __/ | | | | | //
 // |___/ .__/|_|_|\_\___| |_| |_| |_|\___|_| |_| |_| //
 //     |_|                                           //
 //                                                   //
 ///////////////////////////////////////////////////////
 
 integer i;
 wire [clogb2(DEPTH-1)-1:0] spike_out_rd_addr;
 wire [4:0] spike_out_ag;
 reg [clogb2(FREQUENCY_RATIO-1)-1:0] step_counter;
  
 always @(posedge clk)
    if(rst)
        for(i=0;i<DEPTH;i=i+1)
            spike_mem[i] <= 0;
    else if(en)
            if(step_counter == 0)
                spike_mem[ch_counter] <= {spike_in,active_group_in};
            else
                spike_mem[ch_counter] <= {spike_in,active_group_in} | spike_out_ag;
 
 assign spike_out_ag = spike_mem[spike_out_rd_addr];
 assign active_group_out = spike_out_ag[0];
 assign spike_out = spike_out_ag[4:1];

 ///////////////////////////////////////////////////////////////
 //       _                                     _             //
 //   ___| |_ ___ _ __     ___ ___  _   _ _ __ | |_ ___ _ __  //
 //  / __| __/ _ \ '_ \   / __/ _ \| | | | '_ \| __/ _ \ '__| //
 //  \__ \ ||  __/ |_) | | (_| (_) | |_| | | | | ||  __/ |    //
 //  |___/\__\___| .__/   \___\___/ \__,_|_| |_|\__\___|_|    //
 //              |_|                                          //
 ///////////////////////////////////////////////////////////////
   
 always @(posedge clk)
    if(rst)
        step_counter <= 0;
    else if( (ch_counter == (DEPTH-1)) && en)
            if(step_counter < FREQUENCY_RATIO-1)
                step_counter <= step_counter + 1'b1;
            else
                step_counter <= 0;
 
 reg stream_out;   
 always @(posedge clk)
    if(rst)
           stream_out <= 0;
    else
        stream_out <= (step_counter == (FREQUENCY_RATIO-1)) && (ch_counter == (DEPTH-1)) && en;
 
 ///////////////////////////////////////////////////////////
 //      _                                          _     //
 //  ___| |_ _ __ ___  __ _ _ __ ___     ___  _   _| |_   //
 // / __| __| '__/ _ \/ _` | '_ ` _ \   / _ \| | | | __|  //
 // \__ \ |_| | |  __/ (_| | | | | | | | (_) | |_| | |_   //
 // |___/\__|_|  \___|\__,_|_| |_|_|_|  \___/ \__,_|\__|  //
 //          ___ ___  _   _ _ __ | |_ ___ _ __            //
 //         / __/ _ \| | | | '_ \| __/ _ \ '__|           //
 //        | (_| (_) | |_| | | | | ||  __/ |              //
 //         \___\___/ \__,_|_| |_|\__\___|_|              //
 //                                                       //
 ///////////////////////////////////////////////////////////     
 
  reg [clogb2(DEPTH-1)-1:0] stream_out_counter;   
 
  always @(posedge clk)
    if(rst)
        stream_out_counter <= 0;
    else if(stream_out || (stream_out_counter != 0) )
            stream_out_counter <= stream_out_counter + 1'b1;  
                                                
  assign valid = stream_out || stream_out_counter != 0;
  assign spike_out_rd_addr = valid? stream_out_counter:ch_counter; // is this right??
  
  
 //  The following function calculates the address width based on specified RAM depth
 function integer clogb2;
   input integer depth;
     for (clogb2=0; depth>0; clogb2=clogb2+1)
       depth = depth >> 1;
 endfunction 
    
endmodule
