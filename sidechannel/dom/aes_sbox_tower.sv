// ============================================================================
//  aes_sbox_tower.sv - unmasked tower-field AES forward S-box
// ----------------------------------------------------------------------------
//  Computes:    sbox(x) = AffineLinear( InvIso( tinv( Iso(x) ) ) )  XOR  0x63
//
//  where:
//    Iso       : 8x8 GF(2) linear map  std_byte  -> GF((2^4)^2) tower byte
//    tinv      : multiplicative inverse in the tower field
//                (GF(2^4) operations with modulus z^2 + z + lambda, lambda=0x8)
//    InvIso    : inverse linear map, folded together with the AES affine's
//                linear part into "out_map"
//    XOR 0x63  : AES affine constant (FIPS 197)
//
//  All field constants come from sbox_tower_model.py which brute-force verifies
//  the composition reproduces the entire 256-entry AES S-box table. Do NOT
//  hand-edit them - rerun the model if you need to change the basis.
//
//  Combinational only (no clock). This is the unmasked baseline that the DOM
//  version (cv32e40p_zkne_dom.sv, Phase 3b) will be built on top of by splitting
//  the GF(2^4) inverse into GF(2^2) ops and masking the nonlinear multipliers.
// ============================================================================

module aes_sbox_tower (
    input  logic [7:0] x,
    output logic [7:0] sbox_out
);

  // -------------------------------------------------------------------------
  // GF(2^4) primitives -  modulus y^4 + y + 1  (reduce-mask 4'h3)
  // -------------------------------------------------------------------------
  function automatic logic [3:0] gmul4(input logic [3:0] a, input logic [3:0] b);
    logic [3:0] p, aa, bb;
    begin
      p  = 4'h0;
      aa = a;
      bb = b;
      for (int i = 0; i < 4; i++) begin
        if (bb[0]) p = p ^ aa;
        if (aa[3]) aa = {aa[2:0], 1'b0} ^ 4'h3;     // x*y reduced by y^4 = y + 1
        else       aa = {aa[2:0], 1'b0};
        bb = bb >> 1;
      end
      return p;
    end
  endfunction

  // GF(2^4) inverse via 16-entry table (a^14 in GF(2^4)*).
  // Constants derived in sbox_tower_model.py (and double-checked by hand
  // against generator alpha = 0x2: inv(alpha^k) = alpha^(15-k)).
  function automatic logic [3:0] ginv4(input logic [3:0] a);
    case (a)
      4'h0: return 4'h0;
      4'h1: return 4'h1;
      4'h2: return 4'h9;
      4'h3: return 4'he;
      4'h4: return 4'hd;
      4'h5: return 4'hb;
      4'h6: return 4'h7;
      4'h7: return 4'h6;
      4'h8: return 4'hf;
      4'h9: return 4'h2;
      4'ha: return 4'hc;
      4'hb: return 4'h5;
      4'hc: return 4'ha;
      4'hd: return 4'h4;
      4'he: return 4'h3;
      4'hf: return 4'h8;
    endcase
  endfunction

  // -------------------------------------------------------------------------
  // in_map: standard byte -> tower representation (verified in Python)
  // image of input bit i for i = 0..7:
  //   01, 20, 46, 4c, 3c, d5, 34, e5
  // -------------------------------------------------------------------------
  logic [7:0] t;
  always_comb begin
    t = 8'h00;
    if (x[0]) t = t ^ 8'h01;
    if (x[1]) t = t ^ 8'h20;
    if (x[2]) t = t ^ 8'h46;
    if (x[3]) t = t ^ 8'h4c;
    if (x[4]) t = t ^ 8'h3c;
    if (x[5]) t = t ^ 8'hd5;
    if (x[6]) t = t ^ 8'h34;
    if (x[7]) t = t ^ 8'he5;
  end

  // -------------------------------------------------------------------------
  // Tower inverse in GF((2^4)^2) with modulus z^2 + z + lambda, lambda = 0x8.
  //
  // For A = ah*z + al  (ah,al in GF(2^4)):
  //    d        = ah^2 * lambda + ah*al + al^2            (the "norm")
  //    A^{-1}   = (ah * d^{-1}) z + ((ah + al) * d^{-1})
  //
  // The only nonlinear gates here are the GF(2^4) multipliers - those are
  // what DOM masking will protect in Phase 3b.
  // -------------------------------------------------------------------------
  logic [3:0] ah, al;
  logic [3:0] ah_sq, al_sq, ah_al, ah_sq_lam, d, dinv;
  logic [3:0] ph, pl;
  logic [7:0] inv_tower;
  localparam logic [3:0] LAMBDA = 4'h8;

  assign ah = t[7:4];
  assign al = t[3:0];

  assign ah_sq     = gmul4(ah, ah);
  assign al_sq     = gmul4(al, al);
  assign ah_al     = gmul4(ah, al);
  assign ah_sq_lam = gmul4(ah_sq, LAMBDA);
  assign d         = ah_sq_lam ^ ah_al ^ al_sq;
  assign dinv      = ginv4(d);
  assign ph        = gmul4(ah,         dinv);
  assign pl        = gmul4(ah ^ al,    dinv);
  assign inv_tower = {ph, pl};

  // -------------------------------------------------------------------------
  // out_map: tower-inverse byte -> standard byte, folded with AES affine
  // linear part. Image of inverse-result bit i for i = 0..7:
  //   1f, b2, ab, 36, 52, 3e, 65, 60
  // Final S-box adds the AES affine constant 0x63.
  // -------------------------------------------------------------------------
  logic [7:0] out_lin;
  always_comb begin
    out_lin = 8'h00;
    if (inv_tower[0]) out_lin = out_lin ^ 8'h1f;
    if (inv_tower[1]) out_lin = out_lin ^ 8'hb2;
    if (inv_tower[2]) out_lin = out_lin ^ 8'hab;
    if (inv_tower[3]) out_lin = out_lin ^ 8'h36;
    if (inv_tower[4]) out_lin = out_lin ^ 8'h52;
    if (inv_tower[5]) out_lin = out_lin ^ 8'h3e;
    if (inv_tower[6]) out_lin = out_lin ^ 8'h65;
    if (inv_tower[7]) out_lin = out_lin ^ 8'h60;
  end

  assign sbox_out = out_lin ^ 8'h63;

endmodule
