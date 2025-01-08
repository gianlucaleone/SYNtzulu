`default_nettype none

module spi_acc_control #(parameter DOUBLE_CLOCK = 0) (
    input  wire wb_clk,
    input  wire wb_rst,

    input  wire i_if_start,
    output wire o_if_load1,
    output wire o_if_load2,
    output wire o_if_snn_we,
    output wire o_if_set0,
    output wire o_if_clr,

    input  wire i_spi_valid,
    input  wire i_spi_end,
    output wire o_spi_en,
    output wire o_spi_read_ack
    );

    reg [4:0] out;
    reg     if_load1_ff,    if_load2_ff,    if_snn_we_ff,   if_set0_ff, if_clr_ff;
    wire    if_load1,       if_load2,       if_snn_we,      if_set0,    if_clr;

    assign {o_spi_en, if_load1, if_load2, if_snn_we, if_set0} = out;
    assign if_clr = o_spi_en;
    assign o_spi_read_ack = if_snn_we;

    assign o_if_load1   = DOUBLE_CLOCK? (if_load1  | if_load1_ff)  : if_load1;
    assign o_if_load2   = DOUBLE_CLOCK? (if_load2  | if_load2_ff)  : if_load2;
    assign o_if_snn_we  = DOUBLE_CLOCK? (if_snn_we | if_snn_we_ff) : if_snn_we;
    assign o_if_set0    = DOUBLE_CLOCK? (if_set0   | if_set0_ff)   : if_set0;
    assign o_if_clr     = DOUBLE_CLOCK? (if_clr    | if_clr_ff)    : if_clr;
    
    parameter [2:0]
        IDLE = 0,
        ENABLE = 1,
        WAIT_DATA1 = 2,
        WAIT_DATA2 = 3,
        WRITE_DATA = 4,
        END_SET0 = 5,
        DUMMY = 6;
    
    reg [2:0] state, state_next;

    // state transition
    always @(posedge wb_clk) begin
        if (wb_rst) begin
            state <= IDLE;
            if_load1_ff <= 0;
            if_load2_ff <= 0;
            if_snn_we_ff <= 0;
            if_set0_ff <= 0;
            if_clr_ff <= 0;
        end
        else begin
            state <= state_next;
            if_load1_ff     <= if_load1;
            if_load2_ff     <= if_load2;
            if_snn_we_ff    <= if_snn_we;
            if_set0_ff      <= if_set0;
            if_clr_ff       <= if_clr;
        end
    end

    // next state and output logic
    always @(*) begin
        case (state)
            IDLE: begin
                out = 5'b0xx00;
                if (i_if_start) begin
                    state_next = ENABLE;
                end
                else begin
                    state_next = IDLE;
                end
            end
            ENABLE: begin
                out = 5'b1xx00;
                state_next = WAIT_DATA1;
            end
            WAIT_DATA1: begin
                out = 5'b01x00;
                if (i_spi_valid) begin
					state_next = WAIT_DATA2;                
				end
                else begin
                    state_next = WAIT_DATA1;
                end
            end
            WAIT_DATA2: begin
                out = 5'b00100;
                if (i_spi_valid) begin
                    state_next = DUMMY;
                end
                else begin
                    state_next = WAIT_DATA2;
                end
            end
            DUMMY: begin
                out = 5'b00000;
                state_next = WRITE_DATA;
            end
            WRITE_DATA: begin
                out = 5'b00010;
                if (i_spi_end) begin
                    state_next = END_SET0;
                end
                else begin
                    state_next = WAIT_DATA1;
                end
            end
            END_SET0: begin
                out = 5'b0xx01;
                state_next = IDLE;  
            end
            default: begin
                out = 5'b0xx0x;
                state_next = IDLE;
            end
        endcase
    end

endmodule
