`timescale 1ns / 1ps
`default_nettype none
module servant_tb;

   parameter memfile = "firmware/exe.hex";
   parameter memsize = 8192;
   parameter with_csr = 1;

   reg wb_clk = 1'b0;
   reg wb_rst = 1'b1;

   wire q;
   reg [2:0] buttons = 15;

   always  #31 wb_clk <= !wb_clk;
   initial #62 wb_rst <= 1'b0;

   //vlog_tb_utils vtu();

   uart_decoder #(57600) uart_decoder (q);

   servant_sim
     #(.memfile  (memfile),
       .memsize  (memsize),
       .with_csr (with_csr))
   servant_sim_i
     (.wb_clk (wb_clk),
      .wb_rst (wb_rst),
      .pc_adr (),
      .pc_vld (),
      .q      (q),
	  .buttons(buttons));


parameter OUTPUT_FILE_TARGET = {"sim/results/",`PATH,"/snn_inference.txt"};
parameter TARGET_FILE = {"sim/target/",`PATH,"/snn_inference.txt"};
parameter TARGET_FILE_BINNING= {"sim/target/",`PATH,"/encoded_input.txt"};
parameter OUTPUT_FILE_BINNING = {"sim/results/",`PATH,"/encoded_input.txt"};

parameter MAX_ERRORS = 1000;

integer i,j,k;
integer f_in, f_out_spikes,f_t;
integer f_t_bin, f_out_bin;
integer f_out_target, f_out;
integer f_out_snn_L1, f_t_L1;
integer f_out_snn_L2, f_t_L2;
integer f_out_snn_L3, f_t_L3;

initial begin
 
	`ifndef PSIM   
		$dumpfile("tb_serv.vcd");  
	`else
		$dumpfile("ps_tb_serv.vcd");  
	`endif 

	$dumpvars(10,servant_tb); 

    f_out_target =  $fopen(TARGET_FILE,"r");
    f_out =         $fopen(OUTPUT_FILE_TARGET,"w");
    
	f_t_bin =       $fopen(TARGET_FILE_BINNING,"r");
	f_out_bin =     $fopen(OUTPUT_FILE_BINNING,"w");

    //wait(dut.control_i.state == 11);
	#20000
	buttons = 0;
	#70000000; 

	//$fclose(f_out_spikes);
    $fclose(f_out);
	$fclose(f_out_target);
	$fclose(f_out_bin);	
	$fclose(f_t_bin);	

    $finish;

end

`ifndef PSIM

	/*
	  ___        __                              
	 |_ _|_ __  / _| ___ _ __ ___ _ __   ___ ___ 
	  | || '_ \| |_ / _ \ '__/ _ \ '_ \ / __/ _ \
	  | || | | |  _|  __/ | |  __/ | | | (_|  __/
	 |___|_| |_|_|  \___|_|  \___|_| |_|\___\___|
		                                         
	*/

	reg signed [25:0] prediction_snn;
	reg signed [25:0] target_prediction_snn;
	integer ll = 0;
	integer errors_snn_inference = 0; integer n;
	integer dummy;

	wire signed [15:0] p1;
	wire signed [15:0] p2;
	wire valid_snn;

	assign valid_snn = servant_sim_i.service_i.mosquito.snn_lp_i.output_buffer_wr_en;
	assign p1 =  servant_sim_i.service_i.mosquito.snn_lp_i.output_buffer_din[15:0];
	assign p2 = servant_sim_i.service_i.mosquito.snn_lp_i.output_buffer_din[31:16];

	wire [31:0] N4;
	assign N4 = servant_sim_i.service_i.NEURON_4/2;
	reg [31:0] wr_cnt;	
	initial wr_cnt = 0; 

	always @(posedge wb_clk) begin
		if (valid_snn) begin
			ll <= ll + 1;			
			if(ll == wr_cnt) begin	
				wr_cnt <= wr_cnt + N4; 				
				$fwrite(f_out,"[%d,%d],\n", $signed(p1),$signed(p2));
		
				$display("Inference #%d: [%d, %d]",ll/N4,$signed(p1),$signed(p2));

				prediction_snn = p1;
				dummy = $fscanf(f_out_target, "%d,\n", target_prediction_snn);

					if(target_prediction_snn != prediction_snn) begin
						errors_snn_inference = errors_snn_inference + 1;
						$display("#SNN inference error detected @%d\n",ll+1);
						$display("target_inference = %d, inference = %d\n",target_prediction_snn,prediction_snn);
						if(errors_snn_inference > MAX_ERRORS) begin
						    $display("Exiting from L4 error checks\n");
						    $fclose(f_out_target);
						    $fclose(f_out);
							$fclose(f_out_bin);	
							$fclose(f_t_bin);	
						    #0.2
						    $finish;
						    
						end
					end
				
			end
		end
	end

	/*
		                       _ _             
	   ___ _ __   ___ ___   __| (_)_ __   __ _ 
	  / _ \ '_ \ / __/ _ \ / _` | | '_ \ / _` |
	 |  __/ | | | (_| (_) | (_| | | | | | (_| |
	  \___|_| |_|\___\___/ \__,_|_|_| |_|\__, |
		                                 |___/ 
	*/

	reg [3:0] target_bins;
	integer jj = 0;
	integer error_bin = 0;
	wire [3:0] bin;
	assign bin = servant_sim_i.service_i.mosquito.spike_bin;
	wire valid_bin;
	assign valid_bin = servant_sim_i.service_i.mosquito.valid_bin;

	always @(valid_bin) begin
		if(valid_bin) begin
			jj = jj + 1;
			$fwrite(f_out_bin,"%b ", bin);
			if(((jj%8) == 0) && (jj != 0))
				$fwrite(f_out_bin,"\n");
			dummy = $fscanf(f_t_bin, "%b ", target_bins);
			for(k=0;k<4;k=k+1) begin
				if(bin[k] != target_bins[k]) begin
					error_bin = error_bin + 1;
				    $display("#Error detected @(%d,%d)[jj=%d,k=%d]\n",jj/32+1,4*(jj%32)-k,jj,k);
				    $display("target_bins = %d, bin = %d\n",target_bins,bin);
				end
			end 
		end
	end

`endif

endmodule
