module fsm_uart_tx #( parameter N = 10) (
	
	input  rst,clk,
	input  i_start, i_continue,
	output [clogb2(N-1)-1:0] o_sel,
	output o_valid
);

reg [clogb2(N-1):0] cnt;

always @(posedge clk)
	if (rst) begin
		cnt <= 0;
	end
	else if (cnt == N) begin
			cnt <= 0;
	end
	else if (cnt != 0 && i_continue) begin
		cnt <= cnt + 1'b1;
	end
	else if (cnt == 0 && i_start) begin
		cnt <= 1;
	end

reg continue_r;
always @(posedge clk)
	if (rst)
		continue_r <= 0;
	else if (cnt != 0)
			continue_r <= i_continue;

assign o_sel = cnt;
assign o_valid = (i_start && i_continue) || (i_continue && cnt != 0);

//////////////////////////////////////////////////
//   __                  _   _                  //
//  / _|_   _ _ __   ___| |_(_) ___  _ __  ___  //
// | |_| | | | '_ \ / __| __| |/ _ \| '_ \/ __| //
// |  _| |_| | | | | (__| |_| | (_) | | | \__ \ //
// |_|  \__,_|_| |_|\___|\__|_|\___/|_| |_|___/ //
//                                              //
//////////////////////////////////////////////////

function integer clogb2;
  input integer depth;
    for (clogb2=0; depth>0; clogb2=clogb2+1)
      depth = depth >> 1;
endfunction   

endmodule
