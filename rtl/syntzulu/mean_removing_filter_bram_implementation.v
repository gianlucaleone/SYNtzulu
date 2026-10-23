`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 17.07.2023 10:00:39
// Design Name: 
// Module Name: mean_removing_filter_bram_implementation
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


module mean_removing_filter_bram_implementation #(
    parameter CHANNELS = 128, 
    parameter ORDER = 2, 
    parameter DW = 15)
    (
    input clk, 
    input rst, 
    input en, 
    input signed [DW-1:0] data_in,
    output signed [DW-1:0] enhanced_data,
    output reg valid
);
    
    localparam ORDER_L2 = $clog2(ORDER);
    
    reg signed [DW-1:0] data_in_pipe [ORDER-1:0];
    reg en_p[1:0];
    
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
    
    wire signed [DW-1:0] data_1, data_2; // old samples
    

    BRAM_singlePort_readFirst
    #(
      .RAM_WIDTH(2*DW),         // Specify RAM data width
      .RAM_DEPTH(CHANNELS),             // Specify RAM depth (number of entries)
      .RAM_PERFORMANCE("LOW_LATENCY"),  // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
	  .INIT_FILE("sim/mem/ieeg/filter.txt")      
	)
    sample_mem
     (
      .addra(r_channel_cnt),           // Port A address bus, driven by axi bus
      .addrb(channel_cnt),             // Port B address bus, it goes in the accumulator
      .dina({data_2, data_in_pipe[0]}),             // Port A RAM input data, driven by axi bus
      .clk(clk),                       // Clock
      .wea(en_p[0]),                     // Port A write enable
      .ena(en_p[0]),                     // Port A RAM Enable, for additional power savings, disable port when not in use
      .enb(en),                      // Port B RAM Enable, for additional power savings, disable port when not in use
      .rst(rst),                       // Port A and B output reset (does not affect memory contents)
      .regceb(1'b1),                   // Port B output register enable
      
      .doutb({data_1, data_2})                // Port B RAM output data
    );   
    
    integer i;
    always @(posedge clk) begin
        if(rst) begin
            for(i=0;i<ORDER;i=i+1) 
                data_in_pipe[i] <= 0;           
            en_p[0] <= 0;
            en_p[1] <= 0;
            valid <= 0;
          end
        else begin
            en_p[0] <= en;
            en_p[1] <= en_p[0];
            valid <= en_p[1];
            if(en) begin
                data_in_pipe[0] <= data_in;
                for(i=1;i<ORDER;i=i+1)               
                    data_in_pipe[i] <= data_in_pipe[i-1];                
            end
        end
    end
    
    //(* use_dsp = "yes" *)
    wire signed [DW + ORDER_L2 - 1:0] adder_tree_out; 
    reg signed [DW - 1:0] mean_value;
 
    //assign adder_tree_out = data_in_pipe[CHANNELS*8-1] + data_in_pipe[CHANNELS*7-1] + data_in_pipe[CHANNELS*6-1] + + data_in_pipe[CHANNELS*5-1] + 
    //                        data_in_pipe[CHANNELS*4-1] + data_in_pipe[CHANNELS*3-1] + data_in_pipe[CHANNELS*2-1] + data_in_pipe[CHANNELS*1-1];
    
    assign adder_tree_out = data_1 + data_2;
    
    reg signed [DW-1:0] filtered_data;
    reg signed [DW-1:0] target_sample;
    reg signed [DW + ORDER_L2 - 1:0] supporto_1;
    reg signed [DW - 1:0] supporto_2;
    always @(posedge clk)
        if (rst)
            mean_value <= 0;
        else begin
            if(en_p[0]) begin
                if(adder_tree_out[DW + ORDER_L2-1]) begin
                    supporto_1 = ~adder_tree_out+1'b1;            
                    supporto_2 = supporto_1[DW + ORDER_L2-1:ORDER_L2];
                    mean_value <= ~supporto_2+1'b1;
                 end
                 else
                    mean_value <= adder_tree_out[DW + ORDER_L2-1:ORDER_L2]; // right shift of ORDER_L2 positions
                target_sample <= data_in_pipe[0];
            end
            if(en_p[1])
                filtered_data <= target_sample - mean_value;
        end 
    
    
    //assign mean_value = adder_tree_out[DW + ORDER_L2-1:ORDER_L2]; // right shift of ORDER_L2 positions
    //assign filtered_data = data_in - mean_value; // mean value subtraction
    assign enhanced_data = filtered_data[DW-1]?-filtered_data:filtered_data; // absolute value
    
    //  The following function calculates the address width based on specified RAM depth
    function integer clogb2;
      input integer depth;
        for (clogb2=0; depth>0; clogb2=clogb2+1)
          depth = depth >> 1;
    endfunction 

endmodule
