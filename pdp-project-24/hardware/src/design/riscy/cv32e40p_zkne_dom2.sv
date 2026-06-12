// =============================================================================
// 2-wide DOM-Protected Zkne AES "half column" Execution Unit (CV32E40P)
// =============================================================================
//
// Computes TWO AES byte-lanes in ONE instruction using TWO parallel
// DOM-protected S-boxes (OpenTitan aes_sbox_dom). Replaces two of the four
// chained aes32esmi/aes32esi steps that build an output word.
//
// Operands (same routing as the scalar aes32 path: operand_a, operand_b, bs):
//   bs_i[0] = pair index p in {0,1}; the two active lanes are 2p and 2p+1.
//     even lane (2p)   : byte (2p)   of operand_a_i
//     odd  lane (2p+1) : byte (2p+1) of operand_b_i
//
//   ALU_AES32ESMI2: rd = ROL(MixCol(SBOX(a[2p])),  2p*8)
//                      ^ ROL(MixCol(SBOX(b[2p+1])),(2p+1)*8)
//   ALU_AES32ESI2 : rd = SBOX(a[2p])   placed at byte 2p
//                      ^ SBOX(b[2p+1]) placed at byte 2p+1
//
// There is NO accumulator: software XORs the two halves (and the round key).
// So a full column = 2 of these instructions + a couple of XORs, instead of
// the 4 chained scalar instructions.
//
// Timing/handshake identical to cv32e40p_zkne_dom (5-cycle S-box latency,
// ready_o low for 5 cycles); both S-boxes run in lockstep.
//
// SECURITY NOTE: two parallel DOM S-boxes need two independent 28-bit PRD
// streams. We slice them from a 64-bit LFSR. Seed is fixed (sim only); a real
// deployment needs a TRNG and fresh, non-overlapping randomness.
// =============================================================================

module cv32e40p_zkne_dom2
  import cv32e40p_pkg::*;
#(
    parameter bit PipelineMul = 1'b1
) (
    input  logic        clk,
    input  logic        rst_n,

    input  alu_opcode_e operator_i,    // ALU_AES32ESMI2 or ALU_AES32ESI2
    input  logic [31:0] operand_a_i,   // supplies the even lane byte
    input  logic [31:0] operand_b_i,   // supplies the odd  lane byte
    input  logic [ 1:0] bs_i,          // bs_i[0] = pair index p

    input  logic        valid_i,
    input  logic        en_i,
    output logic        valid_o,
    output logic        ready_o,

    output logic [31:0] result_o
);

  // =========================================================================
  // 64-bit LFSR: lane0 PRD = [27:0], lane1 PRD = [55:28]
  // =========================================================================
  logic [63:0] lfsr_state;
  wire lfsr_fb = lfsr_state[63] ^ lfsr_state[62] ^ lfsr_state[60] ^ lfsr_state[59];
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) lfsr_state <= 64'hDEAD_BEEF_CAFE_1234;
    else        lfsr_state <= {lfsr_state[62:0], lfsr_fb};
  end

  // =========================================================================
  // Active lane indices and the two input bytes.
  // even lane = {p,1'b0} (0 or 2); odd lane = {p,1'b1} (1 or 3)
  // =========================================================================
  wire       p          = bs_i[0];
  wire [1:0] lane_even   = {p, 1'b0};
  wire [1:0] lane_odd    = {p, 1'b1};
  wire [4:0] off_even    = {p, 4'b0000};       // (2p)*8   = 16p
  wire [4:0] off_odd     = {p, 4'b0000} + 5'd8; // (2p+1)*8 = 16p+8

  wire [7:0] byte_even = operand_a_i[off_even +: 8];
  wire [7:0] byte_odd  = operand_b_i[off_odd  +: 8];

  // =========================================================================
  // sbox_running: set on valid_i, cleared when the lanes fire.
  // =========================================================================
  logic sbox_running;
  wire  col_out_req;
  always_ff @(posedge clk or negedge rst_n) begin
    if      (!rst_n)      sbox_running <= 1'b0;
    else if (valid_i)     sbox_running <= 1'b1;
    else if (col_out_req) sbox_running <= 1'b0;
  end
  wire sbox_en = en_i & (valid_i | sbox_running);

  // =========================================================================
  // Two parallel DOM S-boxes
  // =========================================================================
  wire [27:0] prd0 = lfsr_state[27:0];
  wire [27:0] prd1 = lfsr_state[55:28];

  wire [7:0] mask0 = prd0[7:0];
  wire [7:0] mask1 = prd1[7:0];

  wire [7:0] so0_data, so0_mask, so1_data, so1_mask;
  wire       out_req0, out_req1;

  aes_sbox_dom #(.PipelineMul(PipelineMul)) u_sbox_even (
      .clk_i(clk), .rst_ni(rst_n), .en_i(sbox_en),
      .out_req_o(out_req0), .out_ack_i(1'b1), .op_i(aes_pkg::CIPH_FWD),
      .data_i(byte_even ^ mask0), .mask_i(mask0), .prd_i(prd0),
      .data_o(so0_data), .mask_o(so0_mask), .prd_o());

  aes_sbox_dom #(.PipelineMul(PipelineMul)) u_sbox_odd (
      .clk_i(clk), .rst_ni(rst_n), .en_i(sbox_en),
      .out_req_o(out_req1), .out_ack_i(1'b1), .op_i(aes_pkg::CIPH_FWD),
      .data_i(byte_odd ^ mask1), .mask_i(mask1), .prd_i(prd1),
      .data_o(so1_data), .mask_o(so1_mask), .prd_o());

  wire [7:0] so_even = so0_data ^ so0_mask;
  wire [7:0] so_odd  = so1_data ^ so1_mask;
  assign col_out_req = out_req0;   // lockstep

  // =========================================================================
  // Counter / stall / valid: identical cadence to cv32e40p_zkne_dom.
  // =========================================================================
  logic [2:0] count_q, count_d;
  assign count_d = (valid_o)   ? '0             :
                   col_out_req ? count_q        :
                   en_i        ? count_q + 3'd1 : count_q;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) count_q <= '0; else count_q <= count_d;
  end

  logic valid_reg;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) valid_reg <= 1'b0; else valid_reg <= col_out_req;
  end
  assign valid_o = valid_reg;

  logic [2:0] stall_cnt;
  always_ff @(posedge clk or negedge rst_n) begin
    if      (!rst_n)           stall_cnt <= '0;
    else if (valid_i)          stall_cnt <= 3'd5;
    else if (stall_cnt != '0)  stall_cnt <= stall_cnt - 1'b1;
  end
  assign ready_o = (stall_cnt == '0);

  // =========================================================================
  // Register the two S-box outputs and the lane indices when they fire.
  // =========================================================================
  logic [7:0] so_even_reg, so_odd_reg;
  logic [1:0] lane_even_reg, lane_odd_reg;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      so_even_reg <= '0; so_odd_reg <= '0; lane_even_reg <= '0; lane_odd_reg <= 2'd1;
    end else if (col_out_req) begin
      so_even_reg <= so_even; so_odd_reg <= so_odd;
      lane_even_reg <= lane_even; lane_odd_reg <= lane_odd;
    end
  end

  // xtime: GF(2^8) multiply by 2.
  function automatic logic [7:0] xt2(input logic [7:0] x);
    return {x[6:0], 1'b0} ^ (x[7] ? 8'h1b : 8'h00);
  endfunction

  // MixColumns word for one S-box output: {mc3,mc2,mc1,mc0} = {xt2^so, so, so, xt2}
  function automatic logic [31:0] mixcol_word(input logic [7:0] so);
    return {xt2(so) ^ so, so, so, xt2(so)};
  endfunction

  // ROL32 by lane*8.
  function automatic logic [31:0] rol_by_lane(input logic [31:0] w, input logic [1:0] lane);
    case (lane)
      2'd0: rol_by_lane = w;
      2'd1: rol_by_lane = {w[23:0], w[31:24]};
      2'd2: rol_by_lane = {w[15:0], w[31:16]};
      2'd3: rol_by_lane = {w[ 7:0], w[31: 8]};
    endcase
  endfunction

  // Place an S-box byte into byte lane.
  function automatic logic [31:0] place_byte(input logic [7:0] b, input logic [1:0] lane);
    case (lane)
      2'd0: place_byte = {24'b0, b};
      2'd1: place_byte = {16'b0, b, 8'b0};
      2'd2: place_byte = { 8'b0, b, 16'b0};
      2'd3: place_byte = {       b, 24'b0};
    endcase
  endfunction

  wire [31:0] res_esmi2 =
      rol_by_lane(mixcol_word(so_even_reg), lane_even_reg) ^
      rol_by_lane(mixcol_word(so_odd_reg),  lane_odd_reg);

  wire [31:0] res_esi2 =
      place_byte(so_even_reg, lane_even_reg) ^
      place_byte(so_odd_reg,  lane_odd_reg);

  always_comb begin
    case (operator_i)
      ALU_AES32ESMI2: result_o = res_esmi2;
      ALU_AES32ESI2:  result_o = res_esi2;
      default:        result_o = '0;
    endcase
  end

endmodule
