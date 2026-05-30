// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51.

////////////////////////////////////////////////////////////////////////////////
// Design Name:    Zkne AES32 Execution Unit (DOM-masked S-box, multi-cycle)  //
// Project Name:   RI5CY                                                      //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:                                                               //
//   Wraps aes_sbox_tower_dom.sv (4-cycle DOM-masked S-box) so that the       //
//   external interface matches Hruday's cv32e40p_zkne plus clk/rst_n and a   //
//   ready_o multi-cycle handshake. A small FSM (IDLE -> P1..P4 -> DONE       //
//   -> IDLE) drives the DOM pipeline for exactly one instruction at a time,  //
//   so back-to-back AES instructions don't corrupt the pipeline contents.    //
//                                                                            //
//   AES instruction takes 5 cycles total (1 IDLE -> 4 process -> 1 DONE).    //
//                                                                            //
//   Randomness: 32-bit Galois LFSR, shifts every cycle. Provides 8-bit input //
//   mask + 20-bit DOM cross-share randomness. Fresh randomness per cycle.    //
//                                                                            //
//   The unmasked S-box output is produced at the boundary (out_share0 XOR    //
//   out_share1) - this is the inherent integration cost. For the actual      //
//   first-order leakage claim see the sim-based rig in sidechannel/.         //
////////////////////////////////////////////////////////////////////////////////

module cv32e40p_zkne
  import cv32e40p_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,
  input  alu_opcode_e operator_i,
  input  logic [31:0] operand_a_i,
  input  logic [31:0] operand_b_i,
  input  logic [ 1:0] bs_i,
  output logic [31:0] result_o,
  output logic        ready_o
);

  // ---- detect AES op ----
  wire aes_op = (operator_i == ALU_AES32ESI) || (operator_i == ALU_AES32ESMI);

  // ---- FSM for multi-cycle handshake ----
  typedef enum logic [2:0] {S_IDLE, S_P1, S_P2, S_P3, S_P4, S_DONE} state_t;
  state_t state, next_state;

  always_comb begin
    next_state = state;
    case (state)
      S_IDLE: if (aes_op) next_state = S_P1;
      S_P1:   next_state = S_P2;
      S_P2:   next_state = S_P3;
      S_P3:   next_state = S_P4;
      S_P4:   next_state = S_DONE;
      S_DONE: next_state = S_IDLE;
      default: next_state = S_IDLE;
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= S_IDLE;
    else        state <= next_state;
  end

  wire dom_valid_in = (state == S_P1) || (state == S_P2) ||
                      (state == S_P3) || (state == S_P4);

  // ---- 32-bit Galois LFSR PRNG ----
  logic [31:0] lfsr_reg;
  wire   feedback = lfsr_reg[31];
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) lfsr_reg <= 32'h1234_5678;
    else        lfsr_reg <= {lfsr_reg[30:0], 1'b0} ^ (feedback ? 32'h0040_0007 : 32'h0);
  end

  wire [7:0]  mask_byte = lfsr_reg[7:0];
  wire [19:0] dom_rand  = lfsr_reg[27:8];

  // ---- byte select (same as Hruday) ----
  wire [4:0] shamt = {bs_i, 3'b000};
  wire [7:0] si    = operand_b_i[shamt +: 8];

  // ---- mask the input byte (only when actually processing) ----
  wire [7:0] in_share0 = si ^ mask_byte;
  wire [7:0] in_share1 = mask_byte;

  // ---- DOM-masked S-box (4-cycle internal pipeline) ----
  logic       dom_valid_out;
  logic [7:0] out_share0, out_share1;
  aes_sbox_tower_dom dom_inst (
    .clk        (clk),
    .rst_n      (rst_n),
    .valid_in   (dom_valid_in),
    .in_share0  (in_share0),
    .in_share1  (in_share1),
    .rand_in    (dom_rand),
    .valid_out  (dom_valid_out),
    .out_share0 (out_share0),
    .out_share1 (out_share1)
  );

  // ---- unmask at the output boundary ----
  wire [7:0] so = out_share0 ^ out_share1;

  // ---- xtime (same as Hruday) ----
  function automatic logic [7:0] xt2(input logic [7:0] x);
    return {x[6:0], 1'b0} ^ (x[7] ? 8'h1b : 8'h00);
  endfunction

  // ---- aes32esi placement ----
  logic [31:0] so_placed;
  always_comb
    case (bs_i)
      2'b00: so_placed = {24'b0,        so};
      2'b01: so_placed = {16'b0,  so,  8'b0};
      2'b10: so_placed = { 8'b0,  so, 16'b0};
      2'b11: so_placed = {        so, 24'b0};
    endcase

  // ---- aes32esmi MixColumns single-byte contribution then ROL32 ----
  wire [7:0] mc0 = xt2(so) ^ so;   // 0x03 * so
  wire [7:0] mc1 = so;             // 0x01 * so
  wire [7:0] mc2 = so;             // 0x01 * so
  wire [7:0] mc3 = xt2(so);        // 0x02 * so
  wire [31:0] mixcol_word = {mc3, mc2, mc1, mc0};

  logic [31:0] rol_mixed;
  always_comb
    case (bs_i)
      2'b00: rol_mixed = mixcol_word;
      2'b01: rol_mixed = {mixcol_word[23:0], mixcol_word[31:24]};
      2'b10: rol_mixed = {mixcol_word[15:0], mixcol_word[31:16]};
      2'b11: rol_mixed = {mixcol_word[ 7:0], mixcol_word[31: 8]};
    endcase

  // ---- output mux ----
  always_comb
    case (operator_i)
      ALU_AES32ESI:  result_o = operand_a_i ^ so_placed;
      ALU_AES32ESMI: result_o = operand_a_i ^ rol_mixed;
      default:       result_o = '0;
    endcase

  // ---- ready handshake to the ALU ----
  //   non-AES op: always ready (single-cycle path)
  //   AES op:     ready only in state DONE (r4 has captured by then)
  assign ready_o = aes_op ? (state == S_DONE) : 1'b1;

endmodule
