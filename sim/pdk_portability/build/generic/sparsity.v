`default_nettype none
module holo_sparsity_24 (
	clk,
	rst_n,
	valid_in,
	mask_in,
	payload_in,
	valid_out,
	mask_err,
	dense_out
);
	reg _sv2v_0;
	input wire clk;
	input wire rst_n;
	input wire valid_in;
	input wire [3:0] mask_in;
	input wire [3:0] payload_in;
	output reg valid_out;
	output reg mask_err;
	output reg [7:0] dense_out;
	function automatic [2:0] popcount4;
		input [3:0] m;
		reg [1:0] lo;
		reg [1:0] hi;
		reg [2:0] pc;
		begin
			lo = {1'b0, m[0]} + {1'b0, m[1]};
			hi = {1'b0, m[2]} + {1'b0, m[3]};
			pc = {1'b0, lo} + {1'b0, hi};
			popcount4 = pc;
		end
	endfunction
	reg mask_valid;
	always @(*) begin
		if (_sv2v_0)
			;
		mask_valid = popcount4(mask_in) == 3'd2;
	end
	reg [1:0] nz_pos0;
	reg [1:0] nz_pos1;
	always @(*) begin
		if (_sv2v_0)
			;
		nz_pos0 = 2'd0;
		nz_pos1 = 2'd1;
		if (mask_valid) begin
			if (mask_in[0])
				nz_pos0 = 2'd0;
			else if (mask_in[1])
				nz_pos0 = 2'd1;
			else if (mask_in[2])
				nz_pos0 = 2'd2;
			else
				nz_pos0 = 2'd3;
			case (mask_in)
				4'b0011: begin
					nz_pos0 = 2'd0;
					nz_pos1 = 2'd1;
				end
				4'b0101: begin
					nz_pos0 = 2'd0;
					nz_pos1 = 2'd2;
				end
				4'b0110: begin
					nz_pos0 = 2'd1;
					nz_pos1 = 2'd2;
				end
				4'b1001: begin
					nz_pos0 = 2'd0;
					nz_pos1 = 2'd3;
				end
				4'b1010: begin
					nz_pos0 = 2'd1;
					nz_pos1 = 2'd3;
				end
				4'b1100: begin
					nz_pos0 = 2'd2;
					nz_pos1 = 2'd3;
				end
				default: begin
					nz_pos0 = 2'd0;
					nz_pos1 = 2'd1;
				end
			endcase
		end
	end
	reg [1:0] nz_val0;
	reg [1:0] nz_val1;
	always @(*) begin
		if (_sv2v_0)
			;
		nz_val0 = payload_in[1:0];
		nz_val1 = payload_in[3:2];
	end
	reg [1:0] dense_comb [0:3];
	always @(*) begin : sv2v_autoblock_1
		integer idx;
		if (_sv2v_0)
			;
		for (idx = 0; idx < 4; idx = idx + 1)
			if (mask_valid) begin
				if (nz_pos0 == idx[1:0])
					dense_comb[idx] = nz_val0;
				else if (nz_pos1 == idx[1:0])
					dense_comb[idx] = nz_val1;
				else
					dense_comb[idx] = 2'b00;
			end
			else
				dense_comb[idx] = 2'b00;
	end
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			valid_out <= 1'b0;
			mask_err <= 1'b0;
			dense_out <= 8'h00;
		end
		else begin
			valid_out <= valid_in;
			mask_err <= valid_in & ~mask_valid;
			if (valid_in)
				dense_out <= {dense_comb[3], dense_comb[2], dense_comb[1], dense_comb[0]};
			else
				dense_out <= 8'h00;
		end
	initial _sv2v_0 = 0;
endmodule
`default_nettype wire
