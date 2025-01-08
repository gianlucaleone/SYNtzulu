`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03.11.2022 14:26:36
// Design Name: 
// Module Name: integrator
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


module integrator_and_fifo #(parameter DEPTH = 256, parameter WIDTH = 25)
    (
    input clk, rst, en, detection,
    input [13:0] decay,
    input [WIDTH-1:0] stimolo,
    input [WIDTH-1:0] threshold,
    
    output valid,
    output spike,
    output [WIDTH-1:0] output_new
	`ifdef CONFIGURABILITY
		,input clear_counter
	`endif
    );
    
    wire [WIDTH-1:0] output_old;
    
    // FIFO
    bram_fifo #( .DATA_WIDTH(WIDTH), .DEPTH(DEPTH) ) fifo_i (.clk(clk),.rst(rst),.DI(output_new),.rden(en),.wren(valid),.DO(output_old) `ifdef CONFIGURABILITY , .clear_counter(clear_counter) `endif); 
    // wait fifo output
    reg en_d;
    reg [WIDTH-1:0] stimolo_d;
    always @(posedge clk)
        if (rst) begin
            en_d <= 0;
            stimolo_d <= 0;
         end
        else begin 
            en_d <= en;
            if(en)
                stimolo_d <= stimolo;
        end
    // INTEGRATOR
    integrator #(.WIDTH(WIDTH)) integrator_i (clk, rst, en_d, detection,output_old,decay,stimolo_d,threshold,valid,spike,output_new);
    

    endmodule
