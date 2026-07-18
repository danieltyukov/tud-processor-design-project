// ============================================================================
//  aes_sbox_tower_dom.sv - DOM-masked tower-field AES forward S-box
// ----------------------------------------------------------------------------
//  First-order Domain-Oriented Masking (Gross/Mangard/Mendel 2016) applied to
//  the tower-field S-box from aes_sbox_tower.sv.
//
//    * 2-share Boolean masking: x = in_share0 XOR in_share1
//    * GF(2^4) inverse via a^14 = a^2 * a^4 * a^8 chain (no LUT)
//    * 5 GF(2^4) multipliers each wrapped as a registered DOM-AND gate
//    * 4-cycle pipeline; 20 bits of fresh randomness per execution
//
//  Combinational signals use `wire ... = ...` (continuous assignment); only
//  the pipeline registers are `logic` set inside always_ff. Note the SV gotcha
//  that `logic x = expr;` at module scope is one-time INITIALIZATION, not a
//  continuous assignment - that distinction is what makes this DOM design
//  actually update its intermediate signals.
// ============================================================================
`timescale 1ns/1ps

module aes_sbox_tower_dom (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        valid_in,
    input  logic [7:0]  in_share0,
    input  logic [7:0]  in_share1,
    input  logic [19:0] rand_in,
    output logic        valid_out,
    output logic [7:0]  out_share0,
    output logic [7:0]  out_share1
);

  // -------------------------------------------------------------------------
  // GF(2^4) primitives
  // -------------------------------------------------------------------------
  function automatic logic [3:0] gmul4(input logic [3:0] a, input logic [3:0] b);
    logic [3:0] p, aa, bb;
    begin
      p = 4'h0; aa = a; bb = b;
      for (int i = 0; i < 4; i++) begin
        if (bb[0]) p = p ^ aa;
        if (aa[3]) aa = {aa[2:0], 1'b0} ^ 4'h3;
        else       aa = {aa[2:0], 1'b0};
        bb = bb >> 1;
      end
      return p;
    end
  endfunction

  function automatic logic [3:0] sq4(input logic [3:0] a);
    return gmul4(a, a);
  endfunction

  function automatic logic [7:0] apply_in_map(input logic [7:0] x);
    logic [7:0] t;
    begin
      t = 8'h00;
      if (x[0]) t = t ^ 8'h01;
      if (x[1]) t = t ^ 8'h20;
      if (x[2]) t = t ^ 8'h46;
      if (x[3]) t = t ^ 8'h4c;
      if (x[4]) t = t ^ 8'h3c;
      if (x[5]) t = t ^ 8'hd5;
      if (x[6]) t = t ^ 8'h34;
      if (x[7]) t = t ^ 8'he5;
      return t;
    end
  endfunction

  function automatic logic [7:0] apply_out_map(input logic [7:0] x);
    logic [7:0] t;
    begin
      t = 8'h00;
      if (x[0]) t = t ^ 8'h1f;
      if (x[1]) t = t ^ 8'hb2;
      if (x[2]) t = t ^ 8'hab;
      if (x[3]) t = t ^ 8'h36;
      if (x[4]) t = t ^ 8'h52;
      if (x[5]) t = t ^ 8'h3e;
      if (x[6]) t = t ^ 8'h65;
      if (x[7]) t = t ^ 8'h60;
      return t;
    end
  endfunction

  localparam logic [3:0] LAMBDA = 4'h8;

  // -------------------------------------------------------------------------
  // Stage 0 (combinational): randomness unpack, in_map per share, nibble split
  // -------------------------------------------------------------------------
  wire [3:0] z_ah_al = rand_in[ 3: 0];
  wire [3:0] z_m1    = rand_in[ 7: 4];
  wire [3:0] z_m2    = rand_in[11: 8];
  wire [3:0] z_ph    = rand_in[15:12];
  wire [3:0] z_pl    = rand_in[19:16];

  wire [7:0] t_s0 = apply_in_map(in_share0);
  wire [7:0] t_s1 = apply_in_map(in_share1);
  wire [3:0] ah0  = t_s0[7:4];
  wire [3:0] al0  = t_s0[3:0];
  wire [3:0] ah1  = t_s1[7:4];
  wire [3:0] al1  = t_s1[3:0];

  // -------------------------------------------------------------------------
  // Stage 1: DOM-mul of  ah * al
  // -------------------------------------------------------------------------
  wire [3:0] m_ah_al_inner_s0 = gmul4(ah0, al0);
  wire [3:0] m_ah_al_inner_s1 = gmul4(ah1, al1);
  wire [3:0] m_ah_al_cross_0  = gmul4(ah0, al1) ^ z_ah_al;
  wire [3:0] m_ah_al_cross_1  = gmul4(ah1, al0) ^ z_ah_al;

  logic       r1_valid;
  logic [3:0] r1_ah0, r1_al0, r1_ah1, r1_al1;
  logic [3:0] r1_m_ah_al_s0, r1_m_ah_al_s1;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      r1_valid       <= 1'b0;
      r1_ah0         <= '0; r1_al0 <= '0; r1_ah1 <= '0; r1_al1 <= '0;
      r1_m_ah_al_s0  <= '0; r1_m_ah_al_s1 <= '0;
    end else begin
      r1_valid       <= valid_in;
      r1_ah0         <= ah0; r1_al0 <= al0; r1_ah1 <= ah1; r1_al1 <= al1;
      r1_m_ah_al_s0  <= m_ah_al_inner_s0 ^ m_ah_al_cross_0;
      r1_m_ah_al_s1  <= m_ah_al_inner_s1 ^ m_ah_al_cross_1;
    end
  end

  // -------------------------------------------------------------------------
  // Stage 2: build d shares, derive d^2, d^4, d^8; DOM-mul  m1 = d^2 * d^4
  // -------------------------------------------------------------------------
  wire [3:0] d_s0 = gmul4(sq4(r1_ah0), LAMBDA) ^ r1_m_ah_al_s0 ^ sq4(r1_al0);
  wire [3:0] d_s1 = gmul4(sq4(r1_ah1), LAMBDA) ^ r1_m_ah_al_s1 ^ sq4(r1_al1);

  wire [3:0] d2_s0 = sq4(d_s0);
  wire [3:0] d2_s1 = sq4(d_s1);
  wire [3:0] d4_s0 = sq4(d2_s0);
  wire [3:0] d4_s1 = sq4(d2_s1);
  wire [3:0] d8_s0 = sq4(d4_s0);
  wire [3:0] d8_s1 = sq4(d4_s1);

  wire [3:0] m1_inner_s0 = gmul4(d2_s0, d4_s0);
  wire [3:0] m1_inner_s1 = gmul4(d2_s1, d4_s1);
  wire [3:0] m1_cross_0  = gmul4(d2_s0, d4_s1) ^ z_m1;
  wire [3:0] m1_cross_1  = gmul4(d2_s1, d4_s0) ^ z_m1;

  logic       r2_valid;
  logic [3:0] r2_ah0, r2_al0, r2_ah1, r2_al1;
  logic [3:0] r2_d8_s0, r2_d8_s1;
  logic [3:0] r2_m1_s0, r2_m1_s1;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      r2_valid <= 1'b0;
      r2_ah0   <= '0; r2_al0 <= '0; r2_ah1 <= '0; r2_al1 <= '0;
      r2_d8_s0 <= '0; r2_d8_s1 <= '0;
      r2_m1_s0 <= '0; r2_m1_s1 <= '0;
    end else begin
      r2_valid <= r1_valid;
      r2_ah0   <= r1_ah0; r2_al0 <= r1_al0; r2_ah1 <= r1_ah1; r2_al1 <= r1_al1;
      r2_d8_s0 <= d8_s0;  r2_d8_s1 <= d8_s1;
      r2_m1_s0 <= m1_inner_s0 ^ m1_cross_0;
      r2_m1_s1 <= m1_inner_s1 ^ m1_cross_1;
    end
  end

  // -------------------------------------------------------------------------
  // Stage 3: DOM-mul  dinv = m1 * d^8  (= d^14)
  // -------------------------------------------------------------------------
  wire [3:0] m2_inner_s0 = gmul4(r2_m1_s0, r2_d8_s0);
  wire [3:0] m2_inner_s1 = gmul4(r2_m1_s1, r2_d8_s1);
  wire [3:0] m2_cross_0  = gmul4(r2_m1_s0, r2_d8_s1) ^ z_m2;
  wire [3:0] m2_cross_1  = gmul4(r2_m1_s1, r2_d8_s0) ^ z_m2;

  logic       r3_valid;
  logic [3:0] r3_ah0, r3_al0, r3_ah1, r3_al1;
  logic [3:0] r3_dinv_s0, r3_dinv_s1;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      r3_valid   <= 1'b0;
      r3_ah0     <= '0; r3_al0 <= '0; r3_ah1 <= '0; r3_al1 <= '0;
      r3_dinv_s0 <= '0; r3_dinv_s1 <= '0;
    end else begin
      r3_valid   <= r2_valid;
      r3_ah0     <= r2_ah0; r3_al0 <= r2_al0; r3_ah1 <= r2_ah1; r3_al1 <= r2_al1;
      r3_dinv_s0 <= m2_inner_s0 ^ m2_cross_0;
      r3_dinv_s1 <= m2_inner_s1 ^ m2_cross_1;
    end
  end

  // -------------------------------------------------------------------------
  // Stage 4: two parallel DOM-muls  ph = ah * dinv,   pl = (ah XOR al) * dinv
  // -------------------------------------------------------------------------
  wire [3:0] ahxal_s0 = r3_ah0 ^ r3_al0;
  wire [3:0] ahxal_s1 = r3_ah1 ^ r3_al1;

  wire [3:0] ph_inner_s0 = gmul4(r3_ah0, r3_dinv_s0);
  wire [3:0] ph_inner_s1 = gmul4(r3_ah1, r3_dinv_s1);
  wire [3:0] ph_cross_0  = gmul4(r3_ah0, r3_dinv_s1) ^ z_ph;
  wire [3:0] ph_cross_1  = gmul4(r3_ah1, r3_dinv_s0) ^ z_ph;

  wire [3:0] pl_inner_s0 = gmul4(ahxal_s0, r3_dinv_s0);
  wire [3:0] pl_inner_s1 = gmul4(ahxal_s1, r3_dinv_s1);
  wire [3:0] pl_cross_0  = gmul4(ahxal_s0, r3_dinv_s1) ^ z_pl;
  wire [3:0] pl_cross_1  = gmul4(ahxal_s1, r3_dinv_s0) ^ z_pl;

  logic       r4_valid;
  logic [3:0] r4_ph_s0, r4_ph_s1, r4_pl_s0, r4_pl_s1;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      r4_valid <= 1'b0;
      r4_ph_s0 <= '0; r4_ph_s1 <= '0; r4_pl_s0 <= '0; r4_pl_s1 <= '0;
    end else begin
      r4_valid <= r3_valid;
      r4_ph_s0 <= ph_inner_s0 ^ ph_cross_0;
      r4_ph_s1 <= ph_inner_s1 ^ ph_cross_1;
      r4_pl_s0 <= pl_inner_s0 ^ pl_cross_0;
      r4_pl_s1 <= pl_inner_s1 ^ pl_cross_1;
    end
  end

  // -------------------------------------------------------------------------
  // Combinational tail: assemble inv-tower per share, apply out_map per share,
  // add the AES affine constant 0x63 to ONE share only.
  // -------------------------------------------------------------------------
  wire [7:0] inv_tower_s0 = {r4_ph_s0, r4_pl_s0};
  wire [7:0] inv_tower_s1 = {r4_ph_s1, r4_pl_s1};

  assign out_share0 = apply_out_map(inv_tower_s0) ^ 8'h63;
  assign out_share1 = apply_out_map(inv_tower_s1);
  assign valid_out  = r4_valid;

endmodule
