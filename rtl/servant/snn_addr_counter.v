`default_nettype none
module snn_addr_counter
#(
    parameter DEPTH = 8192
)
(
    input  wire clk,
    input  wire rst,
    input  wire clr,
    input  wire inc,
    output reg  [clogb2(DEPTH)-1:0] addr
);

    always @(posedge clk) begin
        if (rst | clr) begin
            addr <= 0;
        end
        else if (inc) begin
                addr <= addr + 1;
        end
    end

    function integer clogb2;
        input integer depth;
        for (clogb2=0; depth>0; clogb2=clogb2+1)
            depth = depth >> 1;
    endfunction   

endmodule