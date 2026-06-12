// Minimal aes_pkg for use with aes_sbox_dom only.
// Extracted from OpenTitan (Apache 2.0).
// Contains: ciph_op_e enum and aes_mvm function used by aes_sbox_dom.
package aes_pkg;

  typedef enum logic [1:0] {
    CIPH_FWD = 2'b01,
    CIPH_INV = 2'b10
  } ciph_op_e;

  // Matrix-vector multiply over GF(2) - used by aes_sbox_dom for
  // isomorphism conversions (A2X, X2S, S2X, X2A matrices).
  function automatic logic [7:0] aes_mvm(
    logic [7:0] vec_b,
    logic [7:0] mat_a [8]
  );
    logic [7:0] vec_c;
    vec_c = '0;
    for (int i = 0; i < 8; i++) begin
      for (int j = 0; j < 8; j++) begin
        vec_c[i] = vec_c[i] ^ (mat_a[j][i] & vec_b[7-j]);
      end
    end
    return vec_c;
  endfunction

endpackage