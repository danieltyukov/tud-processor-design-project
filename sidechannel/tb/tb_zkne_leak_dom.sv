// ============================================================================
//  tb_zkne_leak_dom.sv - leakage rig driving the DOM-masked S-box
// ----------------------------------------------------------------------------
//  Counterpart to tb_zkne_leak.sv (which drove Hruday's unprotected combinational
//  S-box). Same CSV output format (idx,group,pt,hw,hd) so the same cpa.py /
//  tvla.py attack the result.
//
//  Per trace:
//    - mask  = fresh random 8 bits
//    - z     = fresh 20 random bits (DOM randomness)
//    - x     = pt XOR KEY_BYTE     (the S-box input)
//    - drive (in_share0, in_share1) = (x XOR mask, mask), assert valid_in for
//      ONE posedge, deassert, wait the 4-cycle pipeline, capture out_share0
//      into a register, log HW + HD.
//
//  The output share is statistically independent of the secret because the
//  mask is fresh per trace. So HW(out_share0) carries no information about
//  KEY_BYTE - CPA must fail and TVLA |t| must stay below 4.5.
// ============================================================================
`timescale 1ns/1ps

module tb_zkne_leak_dom;

  // ----- configuration (plusarg-overridable) -----
  int unsigned NUM_TRACES = 20000;
  int unsigned SEED       = 1;
  int unsigned KEY_BYTE   = 8'h2b;
  int unsigned MODE_TVLA  = 0;
  int unsigned FIXED_PT   = 8'h00;
  string       OUTFILE    = "out/dom_traces.csv";

  // ----- clock / reset -----
  logic clk = 1'b0;
  always #5 clk = ~clk;          // 100 MHz
  logic rst_n;

  // ----- DUT -----
  logic        valid_in;
  logic [7:0]  in_share0, in_share1;
  logic [19:0] rand_in;
  logic        valid_out;
  logic [7:0]  out_share0, out_share1;

  aes_sbox_tower_dom dut (
      .clk        (clk),
      .rst_n      (rst_n),
      .valid_in   (valid_in),
      .in_share0  (in_share0),
      .in_share1  (in_share1),
      .rand_in    (rand_in),
      .valid_out  (valid_out),
      .out_share0 (out_share0),
      .out_share1 (out_share1)
  );

  // ----- captured output share + Hamming-distance history -----
  logic [7:0] result_reg, result_reg_prev;

  // ----- deterministic xorshift32 PRNG -----
  logic [31:0] rng_state;
  function automatic logic [31:0] xorshift32(input logic [31:0] x);
    x ^= (x << 13);
    x ^= (x >> 17);
    x ^= (x << 5);
    return x;
  endfunction

  // ----- locals -----
  int           fd;
  int unsigned  i;
  int unsigned  group;
  int unsigned  hw, hd;
  logic [7:0]   pt, mask, rs2_byte;

  initial begin
    // plusargs
    if ($value$plusargs("num_traces=%d", NUM_TRACES)) ;
    if ($value$plusargs("seed=%d",       SEED))       ;
    if ($value$plusargs("key_byte=%d",   KEY_BYTE))   ;
    if ($value$plusargs("tvla=%d",       MODE_TVLA))  ;
    if ($value$plusargs("fixed_pt=%d",   FIXED_PT))   ;
    if ($value$plusargs("outfile=%s",    OUTFILE))    ;

    rng_state = SEED ^ 32'h9E3779B9;
    if (rng_state == 0) rng_state = 32'h1;

    // reset
    rst_n           = 1'b0;
    valid_in        = 1'b0;
    in_share0       = '0;
    in_share1       = '0;
    rand_in         = '0;
    result_reg      = '0;
    result_reg_prev = '0;
    repeat (3) @(posedge clk);
    rst_n = 1'b1;
    @(posedge clk);

    fd = $fopen(OUTFILE, "w");
    if (fd == 0) begin
      $error("cannot open %s for writing", OUTFILE);
      $finish;
    end
    $fwrite(fd, "idx,group,pt,hw,hd\n");

    // ----- trace loop -----
    for (i = 0; i < NUM_TRACES; i++) begin

      // pick plaintext (CPA vs TVLA)
      if (MODE_TVLA) begin
        rng_state = xorshift32(rng_state);
        group     = rng_state[0];
        if (group) begin
          pt = FIXED_PT[7:0];
        end else begin
          rng_state = xorshift32(rng_state);
          pt        = rng_state[7:0];
        end
      end else begin
        group     = 0;
        rng_state = xorshift32(rng_state);
        pt        = rng_state[7:0];
      end

      // fresh per-trace mask + DOM randomness
      rng_state = xorshift32(rng_state);
      mask      = rng_state[7:0];
      rng_state = xorshift32(rng_state);
      rand_in   = rng_state[19:0];

      rs2_byte  = pt ^ KEY_BYTE[7:0];

      // assert valid_in for ONE clock; deassert; wait pipeline drain
      @(negedge clk);
      in_share0 = rs2_byte ^ mask;
      in_share1 = mask;
      valid_in  = 1'b1;

      @(negedge clk);    // one posedge has fired -> r1 captured
      valid_in  = 1'b0;

      repeat (3) @(posedge clk);  // posedges for r2, r3, r4

      // at this point valid_out = 1, out_share0 is the masked S-box output share
      result_reg_prev = result_reg;
      result_reg      = out_share0;
      hw = $countones(result_reg);
      hd = $countones(result_reg ^ result_reg_prev);

      $fwrite(fd, "%0d,%0d,%0d,%0d,%0d\n", i, group, pt, hw, hd);
    end

    $fclose(fd);
    $display("DOM_LEAK_TB_DONE traces=%0d key_byte=0x%02x tvla=%0d outfile=%s",
             NUM_TRACES, KEY_BYTE[7:0], MODE_TVLA, OUTFILE);
    $finish;
  end

  // safety timeout
  initial begin
    #20_000_000;   // 20 ms
    $error("TIMEOUT in tb_zkne_leak_dom");
    $finish;
  end

endmodule
