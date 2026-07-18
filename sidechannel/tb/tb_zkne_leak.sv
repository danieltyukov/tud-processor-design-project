// ============================================================================
//  tb_zkne_leak.sv — side-channel leakage harness for the Zkne AES unit
// ----------------------------------------------------------------------------
//  Standalone unit testbench around cv32e40p_zkne (Hruday's unprotected AES
//  encryption unit). Drives N traces of (attacker-chosen plaintext byte XORed
//  with a hidden key byte) into the DUT, captures the result in a register
//  (modelling the EX/WB pipeline register), and logs a simulation power proxy
//  per trace to a CSV. The CSV is then attacked off-line by analysis/cpa.py
//  (correlation power analysis) and analysis/tvla.py (Welch t-test).
//
//  Attack model (first-round CPA):
//    rs2_byte = pt ^ KEY_BYTE        (AddRoundKey: the S-box input)
//    so       = sbox[rs2_byte]       (the leak point — computed in the DUT)
//    result   = operand_a ^ place(so, bs); operand_a := 0  ⇒ result == so@bs
//    power    = HammingWeight(result)  (logged clean; noise added in Python)
//
//  Compile standalone (only deps are the package + the DUT):
//    xvlog -sv rtl/cv32e40p_pkg.sv rtl/cv32e40p_zkne.sv tb/tb_zkne_leak.sv
//
//  Plusargs (all optional, defaults below):
//    +num_traces=<n>  +seed=<n>  +key_byte=<0..255>  +tvla=<0|1>
//    +fixed_pt=<0..255>  +op=<0=aes32esi|1=aes32esmi>  +bs=<0..3>
//    +outfile=<path>  +vcd=<0|1>
// ============================================================================
`timescale 1ns/1ps

module tb_zkne_leak
  import cv32e40p_pkg::*;
();

  // ----- configuration (overridable via plusargs) -----
  int unsigned  NUM_TRACES = 20000;
  int unsigned  SEED       = 1;
  int unsigned  KEY_BYTE   = 8'h2b;   // hidden key byte the attack must recover
  int unsigned  MODE_TVLA  = 0;       // 0 = CPA (all random), 1 = TVLA (fixed vs random)
  int unsigned  FIXED_PT   = 8'h00;   // fixed-group plaintext byte (TVLA)
  int unsigned  OP_SEL     = 0;       // 0 = aes32esi, 1 = aes32esmi
  int unsigned  BS         = 0;       // byte lane operated on (0..3)
  int unsigned  VCD_ON     = 0;       // 1 = also dump waves (debug only)
  string        OUTFILE    = "out/traces.csv";

  // ----- DUT I/O -----
  alu_opcode_e  operator;
  logic [31:0]  op_a, op_b;
  logic [1:0]   bs;
  logic [31:0]  dut_result;

  cv32e40p_zkne dut (
    .operator_i  (operator),
    .operand_a_i (op_a),
    .operand_b_i (op_b),
    .bs_i        (bs),
    .result_o    (dut_result)
  );

  // ----- captured result register (models the EX/WB pipeline register) -----
  logic [31:0] result_reg, result_reg_prev;

  // ----- locals -----
  int           fd;
  int unsigned  i;
  logic [7:0]   pt, rs2_byte;
  int unsigned  group;
  int unsigned  hw, hd;
  logic [31:0]  rng_state;

  // Deterministic, simulator-independent PRNG (xorshift32). xsim does not
  // support the seeded $urandom(seed) call form, and a fixed PRNG makes trace
  // sets exactly reproducible across machines.
  function automatic logic [31:0] xorshift32(input logic [31:0] x);
    x ^= (x << 13);
    x ^= (x >> 17);
    x ^= (x << 5);
    return x;
  endfunction

  initial begin
    // -- read plusargs (canonical if() form; xsim dislikes void'() here) --
    if ($value$plusargs("num_traces=%d", NUM_TRACES)) ;
    if ($value$plusargs("seed=%d",       SEED))       ;
    if ($value$plusargs("key_byte=%d",   KEY_BYTE))   ;
    if ($value$plusargs("tvla=%d",       MODE_TVLA))  ;
    if ($value$plusargs("fixed_pt=%d",   FIXED_PT))   ;
    if ($value$plusargs("op=%d",         OP_SEL))     ;
    if ($value$plusargs("bs=%d",         BS))         ;
    if ($value$plusargs("vcd=%d",        VCD_ON))     ;
    if ($value$plusargs("outfile=%s",    OUTFILE))    ;

    if (VCD_ON) begin
      $dumpfile("out/zkne_leak.vcd");
      $dumpvars(0, tb_zkne_leak);
    end

    // -- seed the PRNG (mix with golden-ratio constant; force non-zero) --
    rng_state = SEED ^ 32'h9E3779B9;
    if (rng_state == 0) rng_state = 32'h1;

    // -- static stimulus --
    operator = (OP_SEL == 1) ? ALU_AES32ESMI : ALU_AES32ESI;
    bs       = BS[1:0];
    op_a     = 32'h0;            // rs1 = 0  ⇒  result register == placed S-box output
    result_reg      = '0;
    result_reg_prev = '0;

    fd = $fopen(OUTFILE, "w");
    if (fd == 0) begin
      $error("tb_zkne_leak: cannot open %s for writing", OUTFILE);
      $finish;
    end
    $fwrite(fd, "idx,group,pt,hw,hd\n");

    // -- trace loop --
    for (i = 0; i < NUM_TRACES; i++) begin
      if (MODE_TVLA) begin
        rng_state = xorshift32(rng_state);
        group     = rng_state[0];                    // interleaved random/fixed
        if (group) begin
          pt = FIXED_PT[7:0];
        end else begin
          rng_state = xorshift32(rng_state);
          pt        = rng_state[7:0];
        end
      end else begin
        group     = 0;
        rng_state = xorshift32(rng_state);
        pt        = rng_state[7:0];                  // random plaintext byte
      end

      rs2_byte = pt ^ KEY_BYTE[7:0];                 // AddRoundKey → S-box input

      // place rs2_byte into lane bs of operand_b (the rest is don't-care/zero)
      op_b               = 32'h0;
      op_b[8*BS +: 8]    = rs2_byte;

      #1;  // let the combinational DUT settle

      result_reg_prev = result_reg;
      result_reg      = dut_result;

      hw = $countones(result_reg);
      hd = $countones(result_reg ^ result_reg_prev);

      $fwrite(fd, "%0d,%0d,%0d,%0d,%0d\n", i, group, pt, hw, hd);
    end

    $fclose(fd);
    $display("LEAK_TB_DONE traces=%0d key_byte=0x%02x op=%s bs=%0d tvla=%0d outfile=%s",
             NUM_TRACES, KEY_BYTE[7:0],
             (OP_SEL == 1) ? "aes32esmi" : "aes32esi", BS, MODE_TVLA, OUTFILE);
    $finish;
  end

endmodule
