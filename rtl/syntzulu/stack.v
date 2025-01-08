`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03.11.2022 11:06:53
// Design Name: 
// Module Name: stack
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


module stack
#(
parameter DATA_WIDTH = 4,
parameter DEPTH = 24
)
(
input clk, rst,
input [DATA_WIDTH-1:0] din,
input wr_en, clear,
input stream_out,

output [DATA_WIDTH-1:0] dout,
output reg done,
output [clogb2(DEPTH-1)-1:0] active_entries,
output empty 
);

// shift register    
reg [DATA_WIDTH-1:0] shift [DEPTH-1:0];
integer i;
always@(posedge clk)
    if (rst)
       for(i=0;i<DEPTH;i=i+1)
            shift[i] <= 0;
    else    
        if(wr_en) begin
            shift[0] <= din;
            for(i=1;i<DEPTH;i=i+1)
                shift[i] <= shift[i-1];
        end
            
// entries counter
reg [clogb2(DEPTH-1):0] entries_cnt;    
always @(posedge clk)
    if(rst)
       entries_cnt <= 0;
    else
        if(wr_en)
            entries_cnt <= entries_cnt + 1'b1;     
        else if (clear)
            entries_cnt <= 0;

// stream counter
reg [clogb2(DEPTH-1)-1:0] stream_cnt;    
always @(posedge clk)
    if(rst)
       stream_cnt <= 0;
    else
        if(stream_out && (entries_cnt != 0) )
            stream_cnt <= entries_cnt - 1'b1;
        else if (stream_cnt != 0) 
            stream_cnt <= stream_cnt - 1'b1;

// output assignment 
assign dout = shift[stream_cnt];

always @(posedge clk)
    if (rst) 
        done = 0;
    else if (stream_cnt == 1 || ( stream_out && ( (entries_cnt == 1) || (entries_cnt == 0) ) ) )
            done <= 1;
         else
            done <= 0;

assign active_entries = entries_cnt == 0 ? 0 : entries_cnt - 1'b1;            
 
assign empty = entries_cnt == 0;
           
//  The following function calculates the address width based on specified RAM depth
function integer clogb2;
  input integer depth;
    for (clogb2=0; depth>0; clogb2=clogb2+1)
      depth = depth >> 1;
endfunction 
   
endmodule
