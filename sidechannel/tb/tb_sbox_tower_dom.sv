// ============================================================================
//  tb_sbox_tower_dom.sv - functional equivalence test for the DOM-masked S-box
// ----------------------------------------------------------------------------
//  For each test (x, mask, rand_bits):
//     - drive in_share0 = x XOR mask, in_share1 = mask
//     - wait the 4-cycle pipeline latency
//     - read out_share0, out_share1
//     - assert  (out_share0 XOR out_share1) == sbox_ref[x]
//
//  Also walks all 256 values of x with mask = 0 (degenerate but sanity-checks
//  the no-mask path), and then a large random sweep over (x, mask, rand).
// ============================================================================
`timescale 1ns/1ps

module tb_sbox_tower_dom;

  logic clk = 1'b0;
  logic rst_n;
  logic valid_in;
  logic [7:0] in_share0, in_share1;
  logic [19:0] rand_in;
  logic valid_out;
  logic [7:0] out_share0, out_share1;

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

  always #5 clk = ~clk;   // 100 MHz

  // ---- reference S-box ----
  logic [7:0] expected [0:255];
  initial begin
    expected[  0]=8'h63; expected[  1]=8'h7c; expected[  2]=8'h77; expected[  3]=8'h7b;
    expected[  4]=8'hf2; expected[  5]=8'h6b; expected[  6]=8'h6f; expected[  7]=8'hc5;
    expected[  8]=8'h30; expected[  9]=8'h01; expected[ 10]=8'h67; expected[ 11]=8'h2b;
    expected[ 12]=8'hfe; expected[ 13]=8'hd7; expected[ 14]=8'hab; expected[ 15]=8'h76;
    expected[ 16]=8'hca; expected[ 17]=8'h82; expected[ 18]=8'hc9; expected[ 19]=8'h7d;
    expected[ 20]=8'hfa; expected[ 21]=8'h59; expected[ 22]=8'h47; expected[ 23]=8'hf0;
    expected[ 24]=8'had; expected[ 25]=8'hd4; expected[ 26]=8'ha2; expected[ 27]=8'haf;
    expected[ 28]=8'h9c; expected[ 29]=8'ha4; expected[ 30]=8'h72; expected[ 31]=8'hc0;
    expected[ 32]=8'hb7; expected[ 33]=8'hfd; expected[ 34]=8'h93; expected[ 35]=8'h26;
    expected[ 36]=8'h36; expected[ 37]=8'h3f; expected[ 38]=8'hf7; expected[ 39]=8'hcc;
    expected[ 40]=8'h34; expected[ 41]=8'ha5; expected[ 42]=8'he5; expected[ 43]=8'hf1;
    expected[ 44]=8'h71; expected[ 45]=8'hd8; expected[ 46]=8'h31; expected[ 47]=8'h15;
    expected[ 48]=8'h04; expected[ 49]=8'hc7; expected[ 50]=8'h23; expected[ 51]=8'hc3;
    expected[ 52]=8'h18; expected[ 53]=8'h96; expected[ 54]=8'h05; expected[ 55]=8'h9a;
    expected[ 56]=8'h07; expected[ 57]=8'h12; expected[ 58]=8'h80; expected[ 59]=8'he2;
    expected[ 60]=8'heb; expected[ 61]=8'h27; expected[ 62]=8'hb2; expected[ 63]=8'h75;
    expected[ 64]=8'h09; expected[ 65]=8'h83; expected[ 66]=8'h2c; expected[ 67]=8'h1a;
    expected[ 68]=8'h1b; expected[ 69]=8'h6e; expected[ 70]=8'h5a; expected[ 71]=8'ha0;
    expected[ 72]=8'h52; expected[ 73]=8'h3b; expected[ 74]=8'hd6; expected[ 75]=8'hb3;
    expected[ 76]=8'h29; expected[ 77]=8'he3; expected[ 78]=8'h2f; expected[ 79]=8'h84;
    expected[ 80]=8'h53; expected[ 81]=8'hd1; expected[ 82]=8'h00; expected[ 83]=8'hed;
    expected[ 84]=8'h20; expected[ 85]=8'hfc; expected[ 86]=8'hb1; expected[ 87]=8'h5b;
    expected[ 88]=8'h6a; expected[ 89]=8'hcb; expected[ 90]=8'hbe; expected[ 91]=8'h39;
    expected[ 92]=8'h4a; expected[ 93]=8'h4c; expected[ 94]=8'h58; expected[ 95]=8'hcf;
    expected[ 96]=8'hd0; expected[ 97]=8'hef; expected[ 98]=8'haa; expected[ 99]=8'hfb;
    expected[100]=8'h43; expected[101]=8'h4d; expected[102]=8'h33; expected[103]=8'h85;
    expected[104]=8'h45; expected[105]=8'hf9; expected[106]=8'h02; expected[107]=8'h7f;
    expected[108]=8'h50; expected[109]=8'h3c; expected[110]=8'h9f; expected[111]=8'ha8;
    expected[112]=8'h51; expected[113]=8'ha3; expected[114]=8'h40; expected[115]=8'h8f;
    expected[116]=8'h92; expected[117]=8'h9d; expected[118]=8'h38; expected[119]=8'hf5;
    expected[120]=8'hbc; expected[121]=8'hb6; expected[122]=8'hda; expected[123]=8'h21;
    expected[124]=8'h10; expected[125]=8'hff; expected[126]=8'hf3; expected[127]=8'hd2;
    expected[128]=8'hcd; expected[129]=8'h0c; expected[130]=8'h13; expected[131]=8'hec;
    expected[132]=8'h5f; expected[133]=8'h97; expected[134]=8'h44; expected[135]=8'h17;
    expected[136]=8'hc4; expected[137]=8'ha7; expected[138]=8'h7e; expected[139]=8'h3d;
    expected[140]=8'h64; expected[141]=8'h5d; expected[142]=8'h19; expected[143]=8'h73;
    expected[144]=8'h60; expected[145]=8'h81; expected[146]=8'h4f; expected[147]=8'hdc;
    expected[148]=8'h22; expected[149]=8'h2a; expected[150]=8'h90; expected[151]=8'h88;
    expected[152]=8'h46; expected[153]=8'hee; expected[154]=8'hb8; expected[155]=8'h14;
    expected[156]=8'hde; expected[157]=8'h5e; expected[158]=8'h0b; expected[159]=8'hdb;
    expected[160]=8'he0; expected[161]=8'h32; expected[162]=8'h3a; expected[163]=8'h0a;
    expected[164]=8'h49; expected[165]=8'h06; expected[166]=8'h24; expected[167]=8'h5c;
    expected[168]=8'hc2; expected[169]=8'hd3; expected[170]=8'hac; expected[171]=8'h62;
    expected[172]=8'h91; expected[173]=8'h95; expected[174]=8'he4; expected[175]=8'h79;
    expected[176]=8'he7; expected[177]=8'hc8; expected[178]=8'h37; expected[179]=8'h6d;
    expected[180]=8'h8d; expected[181]=8'hd5; expected[182]=8'h4e; expected[183]=8'ha9;
    expected[184]=8'h6c; expected[185]=8'h56; expected[186]=8'hf4; expected[187]=8'hea;
    expected[188]=8'h65; expected[189]=8'h7a; expected[190]=8'hae; expected[191]=8'h08;
    expected[192]=8'hba; expected[193]=8'h78; expected[194]=8'h25; expected[195]=8'h2e;
    expected[196]=8'h1c; expected[197]=8'ha6; expected[198]=8'hb4; expected[199]=8'hc6;
    expected[200]=8'he8; expected[201]=8'hdd; expected[202]=8'h74; expected[203]=8'h1f;
    expected[204]=8'h4b; expected[205]=8'hbd; expected[206]=8'h8b; expected[207]=8'h8a;
    expected[208]=8'h70; expected[209]=8'h3e; expected[210]=8'hb5; expected[211]=8'h66;
    expected[212]=8'h48; expected[213]=8'h03; expected[214]=8'hf6; expected[215]=8'h0e;
    expected[216]=8'h61; expected[217]=8'h35; expected[218]=8'h57; expected[219]=8'hb9;
    expected[220]=8'h86; expected[221]=8'hc1; expected[222]=8'h1d; expected[223]=8'h9e;
    expected[224]=8'he1; expected[225]=8'hf8; expected[226]=8'h98; expected[227]=8'h11;
    expected[228]=8'h69; expected[229]=8'hd9; expected[230]=8'h8e; expected[231]=8'h94;
    expected[232]=8'h9b; expected[233]=8'h1e; expected[234]=8'h87; expected[235]=8'he9;
    expected[236]=8'hce; expected[237]=8'h55; expected[238]=8'h28; expected[239]=8'hdf;
    expected[240]=8'h8c; expected[241]=8'ha1; expected[242]=8'h89; expected[243]=8'h0d;
    expected[244]=8'hbf; expected[245]=8'he6; expected[246]=8'h42; expected[247]=8'h68;
    expected[248]=8'h41; expected[249]=8'h99; expected[250]=8'h2d; expected[251]=8'h0f;
    expected[252]=8'hb0; expected[253]=8'h54; expected[254]=8'hbb; expected[255]=8'h16;
  end

  // ---- xorshift32 PRNG (so the test is fully deterministic) ----
  logic [31:0] rng_state;
  function automatic logic [31:0] xorshift32(input logic [31:0] x);
    x ^= (x << 13);
    x ^= (x >> 17);
    x ^= (x << 5);
    return x;
  endfunction

  // ---- queue of expected outputs (one per inflight x) ----
  logic [7:0] inflight [$];

  // ---- main stimulus + checker ----
  int errors;
  int checked;
  int total_to_send;
  int sent;

  initial begin
    errors        = 0;
    checked       = 0;
    sent          = 0;
    total_to_send = 256 + 5000;       // exhaustive mask=0 sweep + random sweep
    rng_state     = 32'hDEAD_BEEF;

    // ---- reset ----
    rst_n      = 1'b0;
    valid_in   = 1'b0;
    in_share0  = '0;
    in_share1  = '0;
    rand_in    = '0;
    repeat (3) @(posedge clk);
    rst_n      = 1'b1;
    @(posedge clk);

    // ---- send all stimuli + drain pipeline ----
    fork
      // -- driver --
      begin
        // 1) exhaustive sweep with mask = 0 (sanity: just no-mask path)
        for (int x = 0; x < 256; x++) begin
          @(negedge clk);
          valid_in  = 1'b1;
          in_share0 = x[7:0];
          in_share1 = 8'h00;
          rand_in   = '0;             // no randomness needed (mask = 0)
          inflight.push_back(expected[x]);
          sent++;
        end
        // 2) random sweep
        begin
          logic [7:0] x_val, mask_val;
          for (int k = 0; k < 5000; k++) begin
            @(negedge clk);
            rng_state = xorshift32(rng_state); mask_val  = rng_state[7:0];
            rng_state = xorshift32(rng_state); x_val     = rng_state[7:0];
            rng_state = xorshift32(rng_state); rand_in   = rng_state[19:0];
            in_share1 = mask_val;
            in_share0 = x_val ^ mask_val;
            inflight.push_back(expected[x_val]);
            sent++;
          end
        end
        @(negedge clk);
        valid_in = 1'b0;
        // wait pipeline drain
        repeat (8) @(posedge clk);
      end

      // -- consumer (one entry consumed per clock when valid_out high) --
      begin : check_blk
        logic [7:0] sbox_val;
        logic [7:0] exp_val;
        while (checked < total_to_send) begin
          @(posedge clk);
          if (valid_out) begin
            sbox_val = out_share0 ^ out_share1;
            exp_val  = inflight.pop_front();
            checked++;
            if (sbox_val !== exp_val) begin
              errors++;
              if (errors <= 4) begin
                $display("MISMATCH #%0d: shares=%02h^%02h=%02h  expected=%02h",
                         checked, out_share0, out_share1, sbox_val, exp_val);
              end
            end
          end
        end
      end
    join

    $display("----------------------------------------------------------");
    if (errors == 0) begin
      $display("DOM SBOX TEST: PASS  (%0d/%0d unmasked results match AES)",
               checked, total_to_send);
    end else begin
      $display("DOM SBOX TEST: FAIL  %0d/%0d mismatches",
               errors, total_to_send);
    end
    $display("----------------------------------------------------------");
    $finish;
  end

  // safety timeout
  initial begin
    #2000000;   // 2 ms = 200,000 clocks - generous
    $error("TIMEOUT");
    $finish;
  end

endmodule
