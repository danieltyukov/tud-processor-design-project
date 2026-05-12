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
// Design Name:    Zkne AES32 Execution Unit                                  //
// Project Name:   RI5CY                                                      //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Implements the RISC-V Zkne scalar AES encryption           //
//                 instructions for RV32:                                     //
//                   aes32esi  rd,rs1,rs2,bs  -- SubBytes only                //
//                   aes32esmi rd,rs1,rs2,bs  -- SubBytes + MixColumns        //
//                                                                            //
// Instruction encoding (both share OPCODE_OPIMM = 7'h13, funct3 = 3'b000): //
//   [31:30] = bs   (byte select: 0-3)                                        //
//   [29:25] = 10001 (aes32esi) or 10011 (aes32esmi)                         //
//   [24:20] = rs2                                                            //
//   [19:15] = rs1                                                            //
//   [11:7]  = rd                                                             //
//                                                                            //
// bs is passed in via imm_vec_ext_i (the existing 2-bit path from ID→EX).  //
////////////////////////////////////////////////////////////////////////////////

module cv32e40p_zkne
  import cv32e40p_pkg::*;
(
  input  alu_opcode_e operator_i,
  input  logic [31:0] operand_a_i,  // rs1 (XOR'd with final result)
  input  logic [31:0] operand_b_i,  // rs2 (byte-selected, SubBytes applied)
  input  logic [ 1:0] bs_i,         // byte select from instr[31:30]
  output logic [31:0] result_o
);

  //-------------------------------------------------------------------------
  // AES forward S-box (FIPS 197, Figure 7)
  //-------------------------------------------------------------------------
  function automatic logic [7:0] aes_sbox_fwd(input logic [7:0] x);
    /* verilator lint_off CASEINCOMPLETE */
    case (x)
      8'h00:return 8'h63; 8'h01:return 8'h7c; 8'h02:return 8'h77; 8'h03:return 8'h7b;
      8'h04:return 8'hf2; 8'h05:return 8'h6b; 8'h06:return 8'h6f; 8'h07:return 8'hc5;
      8'h08:return 8'h30; 8'h09:return 8'h01; 8'h0a:return 8'h67; 8'h0b:return 8'h2b;
      8'h0c:return 8'hfe; 8'h0d:return 8'hd7; 8'h0e:return 8'hab; 8'h0f:return 8'h76;
      8'h10:return 8'hca; 8'h11:return 8'h82; 8'h12:return 8'hc9; 8'h13:return 8'h7d;
      8'h14:return 8'hfa; 8'h15:return 8'h59; 8'h16:return 8'h47; 8'h17:return 8'hf0;
      8'h18:return 8'had; 8'h19:return 8'hd4; 8'h1a:return 8'ha2; 8'h1b:return 8'haf;
      8'h1c:return 8'h9c; 8'h1d:return 8'ha4; 8'h1e:return 8'h72; 8'h1f:return 8'hc0;
      8'h20:return 8'hb7; 8'h21:return 8'hfd; 8'h22:return 8'h93; 8'h23:return 8'h26;
      8'h24:return 8'h36; 8'h25:return 8'h3f; 8'h26:return 8'hf7; 8'h27:return 8'hcc;
      8'h28:return 8'h34; 8'h29:return 8'ha5; 8'h2a:return 8'he5; 8'h2b:return 8'hf1;
      8'h2c:return 8'h71; 8'h2d:return 8'hd8; 8'h2e:return 8'h31; 8'h2f:return 8'h15;
      8'h30:return 8'h04; 8'h31:return 8'hc7; 8'h32:return 8'h23; 8'h33:return 8'hc3;
      8'h34:return 8'h18; 8'h35:return 8'h96; 8'h36:return 8'h05; 8'h37:return 8'h9a;
      8'h38:return 8'h07; 8'h39:return 8'h12; 8'h3a:return 8'h80; 8'h3b:return 8'he2;
      8'h3c:return 8'heb; 8'h3d:return 8'h27; 8'h3e:return 8'hb2; 8'h3f:return 8'h75;
      8'h40:return 8'h09; 8'h41:return 8'h83; 8'h42:return 8'h2c; 8'h43:return 8'h1a;
      8'h44:return 8'h1b; 8'h45:return 8'h6e; 8'h46:return 8'h5a; 8'h47:return 8'ha0;
      8'h48:return 8'h52; 8'h49:return 8'h3b; 8'h4a:return 8'hd6; 8'h4b:return 8'hb3;
      8'h4c:return 8'h29; 8'h4d:return 8'he3; 8'h4e:return 8'h2f; 8'h4f:return 8'h84;
      8'h50:return 8'h53; 8'h51:return 8'hd1; 8'h52:return 8'h00; 8'h53:return 8'hed;
      8'h54:return 8'h20; 8'h55:return 8'hfc; 8'h56:return 8'hb1; 8'h57:return 8'h5b;
      8'h58:return 8'h6a; 8'h59:return 8'hcb; 8'h5a:return 8'hbe; 8'h5b:return 8'h39;
      8'h5c:return 8'h4a; 8'h5d:return 8'h4c; 8'h5e:return 8'h58; 8'h5f:return 8'hcf;
      8'h60:return 8'hd0; 8'h61:return 8'hef; 8'h62:return 8'haa; 8'h63:return 8'hfb;
      8'h64:return 8'h43; 8'h65:return 8'h4d; 8'h66:return 8'h33; 8'h67:return 8'h85;
      8'h68:return 8'h45; 8'h69:return 8'hf9; 8'h6a:return 8'h02; 8'h6b:return 8'h7f;
      8'h6c:return 8'h50; 8'h6d:return 8'h3c; 8'h6e:return 8'h9f; 8'h6f:return 8'ha8;
      8'h70:return 8'h51; 8'h71:return 8'ha3; 8'h72:return 8'h40; 8'h73:return 8'h8f;
      8'h74:return 8'h92; 8'h75:return 8'h9d; 8'h76:return 8'h38; 8'h77:return 8'hf5;
      8'h78:return 8'hbc; 8'h79:return 8'hb6; 8'h7a:return 8'hda; 8'h7b:return 8'h21;
      8'h7c:return 8'h10; 8'h7d:return 8'hff; 8'h7e:return 8'hf3; 8'h7f:return 8'hd2;
      8'h80:return 8'hcd; 8'h81:return 8'h0c; 8'h82:return 8'h13; 8'h83:return 8'hec;
      8'h84:return 8'h5f; 8'h85:return 8'h97; 8'h86:return 8'h44; 8'h87:return 8'h17;
      8'h88:return 8'hc4; 8'h89:return 8'ha7; 8'h8a:return 8'h7e; 8'h8b:return 8'h3d;
      8'h8c:return 8'h64; 8'h8d:return 8'h5d; 8'h8e:return 8'h19; 8'h8f:return 8'h73;
      8'h90:return 8'h60; 8'h91:return 8'h81; 8'h92:return 8'h4f; 8'h93:return 8'hdc;
      8'h94:return 8'h22; 8'h95:return 8'h2a; 8'h96:return 8'h90; 8'h97:return 8'h88;
      8'h98:return 8'h46; 8'h99:return 8'hee; 8'h9a:return 8'hb8; 8'h9b:return 8'h14;
      8'h9c:return 8'hde; 8'h9d:return 8'h5e; 8'h9e:return 8'h0b; 8'h9f:return 8'hdb;
      8'ha0:return 8'he0; 8'ha1:return 8'h32; 8'ha2:return 8'h3a; 8'ha3:return 8'h0a;
      8'ha4:return 8'h49; 8'ha5:return 8'h06; 8'ha6:return 8'h24; 8'ha7:return 8'h5c;
      8'ha8:return 8'hc2; 8'ha9:return 8'hd3; 8'haa:return 8'hac; 8'hab:return 8'h62;
      8'hac:return 8'h91; 8'had:return 8'h95; 8'hae:return 8'he4; 8'haf:return 8'h79;
      8'hb0:return 8'he7; 8'hb1:return 8'hc8; 8'hb2:return 8'h37; 8'hb3:return 8'h6d;
      8'hb4:return 8'h8d; 8'hb5:return 8'hd5; 8'hb6:return 8'h4e; 8'hb7:return 8'ha9;
      8'hb8:return 8'h6c; 8'hb9:return 8'h56; 8'hba:return 8'hf4; 8'hbb:return 8'hea;
      8'hbc:return 8'h65; 8'hbd:return 8'h7a; 8'hbe:return 8'hae; 8'hbf:return 8'h08;
      8'hc0:return 8'hba; 8'hc1:return 8'h78; 8'hc2:return 8'h25; 8'hc3:return 8'h2e;
      8'hc4:return 8'h1c; 8'hc5:return 8'ha6; 8'hc6:return 8'hb4; 8'hc7:return 8'hc6;
      8'hc8:return 8'he8; 8'hc9:return 8'hdd; 8'hca:return 8'h74; 8'hcb:return 8'h1f;
      8'hcc:return 8'h4b; 8'hcd:return 8'hbd; 8'hce:return 8'h8b; 8'hcf:return 8'h8a;
      8'hd0:return 8'h70; 8'hd1:return 8'h3e; 8'hd2:return 8'hb5; 8'hd3:return 8'h66;
      8'hd4:return 8'h48; 8'hd5:return 8'h03; 8'hd6:return 8'hf6; 8'hd7:return 8'h0e;
      8'hd8:return 8'h61; 8'hd9:return 8'h35; 8'hda:return 8'h57; 8'hdb:return 8'hb9;
      8'hdc:return 8'h86; 8'hdd:return 8'hc1; 8'hde:return 8'h1d; 8'hdf:return 8'h9e;
      8'he0:return 8'he1; 8'he1:return 8'hf8; 8'he2:return 8'h98; 8'he3:return 8'h11;
      8'he4:return 8'h69; 8'he5:return 8'hd9; 8'he6:return 8'h8e; 8'he7:return 8'h94;
      8'he8:return 8'h9b; 8'he9:return 8'h1e; 8'hea:return 8'h87; 8'heb:return 8'he9;
      8'hec:return 8'hce; 8'hed:return 8'h55; 8'hee:return 8'h28; 8'hef:return 8'hdf;
      8'hf0:return 8'h8c; 8'hf1:return 8'ha1; 8'hf2:return 8'h89; 8'hf3:return 8'h0d;
      8'hf4:return 8'hbf; 8'hf5:return 8'he6; 8'hf6:return 8'h42; 8'hf7:return 8'h68;
      8'hf8:return 8'h41; 8'hf9:return 8'h99; 8'hfa:return 8'h2d; 8'hfb:return 8'h0f;
      8'hfc:return 8'hb0; 8'hfd:return 8'h54; 8'hfe:return 8'hbb; 8'hff:return 8'h16;
      default: return 8'h00;
    endcase
    /* verilator lint_on CASEINCOMPLETE */
  endfunction

  //-------------------------------------------------------------------------
  // xtime: multiply by {02} in GF(2^8) with AES reduction polynomial
  //-------------------------------------------------------------------------
  function automatic logic [7:0] xt2(input logic [7:0] x);
    return {x[6:0], 1'b0} ^ (x[7] ? 8'h1b : 8'h00);
  endfunction

  //-------------------------------------------------------------------------
  // Internal signals
  //-------------------------------------------------------------------------
  logic [4:0] shamt;
  logic [7:0] si, so;

  // aes32esi: place SubBytes(so) into byte lane bs
  logic [31:0] so_placed;

  // aes32esmi: MixColumns single-byte contribution, then ROL32 by bs*8
  logic [7:0]  mc0, mc1, mc2, mc3;
  logic [31:0] mixcol_word;
  logic [31:0] rol_mixed;

  //-------------------------------------------------------------------------
  // Byte select and SubBytes lookup
  //-------------------------------------------------------------------------
  assign shamt = {bs_i, 3'b000};            // bs * 8 : values 0, 8, 16, 24
  assign si    = operand_b_i[shamt +: 8];   // extract byte bs from rs2
  assign so    = aes_sbox_fwd(si);

  //-------------------------------------------------------------------------
  // aes32esi: rd = rs1 ^ (so placed in byte lane bs)
  //-------------------------------------------------------------------------
  always_comb
    case (bs_i)
      2'b00: so_placed = {24'b0,        so};
      2'b01: so_placed = {16'b0,  so,  8'b0};
      2'b10: so_placed = { 8'b0,  so, 16'b0};
      2'b11: so_placed = {        so, 24'b0};
    endcase

  //-------------------------------------------------------------------------
  // aes32esmi: rd = rs1 ^ ROL32(MixColumn(so), bs*8)
  // Column contribution vector: coeff [0x03, 0x01, 0x01, 0x02] * so
  //-------------------------------------------------------------------------
  assign mc0 = xt2(so) ^ so;   // byte 0: coefficient 0x03
  assign mc1 = so;              // byte 1: coefficient 0x01
  assign mc2 = so;              // byte 2: coefficient 0x01
  assign mc3 = xt2(so);        // byte 3: coefficient 0x02
  assign mixcol_word = {mc3, mc2, mc1, mc0};

  always_comb
    case (bs_i)
      2'b00: rol_mixed = mixcol_word;
      2'b01: rol_mixed = {mixcol_word[23:0], mixcol_word[31:24]};
      2'b10: rol_mixed = {mixcol_word[15:0], mixcol_word[31:16]};
      2'b11: rol_mixed = {mixcol_word[ 7:0], mixcol_word[31: 8]};
    endcase

  //-------------------------------------------------------------------------
  // Output mux
  //-------------------------------------------------------------------------
  always_comb
    case (operator_i)
      ALU_AES32ESI:  result_o = operand_a_i ^ so_placed;
      ALU_AES32ESMI: result_o = operand_a_i ^ rol_mixed;
      default:       result_o = '0;
    endcase

endmodule
