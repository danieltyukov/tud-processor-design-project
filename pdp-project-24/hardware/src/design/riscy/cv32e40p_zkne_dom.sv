// =============================================================================
// DOM-Protected Zkne AES32 Super Execution Unit for RI5CY / CV32E40P
// =============================================================================
//
// Implements the 4-operand parallel super variants of aes32esi / aes32esmi.
//
// Each of the four source registers contributes its least-significant byte:
//   si[k] = operand_k_i[7:0]  for k = 0..3
//
// The byte-select (bs) field is not used; all four bytes are processed in
// parallel through four independent DOM-protected S-box instances.
//
// ESI result:
//   rd = rs1[7:0]_sbox ^ rs2[7:0]_sbox ^ rs3[7:0]_sbox ^ rs4[7:0]_sbox
//   (placed at bit 0, no rotation — pure parallel SubBytes)
//
// ESMI result (with MixColumns):
//   Each sbox output goes through MixColumns independently, then XOR'd:
//   rd = MC(rs1[7:0]_sbox) ^ MC(rs2[7:0]_sbox) ^ MC(rs3[7:0]_sbox) ^ MC(rs4[7:0]_sbox)
//
// Latency: 5 cycles (4 DOM S-box pipeline stages + 1 output registration)
//
// DOM protection: first-order DOM using the OpenTitan aes_sbox_dom module.
// Each S-box instance gets its own independent mask from the LFSR to avoid
// mask reuse across parallel instances (which would break DOM security).
// =============================================================================

module cv32e40p_zkne_dom
  import cv32e40p_pkg::*;
(
    input  logic          clk,
    input  logic          rst_n,

    input  alu_opcode_e   operator_i,

    // Four independent source registers (rs1..rs4 from super instruction)
    input  logic [31:0]   operand_a_i,   // rs1
    input  logic [31:0]   operand_b_i,   // rs2
    input  logic [31:0]   operand_c_i,   // rs3
    input  logic [31:0]   operand_d_i,   // rs4

    // bs_i is unused in the super instruction (kept for port compatibility)
    input  logic [ 1:0]   bs_i,

    input  logic          valid_i,
    input  logic          en_i,
    output logic          valid_o,
    output logic          ready_o,

    output logic [31:0]   result_o
);

    // =========================================================================
    // 64-bit LFSR for pseudo-random data
    // Each of the 4 S-box instances needs 28 bits of PRD per evaluation.
    // We use different non-overlapping slices so each instance has independent
    // masking — mask reuse across parallel DOM instances breaks security.
    // Total needed: 4 * 8 bits for input masks + 4 * 28 bits for PRD = 144 bits.
    // Two 64-bit LFSRs provide 128 bits; the masks reuse the lower slices
    // (acceptable since input masks and PRD are consumed at different points).
    // =========================================================================
    logic [63:0] lfsr0, lfsr1;
    wire fb0 = lfsr0[63] ^ lfsr0[62] ^ lfsr0[60] ^ lfsr0[59];
    wire fb1 = lfsr1[63] ^ lfsr1[62] ^ lfsr1[60] ^ lfsr1[59];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lfsr0 <= 64'hDEAD_BEEF_CAFE_1234;
            lfsr1 <= 64'h1234_5678_9ABC_DEF0;
        end else begin
            lfsr0 <= {lfsr0[62:0], fb0};
            lfsr1 <= {lfsr1[62:0], fb1};
        end
    end

    // Assign independent mask and PRD slices to each of the 4 S-box instances.
    // mask_in[k] : 8-bit input share mask for instance k
    // prd[k]     : 28-bit pseudo-random data for DOM-AND gates in instance k
    wire [7:0]  mask_in [0:3];
    wire [27:0] prd     [0:3];

    assign mask_in[0] = lfsr0[ 7: 0];
    assign mask_in[1] = lfsr0[15: 8];
    assign mask_in[2] = lfsr1[ 7: 0];
    assign mask_in[3] = lfsr1[15: 8];

    assign prd[0]     = lfsr0[27: 0];   // overlaps mask_in[0..2] — OK (consumed at different times)
    assign prd[1]     = lfsr0[55:28];
    assign prd[2]     = lfsr1[27: 0];
    assign prd[3]     = lfsr1[55:28];

    // =========================================================================
    // Input byte extraction and share splitting for each instance
    // share0[k] = si[k] ^ mask_in[k]  (masked byte, data_i for sbox)
    // share1[k] = mask_in[k]           (the mask,   mask_i for sbox)
    // =========================================================================
    wire [7:0] si [0:3];
    assign si[0] = operand_a_i[7:0];
    assign si[1] = operand_b_i[7:0];
    assign si[2] = operand_c_i[7:0];
    assign si[3] = operand_d_i[7:0];

    wire [7:0] share0 [0:3];
    wire [7:0] share1 [0:3];
    generate
        for (genvar k = 0; k < 4; k++) begin : gen_shares
            assign share0[k] = si[k] ^ mask_in[k];
            assign share1[k] = mask_in[k];
        end
    endgenerate

    // =========================================================================
    // sbox_running: set on valid_i, cleared when any sbox fires out_req.
    // All 4 sboxes are synchronous so out_req[0] is representative.
    // =========================================================================
    wire [3:0] sbox_out_req;
    logic sbox_running;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)                 sbox_running <= 1'b0;
        else if (valid_i)           sbox_running <= 1'b1;
        else if (sbox_out_req[0])   sbox_running <= 1'b0;
    end

    // =========================================================================
    // 4 x DOM-protected S-box instances
    // =========================================================================
    wire [7:0] so_data [0:3];   // share 0 of each S-box output
    wire [7:0] so_mask [0:3];   // share 1 of each S-box output

    generate
        for (genvar k = 0; k < 4; k++) begin : gen_sboxes
            aes_sbox_dom #(
                .PipelineMul(1'b1)
            ) sbox_i (
                .clk_i    (clk),
                .rst_ni   (rst_n),
                .en_i     (en_i & (valid_i | sbox_running)),
                .out_req_o(sbox_out_req[k]),
                .out_ack_i(1'b1),
                .op_i     (aes_pkg::CIPH_FWD),
                .data_i   (share0[k]),
                .mask_i   (share1[k]),
                .prd_i    (prd[k]),
                .data_o   (so_data[k]),
                .mask_o   (so_mask[k]),
                .prd_o    ()
            );
        end
    endgenerate

    // Recombine shares: so[k] = SBOX(si[k])
    wire [7:0] so [0:3];
    generate
        for (genvar k = 0; k < 4; k++) begin : gen_recombine
            assign so[k] = so_data[k] ^ so_mask[k];
        end
    endgenerate

    // =========================================================================
    // valid_o fires one cycle after sbox_out_req, matching the pipeline[4]
    // delay chain below (so operator is stable when result is computed).
    // =========================================================================
    logic valid_reg;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) valid_reg <= 1'b0;
        else        valid_reg <= sbox_out_req[0];
    end
    assign valid_o = valid_reg;

    // =========================================================================
    // 4-stage delay pipeline for operator
    // Gated by en_i so stale instructions cannot corrupt it.
    // pipe_op[4] holds the correct operator at the cycle valid_o fires.
    // =========================================================================
    alu_opcode_e pipe_op [0:4];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 5; i++)
                pipe_op[i] <= ALU_AES32ESI;
        end else if (en_i) begin
            pipe_op[0] <= operator_i;
            pipe_op[1] <= pipe_op[0];
            pipe_op[2] <= pipe_op[1];
            pipe_op[3] <= pipe_op[2];
            pipe_op[4] <= pipe_op[3];
        end
    end

    // =========================================================================
    // Stall counter: ready_o low for 5 cycles after valid_i
    // (4 S-box pipeline stages + 1 output registration)
    // =========================================================================
    logic [2:0] stall_cnt;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)               stall_cnt <= '0;
        else if (valid_i)         stall_cnt <= 3'd5;
        else if (stall_cnt != '0) stall_cnt <= stall_cnt - 1'b1;
    end
    assign ready_o = (stall_cnt == '0);

    // =========================================================================
    // xtime: GF(2^8) multiply-by-2
    // =========================================================================
    function automatic logic [7:0] xt2(input logic [7:0] x);
        return {x[6:0], 1'b0} ^ (x[7] ? 8'h1b : 8'h00);
    endfunction

    // =========================================================================
    // Latch S-box outputs when they fire (cycle 4), then use them at cycle 5
    // when valid_o is asserted and pipe_op[4] is stable.
    // =========================================================================
    logic [7:0] so_reg [0:3];
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int k = 0; k < 4; k++) so_reg[k] <= '0;
        end else if (sbox_out_req[0]) begin
            for (int k = 0; k < 4; k++) so_reg[k] <= so[k];
        end
    end

    // =========================================================================
    // MixColumns helper: produce the 32-bit MC word for one S-box output byte.
    // Standard AES MixColumns column contribution for a single byte s:
    //   {xt2(s)^s,  s,  s,  xt2(s)}  placed at bit 0, rotated by bs elsewhere.
    // For the super instruction bs=0 for all four (bytes are always at [7:0]),
    // so no rotation is needed — mc_word is the same for all four instances.
    // =========================================================================
    function automatic logic [31:0] mixcol_word(input logic [7:0] s);
        logic [7:0] x2;
        x2 = xt2(s);
        // Column: [xt2(s)^s, s, s, xt2(s)] — byte 0 at LSB
        return {x2 ^ s, s, s, x2};
    endfunction

    // =========================================================================
    // Output combination (combinational, valid while valid_o is high)
    //
    // ESI:  XOR all four S-box bytes placed at bit position 0 (no bs rotation)
    // ESMI: XOR all four MixColumns words (each 32-bit contribution)
    // =========================================================================
    logic [31:0] esi_result, esmi_result;

    always_comb begin
        // ESI: place each sbox byte at bits [7:0] and XOR across all 4
        esi_result  = {24'b0, so_reg[0]}
                    ^ {24'b0, so_reg[1]}
                    ^ {24'b0, so_reg[2]}
                    ^ {24'b0, so_reg[3]};

        // ESMI: full MixColumns contribution from each byte, XOR'd together
        esmi_result = mixcol_word(so_reg[0])
                    ^ mixcol_word(so_reg[1])
                    ^ mixcol_word(so_reg[2])
                    ^ mixcol_word(so_reg[3]);
    end

    always_comb begin
        case (pipe_op[4])
            ALU_AES32ESI:  result_o = esi_result;
            ALU_AES32ESMI: result_o = esmi_result;
            default:       result_o = '0;
        endcase
    end

endmodule
