`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03.11.2022 10:58:43
// Design Name: 
// Module Name: fifo
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


module fifo
#(
parameter DATA_WIDTH = 25, DEPTH = 256
)
(
input clk, rst,
input [DATA_WIDTH-1:0] DI,
input rden, wren,
output [DATA_WIDTH-1:0] DO
    );

reg [DATA_WIDTH-1:0] fifo [DEPTH-1:0];

integer i;
always @(posedge clk)
    if(rst) 
        for(i=0;i<DEPTH;i=i+1)
            fifo[i] = 0;
    else  
        if(wren) begin
            fifo[wr_pointer] <= DI;
           end

reg [clogb2(DEPTH-1)-1:0] rd_pointer;
always @(posedge clk)
    if(rst) 
		rd_pointer <= 0;
	else if(rden)
			if(rd_pointer<DEPTH-1)		
				rd_pointer <= rd_pointer + 1'b1;
			else
				rd_pointer <= 0;

reg [clogb2(DEPTH-1)-1:0] wr_pointer;
always @(posedge clk)
    if(rst) 
		wr_pointer <= 0;
	else if(wren)
			if(wr_pointer<DEPTH-1)
				wr_pointer <= wr_pointer + 1'b1;
			else
				wr_pointer <= 0;

assign DO = fifo[rd_pointer];

	//  The following function calculates the address width based on specified RAM depth
	function integer clogb2;
	  input integer depth;
		for (clogb2=0; depth>0; clogb2=clogb2+1)
		  depth = depth >> 1;
	endfunction 

endmodule
