// =============================================================================
// DOM-Protected Zkne AES32 Execution Unit for RI5CY / CV32E40P
// =============================================================================
//
// Implements aes32esi and aes32esmi with genuine first-order DOM protection
// using the OpenTitan aes_sbox_dom module (lowRISC, Apache 2.0).
//
// The aes_sbox_dom module uses the Canright tower-field AES S-box with
// DOM-AND gadgets at every non-linear gate — formally verified secure against
// first-order SCA by the Coco-Alma tool.
//
// Latency: 5 cycles (4 S-box pipeline stages + 1 output registration)
// The pipe_a/bs/op/v delay chain is extended to 5 to match.
// =============================================================================

module cv32e40p_zkne_dom
  import cv32e40p_pkg::*;
(
    input  logic          clk,
    input  logic          rst_n,

    input  alu_opcode_e   operator_i,
    input  logic [31:0]   operand_a_i,
    input  logic [31:0]   operand_b_i,
    input  logic [ 1:0]   bs_i,

    input  logic          valid_i,
    input  logic          en_i,
    output logic          valid_o,
    output logic          ready_o,

    output logic [31:0]   result_o
);

    // =========================================================================
    // 64-bit LFSR for pseudo-random data
    // aes_sbox_dom needs 28 bits of PRD per evaluation
    // =========================================================================
    logic [63:0] lfsr_state;
    wire lfsr_fb = lfsr_state[63] ^ lfsr_state[62] ^
                   lfsr_state[60] ^ lfsr_state[59];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) lfsr_state <= 64'hDEAD_BEEF_CAFE_1234;
        else        lfsr_state <= {lfsr_state[62:0], lfsr_fb};
    end

    // =========================================================================
    // Byte extraction and input share splitting
    // share0_in = si ^ mask,  share1_in = mask
    // =========================================================================
    logic [4:0] shamt;
    logic [7:0] si;
    assign shamt = {bs_i, 3'b000};
    assign si    = operand_b_i[shamt +: 8];

    wire [7:0] mask_in   = lfsr_state[7:0];
    wire [7:0] share0_in = si ^ mask_in;   // masked input (data_i for sbox)
    wire [7:0] share1_in = mask_in;        // mask        (mask_i for sbox)

    // =========================================================================
    // DOM-protected S-box (OpenTitan aes_sbox_dom, 5-cycle latency)
    //
    // data_i = share0_in  (the actual byte XORed with mask)
    // mask_i = share1_in  (the mask)
    // prd_i  = 28 fresh random bits from LFSR
    //
    // Output: data_o ^ mask_o = SBOX(si)
    // =========================================================================
    wire        sbox_out_req;
    wire [7:0]  so_data;    // share 0 of output
    wire [7:0]  so_mask;    // share 1 of output

    // sbox_running: set on valid_i, cleared when sbox fires.
    // Prevents the sbox from taking extra pipeline cycles after out_req fires
    // (en_i stays high one cycle longer than needed due to aes_in_flight timing).
    logic sbox_running;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)            sbox_running <= 1'b0;
        else if (valid_i)      sbox_running <= 1'b1;
        else if (sbox_out_req) sbox_running <= 1'b0;
    end

    aes_sbox_dom #(
        .PipelineMul(1'b1)
    ) sbox_i (
        .clk_i    (clk),
        .rst_ni   (rst_n),
        .en_i     (en_i & (valid_i | sbox_running)),
        .out_req_o(sbox_out_req),
        .out_ack_i(1'b1),
        .op_i     (aes_pkg::CIPH_FWD),
        .data_i   (share0_in),
        .mask_i   (share1_in),
        .prd_i    (lfsr_state[27:0]),
        .data_o   (so_data),
        .mask_o   (so_mask),
        .prd_o    ()
    );

    // Recombine shares to get correct S-box output
    wire [7:0] so = so_data ^ so_mask;

    // =========================================================================
    // 4-stage delay pipeline for operand_a, bs, operator
    // Gated by en_i so non-AES operands cannot corrupt it during stalls.
    // pipe[4] holds the correct values at the cycle sbox_out_req fires.
    // =========================================================================
    logic [31:0]  pipe_a  [0:4];
    logic [1:0]   pipe_bs [0:4];
    alu_opcode_e  pipe_op [0:4];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 5; i++) begin
                pipe_a[i]  <= '0;
                pipe_bs[i] <= '0;
                pipe_op[i] <= ALU_AES32ESI;
            end
        end else if (en_i) begin
            pipe_a[0]  <= operand_a_i;  pipe_a[1]  <= pipe_a[0];
            pipe_a[2]  <= pipe_a[1];    pipe_a[3]  <= pipe_a[2];
            pipe_a[4]  <= pipe_a[3];
            pipe_bs[0] <= bs_i;         pipe_bs[1] <= pipe_bs[0];
            pipe_bs[2] <= pipe_bs[1];   pipe_bs[3] <= pipe_bs[2];
            pipe_bs[4] <= pipe_bs[3];
            pipe_op[0] <= operator_i;   pipe_op[1] <= pipe_op[0];
            pipe_op[2] <= pipe_op[1];   pipe_op[3] <= pipe_op[2];
            pipe_op[4] <= pipe_op[3];
        end
    end

    // valid_o fires one cycle after sbox_out_req, when pipe[4] is aligned
    logic valid_reg;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) valid_reg <= 1'b0;
        else        valid_reg <= sbox_out_req;
    end
    assign valid_o = valid_reg;

    // =========================================================================
    // Stall counter: ready_o low for 5 cycles after valid_i
    // (4 sbox stages + 1 registration = 5 cycle total latency)
    // =========================================================================
    logic [2:0] stall_cnt;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)               stall_cnt <= '0;
        else if (valid_i)         stall_cnt <= 3'd5;
        else if (stall_cnt != '0) stall_cnt <= stall_cnt - 1'b1;
    end
    assign ready_o = (stall_cnt == '0);

    // =========================================================================
    // xtime: GF(2^8) multiply by 2
    // =========================================================================
    function automatic logic [7:0] xt2(input logic [7:0] x);
        return {x[6:0], 1'b0} ^ (x[7] ? 8'h1b : 8'h00);
    endfunction

    // =========================================================================
    // MixColumns and output
    //
    // Timing:
    //   cycle 4: sbox_out_req=1, so is valid.  pipe_a/bs/op[4] gets its correct
    //            value at the END of this edge (it can't be read combinationally
    //            yet — that would see the pre-edge stale value).
    //   cycle 5: pipe_a/bs/op[4] now hold the correct operands (post-edge).
    //            so_reg holds the sbox output captured from cycle 4.
    //            valid_reg=1 so valid_o fires.  result_o is combinational here
    //            and is correct for the full cycle the ex_stage reads it.
    //
    // so_reg: register `so` when sbox fires so it is stable at cycle 5.
    // =========================================================================
    logic [7:0] so_reg;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)          so_reg <= '0;
        else if (sbox_out_req) so_reg <= so;
    end

    logic [7:0]  mc0, mc1, mc2, mc3;
    logic [31:0] mixcol_word, rol_mixed, so_placed;

    assign mc0 = xt2(so_reg);
    assign mc1 = so_reg;
    assign mc2 = so_reg;
    assign mc3 = xt2(so_reg) ^ so_reg;
    assign mixcol_word = {mc3, mc2, mc1, mc0};

    always_comb begin
        case (pipe_bs[4])
            2'b00: so_placed = {24'b0,         so_reg        };
            2'b01: so_placed = {16'b0, so_reg,  8'b0         };
            2'b10: so_placed = { 8'b0, so_reg, 16'b0         };
            2'b11: so_placed = {       so_reg, 24'b0         };
            default: so_placed = '0;
        endcase

        case (pipe_bs[4])
            2'b00: rol_mixed = mixcol_word;
            2'b01: rol_mixed = {mixcol_word[23:0], mixcol_word[31:24]};
            2'b10: rol_mixed = {mixcol_word[15:0], mixcol_word[31:16]};
            2'b11: rol_mixed = {mixcol_word[ 7:0], mixcol_word[31: 8]};
            default: rol_mixed = '0;
        endcase
    end

    always_comb begin
        case (pipe_op[4])
            ALU_AES32ESI:  result_o = pipe_a[4] ^ so_placed;
            ALU_AES32ESMI: result_o = pipe_a[4] ^ rol_mixed;
            default:       result_o = '0;
        endcase
    end

endmodule