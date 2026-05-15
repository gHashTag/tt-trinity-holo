module holo_mesh_router (
	clk,
	rst_n,
	flit_in,
	vld_in,
	flit_out,
	vld_out
);
	reg _sv2v_0;
	parameter signed [31:0] FLIT_W = 32;
	parameter signed [31:0] CUR_X = 0;
	parameter signed [31:0] CUR_Y = 0;
	input wire clk;
	input wire rst_n;
	input wire [(5 * FLIT_W) - 1:0] flit_in;
	input wire [0:4] vld_in;
	output wire [(5 * FLIT_W) - 1:0] flit_out;
	output wire [0:4] vld_out;
	localparam signed [31:0] PORT_N = 0;
	localparam signed [31:0] PORT_S = 1;
	localparam signed [31:0] PORT_E = 2;
	localparam signed [31:0] PORT_W = 3;
	localparam signed [31:0] PORT_L = 4;
	reg [(5 * FLIT_W) - 1:0] flit_out_r;
	reg [0:4] vld_out_r;
	reg [2:0] route_port [0:4];
	reg [FLIT_W - 1:0] arb_flit [0:4];
	reg arb_vld [0:4];
	function automatic signed [2:0] sv2v_cast_3_signed;
		input reg signed [2:0] inp;
		sv2v_cast_3_signed = inp;
	endfunction
	function automatic signed [1:0] sv2v_cast_2_signed;
		input reg signed [1:0] inp;
		sv2v_cast_2_signed = inp;
	endfunction
	always @(*) begin
		if (_sv2v_0)
			;
		begin : sv2v_autoblock_1
			reg signed [31:0] p;
			for (p = 0; p < 5; p = p + 1)
				begin : sv2v_autoblock_2
					reg [1:0] dst_x;
					reg [1:0] dst_y;
					dst_x = flit_in[((4 - p) * FLIT_W) + 3-:2];
					dst_y = flit_in[((4 - p) * FLIT_W) + 1-:2];
					if (!vld_in[p])
						route_port[p] = sv2v_cast_3_signed(PORT_L);
					else if (dst_x > sv2v_cast_2_signed(CUR_X))
						route_port[p] = sv2v_cast_3_signed(PORT_E);
					else if (dst_x < sv2v_cast_2_signed(CUR_X))
						route_port[p] = sv2v_cast_3_signed(PORT_W);
					else if (dst_y > sv2v_cast_2_signed(CUR_Y))
						route_port[p] = sv2v_cast_3_signed(PORT_S);
					else if (dst_y < sv2v_cast_2_signed(CUR_Y))
						route_port[p] = sv2v_cast_3_signed(PORT_N);
					else
						route_port[p] = sv2v_cast_3_signed(PORT_L);
				end
		end
	end
	always @(*) begin
		if (_sv2v_0)
			;
		begin : sv2v_autoblock_3
			reg signed [31:0] o;
			for (o = 0; o < 5; o = o + 1)
				begin
					arb_flit[o] = 1'sb0;
					arb_vld[o] = 1'b0;
					begin : sv2v_autoblock_4
						reg signed [31:0] p;
						for (p = 4; p >= 0; p = p - 1)
							if (vld_in[p] && (route_port[p] == sv2v_cast_3_signed(o))) begin
								arb_flit[o] = flit_in[(4 - p) * FLIT_W+:FLIT_W];
								arb_vld[o] = 1'b1;
							end
					end
				end
		end
	end
	always @(posedge clk)
		if (!rst_n) begin : sv2v_autoblock_5
			reg signed [31:0] o;
			for (o = 0; o < 5; o = o + 1)
				begin
					flit_out_r[(4 - o) * FLIT_W+:FLIT_W] <= 1'sb0;
					vld_out_r[o] <= 1'b0;
				end
		end
		else begin : sv2v_autoblock_6
			reg signed [31:0] o;
			for (o = 0; o < 5; o = o + 1)
				begin
					flit_out_r[(4 - o) * FLIT_W+:FLIT_W] <= arb_flit[o];
					vld_out_r[o] <= arb_vld[o];
				end
		end
	assign flit_out = flit_out_r;
	assign vld_out = vld_out_r;
	initial _sv2v_0 = 0;
endmodule
module holo_noc_1cycle (
	clk,
	rst_n,
	flit_in,
	vld_in,
	flit_out,
	vld_out,
	latency_cycles
);
	parameter signed [31:0] FLIT_W = 32;
	parameter signed [31:0] DIES = 2;
	input wire clk;
	input wire rst_n;
	input wire [(DIES * FLIT_W) - 1:0] flit_in;
	input wire [0:DIES - 1] vld_in;
	output reg [(DIES * FLIT_W) - 1:0] flit_out;
	output reg [0:DIES - 1] vld_out;
	output wire [$clog2(DIES + 1) - 1:0] latency_cycles;
	function automatic signed [$clog2(DIES + 1) - 1:0] sv2v_cast_F3FF4_signed;
		input reg signed [$clog2(DIES + 1) - 1:0] inp;
		sv2v_cast_F3FF4_signed = inp;
	endfunction
	assign latency_cycles = sv2v_cast_F3FF4_signed(1);
	always @(posedge clk)
		if (!rst_n) begin : sv2v_autoblock_1
			reg signed [31:0] i;
			for (i = 0; i < DIES; i = i + 1)
				begin
					flit_out[((DIES - 1) - i) * FLIT_W+:FLIT_W] <= 1'sb0;
					vld_out[i] <= 1'b0;
				end
		end
		else begin : sv2v_autoblock_2
			reg signed [31:0] i;
			for (i = 0; i < DIES; i = i + 1)
				begin
					flit_out[((DIES - 1) - i) * FLIT_W+:FLIT_W] <= flit_in[((DIES - 1) - ((DIES - 1) - i)) * FLIT_W+:FLIT_W];
					vld_out[i] <= vld_in[(DIES - 1) - i];
				end
		end
endmodule
module holo_mesh_2x2 (
	clk,
	rst_n,
	inj_flit,
	inj_vld,
	ej_flit,
	ej_vld,
	noc_latency
);
	reg _sv2v_0;
	parameter signed [31:0] FLIT_W = 32;
	input wire clk;
	input wire rst_n;
	input wire [(4 * FLIT_W) - 1:0] inj_flit;
	input wire [0:3] inj_vld;
	output reg [(4 * FLIT_W) - 1:0] ej_flit;
	output reg [0:3] ej_vld;
	output wire [3:0] noc_latency;
	wire [(5 * FLIT_W) - 1:0] r_flit_out [0:3];
	wire [0:4] r_vld_out [0:3];
	reg [(5 * FLIT_W) - 1:0] r_flit_in [0:3];
	reg [0:4] r_vld_in [0:3];
	localparam signed [31:0] PORT_N = 0;
	localparam signed [31:0] PORT_S = 1;
	localparam signed [31:0] PORT_E = 2;
	localparam signed [31:0] PORT_W = 3;
	localparam signed [31:0] PORT_L = 4;
	always @(*) begin
		if (_sv2v_0)
			;
		begin : sv2v_autoblock_1
			reg signed [31:0] n;
			for (n = 0; n < 4; n = n + 1)
				begin : sv2v_autoblock_2
					reg signed [31:0] p;
					for (p = 0; p < 5; p = p + 1)
						begin
							r_flit_in[n][(4 - p) * FLIT_W+:FLIT_W] = 1'sb0;
							r_vld_in[n][p] = 1'b0;
						end
				end
		end
		r_flit_in[1][1 * FLIT_W+:FLIT_W] = r_flit_out[0][2 * FLIT_W+:FLIT_W];
		r_vld_in[1][PORT_W] = r_vld_out[0][PORT_E];
		r_flit_in[0][2 * FLIT_W+:FLIT_W] = r_flit_out[1][1 * FLIT_W+:FLIT_W];
		r_vld_in[0][PORT_E] = r_vld_out[1][PORT_W];
		r_flit_in[3][1 * FLIT_W+:FLIT_W] = r_flit_out[2][2 * FLIT_W+:FLIT_W];
		r_vld_in[3][PORT_W] = r_vld_out[2][PORT_E];
		r_flit_in[2][2 * FLIT_W+:FLIT_W] = r_flit_out[3][1 * FLIT_W+:FLIT_W];
		r_vld_in[2][PORT_E] = r_vld_out[3][PORT_W];
		r_flit_in[2][4 * FLIT_W+:FLIT_W] = r_flit_out[0][3 * FLIT_W+:FLIT_W];
		r_vld_in[2][PORT_N] = r_vld_out[0][PORT_S];
		r_flit_in[0][3 * FLIT_W+:FLIT_W] = r_flit_out[2][4 * FLIT_W+:FLIT_W];
		r_vld_in[0][PORT_S] = r_vld_out[2][PORT_N];
		r_flit_in[3][4 * FLIT_W+:FLIT_W] = r_flit_out[1][3 * FLIT_W+:FLIT_W];
		r_vld_in[3][PORT_N] = r_vld_out[1][PORT_S];
		r_flit_in[1][3 * FLIT_W+:FLIT_W] = r_flit_out[3][4 * FLIT_W+:FLIT_W];
		r_vld_in[1][PORT_S] = r_vld_out[3][PORT_N];
		r_flit_in[0][0+:FLIT_W] = inj_flit[3 * FLIT_W+:FLIT_W];
		r_vld_in[0][PORT_L] = inj_vld[0];
		r_flit_in[1][0+:FLIT_W] = inj_flit[2 * FLIT_W+:FLIT_W];
		r_vld_in[1][PORT_L] = inj_vld[1];
		r_flit_in[2][0+:FLIT_W] = inj_flit[FLIT_W+:FLIT_W];
		r_vld_in[2][PORT_L] = inj_vld[2];
		r_flit_in[3][0+:FLIT_W] = inj_flit[0+:FLIT_W];
		r_vld_in[3][PORT_L] = inj_vld[3];
		ej_flit[3 * FLIT_W+:FLIT_W] = r_flit_out[0][0+:FLIT_W];
		ej_vld[0] = r_vld_out[0][PORT_L];
		ej_flit[2 * FLIT_W+:FLIT_W] = r_flit_out[1][0+:FLIT_W];
		ej_vld[1] = r_vld_out[1][PORT_L];
		ej_flit[FLIT_W+:FLIT_W] = r_flit_out[2][0+:FLIT_W];
		ej_vld[2] = r_vld_out[2][PORT_L];
		ej_flit[0+:FLIT_W] = r_flit_out[3][0+:FLIT_W];
		ej_vld[3] = r_vld_out[3][PORT_L];
	end
	holo_noc_1cycle #(
		.FLIT_W(FLIT_W),
		.DIES(2)
	) u_noc0(
		.clk(clk),
		.rst_n(rst_n),
		.flit_in({r_flit_in[0][0+:FLIT_W], inj_flit[3 * FLIT_W+:FLIT_W]}),
		.vld_in({r_vld_in[0][PORT_L], inj_vld[0]}),
		.flit_out(),
		.vld_out(),
		.latency_cycles(noc_latency[3+:1])
	);
	holo_mesh_router #(
		.FLIT_W(FLIT_W),
		.CUR_X(0),
		.CUR_Y(0)
	) u_router0(
		.clk(clk),
		.rst_n(rst_n),
		.flit_in(r_flit_in[0]),
		.vld_in(r_vld_in[0]),
		.flit_out(r_flit_out[0]),
		.vld_out(r_vld_out[0])
	);
	holo_noc_1cycle #(
		.FLIT_W(FLIT_W),
		.DIES(2)
	) u_noc1(
		.clk(clk),
		.rst_n(rst_n),
		.flit_in({r_flit_in[1][0+:FLIT_W], inj_flit[2 * FLIT_W+:FLIT_W]}),
		.vld_in({r_vld_in[1][PORT_L], inj_vld[1]}),
		.flit_out(),
		.vld_out(),
		.latency_cycles(noc_latency[2+:1])
	);
	holo_mesh_router #(
		.FLIT_W(FLIT_W),
		.CUR_X(1),
		.CUR_Y(0)
	) u_router1(
		.clk(clk),
		.rst_n(rst_n),
		.flit_in(r_flit_in[1]),
		.vld_in(r_vld_in[1]),
		.flit_out(r_flit_out[1]),
		.vld_out(r_vld_out[1])
	);
	holo_noc_1cycle #(
		.FLIT_W(FLIT_W),
		.DIES(2)
	) u_noc2(
		.clk(clk),
		.rst_n(rst_n),
		.flit_in({r_flit_in[2][0+:FLIT_W], inj_flit[FLIT_W+:FLIT_W]}),
		.vld_in({r_vld_in[2][PORT_L], inj_vld[2]}),
		.flit_out(),
		.vld_out(),
		.latency_cycles(noc_latency[1+:1])
	);
	holo_mesh_router #(
		.FLIT_W(FLIT_W),
		.CUR_X(0),
		.CUR_Y(1)
	) u_router2(
		.clk(clk),
		.rst_n(rst_n),
		.flit_in(r_flit_in[2]),
		.vld_in(r_vld_in[2]),
		.flit_out(r_flit_out[2]),
		.vld_out(r_vld_out[2])
	);
	holo_noc_1cycle #(
		.FLIT_W(FLIT_W),
		.DIES(2)
	) u_noc3(
		.clk(clk),
		.rst_n(rst_n),
		.flit_in({r_flit_in[3][0+:FLIT_W], inj_flit[0+:FLIT_W]}),
		.vld_in({r_vld_in[3][PORT_L], inj_vld[3]}),
		.flit_out(),
		.vld_out(),
		.latency_cycles(noc_latency[0+:1])
	);
	holo_mesh_router #(
		.FLIT_W(FLIT_W),
		.CUR_X(1),
		.CUR_Y(1)
	) u_router3(
		.clk(clk),
		.rst_n(rst_n),
		.flit_in(r_flit_in[3]),
		.vld_in(r_vld_in[3]),
		.flit_out(r_flit_out[3]),
		.vld_out(r_vld_out[3])
	);
	initial _sv2v_0 = 0;
endmodule
