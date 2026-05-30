// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

////////////////////////////////////////////////////////////////////////////////
// Design Name:    Zkne AES32 Execution Unit (tower-field S-box variant)      //
// Project Name:   RI5CY                                                      //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Same external interface as Hruday's cv32e40p_zkne.sv but   //
//                 the S-box is computed via the verified tower-field         //
//                 decomposition (GF((2^4)^2)) - the same math used by        //
//                 sidechannel/dom/aes_sbox_tower.sv. Constants come from     //
//                 sidechannel/dom/sbox_tower_model.py and are brute-force    //
//                 verified against the 256-entry FIPS 197 table.             //
//                                                                            //
//                 Still combinational, still single-cycle - no ALU changes   //
//                 needed. The point: prove the tower-field math runs on real //
//                 silicon, as the prerequisite for the DOM-masked variant.   //
////////////////////////////////////////////////////////////////////////////////

module cv32e40p_zkne
  import cv32e40p_pkg::*;
(
  input  alu_opcode_e operator_i,
  input  logic [31:0] operand_a_i,
  input  logic [31:0] operand_b_i,
  input  logic [ 1:0] bs_i,
  output logic [31:0] result_o
);

  //-------------------------------------------------------------------------
  // GF(2^4) primitives (poly y^4 + y + 1)
  //-------------------------------------------------------------------------
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

  function automatic logic [3:0] ginv4(input logic [3:0] a);
    case (a)
      4'h0: return 4'h0; 4'h1: return 4'h1; 4'h2: return 4'h9; 4'h3: return 4'he;
      4'h4: return 4'hd; 4'h5: return 4'hb; 4'h6: return 4'h7; 4'h7: return 4'h6;
      4'h8: return 4'hf; 4'h9: return 4'h2; 4'ha: return 4'hc; 4'hb: return 4'h5;
      4'hc: return 4'ha; 4'hd: return 4'h4; 4'he: return 4'h3; 4'hf: return 4'h8;
    endcase
  endfunction

  //-------------------------------------------------------------------------
  // AES forward S-box, via the tower-field decomposition
  //   sbox(x) = AffineLinear( InvIso( tinv( Iso(x) ) ) ) XOR 0x63
  // with lambda = 0x8, isomorphism constants verified by sbox_tower_model.py.
  //-------------------------------------------------------------------------
  function automatic logic [7:0] aes_sbox_fwd(input logic [7:0] x);
    logic [7:0] t, out_lin, inv_tower;
    logic [3:0] ah, al;
    logic [3:0] ah_sq, al_sq, ah_al, ah_sq_lam, d, dinv;
    logic [3:0] ph, pl;
    begin
      // in_map: standard byte -> tower representation
      t = 8'h00;
      if (x[0]) t = t ^ 8'h01;
      if (x[1]) t = t ^ 8'h20;
      if (x[2]) t = t ^ 8'h46;
      if (x[3]) t = t ^ 8'h4c;
      if (x[4]) t = t ^ 8'h3c;
      if (x[5]) t = t ^ 8'hd5;
      if (x[6]) t = t ^ 8'h34;
      if (x[7]) t = t ^ 8'he5;

      ah = t[7:4];
      al = t[3:0];

      // GF((2^4)^2) inverse: A = ah*z + al
      //   d = ah^2 * lambda + ah*al + al^2
      //   A^-1 = (ah * d^-1) z + ((ah+al) * d^-1)
      ah_sq     = sq4(ah);
      al_sq     = sq4(al);
      ah_al     = gmul4(ah, al);
      ah_sq_lam = gmul4(ah_sq, 4'h8);    // lambda = 0x8
      d         = ah_sq_lam ^ ah_al ^ al_sq;
      dinv      = ginv4(d);
      ph        = gmul4(ah,         dinv);
      pl        = gmul4(ah ^ al,    dinv);
      inv_tower = {ph, pl};

      // out_map: tower-inverse -> standard byte (folded with affine linear)
      out_lin = 8'h00;
      if (inv_tower[0]) out_lin = out_lin ^ 8'h1f;
      if (inv_tower[1]) out_lin = out_lin ^ 8'hb2;
      if (inv_tower[2]) out_lin = out_lin ^ 8'hab;
      if (inv_tower[3]) out_lin = out_lin ^ 8'h36;
      if (inv_tower[4]) out_lin = out_lin ^ 8'h52;
      if (inv_tower[5]) out_lin = out_lin ^ 8'h3e;
      if (inv_tower[6]) out_lin = out_lin ^ 8'h65;
      if (inv_tower[7]) out_lin = out_lin ^ 8'h60;

      return out_lin ^ 8'h63;    // AES affine constant
    end
  endfunction

  //-------------------------------------------------------------------------
  // xtime: multiply by {02} in GF(2^8) with AES reduction polynomial
  //-------------------------------------------------------------------------
  function automatic logic [7:0] xt2(input logic [7:0] x);
    return {x[6:0], 1'b0} ^ (x[7] ? 8'h1b : 8'h00);
  endfunction

  //-------------------------------------------------------------------------
  // Internal signals (identical to Hruday's original, downstream unchanged)
  //-------------------------------------------------------------------------
  logic [4:0] shamt;
  logic [7:0] si, so;

  logic [31:0] so_placed;

  logic [7:0]  mc0, mc1, mc2, mc3;
  logic [31:0] mixcol_word;
  logic [31:0] rol_mixed;

  assign shamt = {bs_i, 3'b000};
  assign si    = operand_b_i[shamt +: 8];
  assign so    = aes_sbox_fwd(si);   // <-- now goes through the tower-field path

  always_comb
    case (bs_i)
      2'b00: so_placed = {24'b0,        so};
      2'b01: so_placed = {16'b0,  so,  8'b0};
      2'b10: so_placed = { 8'b0,  so, 16'b0};
      2'b11: so_placed = {        so, 24'b0};
    endcase

  assign mc0 = xt2(so) ^ so;
  assign mc1 = so;
  assign mc2 = so;
  assign mc3 = xt2(so);
  assign mixcol_word = {mc3, mc2, mc1, mc0};

  always_comb
    case (bs_i)
      2'b00: rol_mixed = mixcol_word;
      2'b01: rol_mixed = {mixcol_word[23:0], mixcol_word[31:24]};
      2'b10: rol_mixed = {mixcol_word[15:0], mixcol_word[31:16]};
      2'b11: rol_mixed = {mixcol_word[ 7:0], mixcol_word[31: 8]};
    endcase

  always_comb
    case (operator_i)
      ALU_AES32ESI:  result_o = operand_a_i ^ so_placed;
      ALU_AES32ESMI: result_o = operand_a_i ^ rol_mixed;
      default:       result_o = '0;
    endcase

endmodule
