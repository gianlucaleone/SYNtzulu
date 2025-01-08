module SB_SPRAM256KA (
	input [13:0] ADDRESS,
	input [15:0] DATAIN,
	input [3:0] MASKWREN,
	input WREN, CHIPSELECT, CLOCK, STANDBY, SLEEP, POWEROFF,
	output reg [15:0] DATAOUT
);
	reg [15:0] mem [0:16383];
	wire off = SLEEP || !POWEROFF;
	integer i;

	always @(negedge POWEROFF) begin
		for (i = 0; i <= 16383; i = i+1)
			mem[i] = 16'bx;
	end

	always @(posedge CLOCK, posedge off) begin
		if (off) begin
			DATAOUT <= 0;
		end else
		if (STANDBY) begin
			DATAOUT <= 16'bx;
		end else
		if (CHIPSELECT) begin
			if (!WREN) begin
				DATAOUT <= mem[ADDRESS];
			end else begin
				if (MASKWREN[0]) mem[ADDRESS][ 3: 0] <= DATAIN[ 3: 0];
				if (MASKWREN[1]) mem[ADDRESS][ 7: 4] <= DATAIN[ 7: 4];
				if (MASKWREN[2]) mem[ADDRESS][11: 8] <= DATAIN[11: 8];
				if (MASKWREN[3]) mem[ADDRESS][15:12] <= DATAIN[15:12];
				DATAOUT <= 16'bx;
			end
		end
	end

	specify
		// https://github.com/YosysHQ/icestorm/blob/95949315364f8d9b0c693386aefadf44b28e2cf6/icefuzz/timings_up5k.txt#L13169-L13182
		$setup(posedge ADDRESS, posedge CLOCK, 268);
		// https://github.com/YosysHQ/icestorm/blob/95949315364f8d9b0c693386aefadf44b28e2cf6/icefuzz/timings_up5k.txt#L13183
		$setup(CHIPSELECT, posedge CLOCK, 404);
		// https://github.com/YosysHQ/icestorm/blob/95949315364f8d9b0c693386aefadf44b28e2cf6/icefuzz/timings_up5k.txt#L13184-L13199
		$setup(DATAIN, posedge CLOCK, 143);
		// https://github.com/YosysHQ/icestorm/blob/95949315364f8d9b0c693386aefadf44b28e2cf6/icefuzz/timings_up5k.txt#L13200-L13203
		$setup(MASKWREN, posedge CLOCK, 143);
		// https://github.com/YosysHQ/icestorm/blob/95949315364f8d9b0c693386aefadf44b28e2cf6/icefuzz/timings_up5k.txt#L13167
		//$setup(negedge SLEEP, posedge CLOCK, 41505);
		// https://github.com/YosysHQ/icestorm/blob/95949315364f8d9b0c693386aefadf44b28e2cf6/icefuzz/timings_up5k.txt#L13167
		//$setup(negedge STANDBY, posedge CLOCK, 1715);
		// https://github.com/YosysHQ/icestorm/blob/95949315364f8d9b0c693386aefadf44b28e2cf6/icefuzz/timings_up5k.txt#L13206
		$setup(WREN, posedge CLOCK, 289);
		// https://github.com/YosysHQ/icestorm/blob/95949315364f8d9b0c693386aefadf44b28e2cf6/icefuzz/timings_up5k.txt#L13207-L13222
		(posedge CLOCK *> (DATAOUT : 16'bx)) = 1821;
		// https://github.com/YosysHQ/icestorm/blob/95949315364f8d9b0c693386aefadf44b28e2cf6/icefuzz/timings_up5k.txt#L13223-L13238
		(posedge SLEEP *> (DATAOUT : 16'b0)) = 1099;
	endspecify

endmodule

