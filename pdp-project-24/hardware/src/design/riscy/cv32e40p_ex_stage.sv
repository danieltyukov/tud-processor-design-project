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
// Design Name:    Execute stage                                              //
// Project Name:   RI5CY                                                      //
// Language:       SystemVerilog                                              //
//                                                                            //
// Description:    Execution stage with DOM-protected AES32 support.          //
//                 The DOM unit has 5-cycle latency. When an AES32 instruction //
//                 enters EX, this stage stalls for 4 cycles by holding       //
//                 ex_ready_o low until aes_valid_o is asserted.              //
////////////////////////////////////////////////////////////////////////////////

module cv32e40p_ex_stage
  import cv32e40p_pkg::*;
  import cv32e40p_apu_core_pkg::*;
#(
    parameter FPU              = 0,
    parameter APU_NARGS_CPU    = 3,
    parameter APU_WOP_CPU      = 6,
    parameter APU_NDSFLAGS_CPU = 15,
    parameter APU_NUSFLAGS_CPU = 5
) (
    input logic clk,
    input logic rst_n,

    // ALU signals from ID stage
    input alu_opcode_e        alu_operator_i,
    input logic        [31:0] alu_operand_a_i,
    input logic        [31:0] alu_operand_b_i,
    input logic        [31:0] alu_operand_c_i,
    input logic               alu_en_i,
    input logic        [ 4:0] bmask_a_i,
    input logic        [ 4:0] bmask_b_i,
    input logic        [ 1:0] imm_vec_ext_i,
    input logic        [ 1:0] alu_vec_mode_i,
    input logic               alu_is_clpx_i,
    input logic               alu_is_subrot_i,
    input logic        [ 1:0] alu_clpx_shift_i,

    // Multiplier signals
    input mul_opcode_e        mult_operator_i,
    input logic        [31:0] mult_operand_a_i,
    input logic        [31:0] mult_operand_b_i,
    input logic        [31:0] mult_operand_c_i,
    input logic               mult_en_i,
    input logic               mult_sel_subword_i,
    input logic        [ 1:0] mult_signed_mode_i,
    input logic        [ 4:0] mult_imm_i,

    input logic [31:0] mult_dot_op_a_i,
    input logic [31:0] mult_dot_op_b_i,
    input logic [31:0] mult_dot_op_c_i,
    input logic [ 1:0] mult_dot_signed_i,
    input logic        mult_is_clpx_i,
    input logic [ 1:0] mult_clpx_shift_i,
    input logic        mult_clpx_img_i,

    output logic mult_multicycle_o,

    // FPU signals
    output logic fpu_fflags_we_o,

    // APU signals
    input logic                              apu_en_i,
    input logic [     APU_WOP_CPU-1:0]       apu_op_i,
    input logic [                 1:0]       apu_lat_i,
    input logic [   APU_NARGS_CPU-1:0][31:0] apu_operands_i,
    input logic [                 5:0]       apu_waddr_i,
    input logic [APU_NDSFLAGS_CPU-1:0]       apu_flags_i,

    input  logic [2:0][5:0] apu_read_regs_i,
    input  logic [2:0]      apu_read_regs_valid_i,
    output logic            apu_read_dep_o,
    input  logic [1:0][5:0] apu_write_regs_i,
    input  logic [1:0]      apu_write_regs_valid_i,
    output logic            apu_write_dep_o,

    output logic apu_perf_type_o,
    output logic apu_perf_cont_o,
    output logic apu_perf_wb_o,

    output logic apu_busy_o,
    output logic apu_ready_wb_o,

    // apu-interconnect
    output logic                           apu_req_o,
    input  logic                           apu_gnt_i,
    output logic [APU_NARGS_CPU-1:0][31:0] apu_operands_o,
    output logic [  APU_WOP_CPU-1:0]       apu_op_o,
    input  logic                           apu_rvalid_i,
    input  logic [             31:0]       apu_result_i,

    input logic        lsu_en_i,
    input logic [31:0] lsu_rdata_i,

    // input from ID stage
    input logic       branch_in_ex_i,
    input logic [5:0] regfile_alu_waddr_i,
    input logic       regfile_alu_we_i,

    // directly passed through to WB stage
    input logic       regfile_we_i,
    input logic [5:0] regfile_waddr_i,

    // CSR access
    input logic        csr_access_i,
    input logic [31:0] csr_rdata_i,

    // Output of EX stage pipeline
    output logic [ 5:0] regfile_waddr_wb_o,
    output logic        regfile_we_wb_o,
    output logic [31:0] regfile_wdata_wb_o,

    // Forwarding ports : to ID stage
    output logic [ 5:0] regfile_alu_waddr_fw_o,
    output logic        regfile_alu_we_fw_o,
    output logic [31:0] regfile_alu_wdata_fw_o,

    // To IF: Jump and branch target and decision
    output logic [31:0] jump_target_o,
    output logic        branch_decision_o,

    // Stall Control
    input logic         is_decoding_i,
    input logic lsu_ready_ex_i,
    input logic lsu_err_i,

    output logic ex_ready_o,
    output logic ex_valid_o,
    input  logic wb_ready_i
);

  logic [31:0] alu_result;
  logic [31:0] mult_result;
  logic        alu_cmp_result;

  logic        regfile_we_lsu;
  logic [ 5:0] regfile_waddr_lsu;

  logic        wb_contention;
  logic        wb_contention_lsu;

  logic        alu_ready;
  logic        mult_ready;

  // APU signals
  logic        apu_valid;
  logic [ 5:0] apu_waddr;
  logic [31:0] apu_result;
  logic        apu_stall;
  logic        apu_active;
  logic        apu_singlecycle;
  logic        apu_multicycle;
  logic        apu_req;
  logic        apu_gnt;

  // =========================================================================
  // DOM AES stall signals
  //
  // aes_insn:      true when the current instruction in EX is AES32
  // aes_in_flight: true from the cycle valid_i is sent until valid_o arrives
  // aes_valid_i:   one-cycle pulse sent to DOM unit at start of AES instruction
  // aes_valid_o:   one-cycle pulse from DOM unit when result is ready (4 cycles later)
  // aes_ready:     low while DOM unit is busy (used to stall ex_ready_o)
  // aes_result:    the 32-bit result from the DOM unit
  // =========================================================================

  logic        aes_insn;        // current instruction is AES32
  logic        aes_in_flight;   // AES instruction currently being processed
  logic        aes_valid_i_int; // one-shot valid to DOM unit
  logic        aes_valid_o_int; // done signal from DOM unit
  logic        aes_ready_int;   // DOM unit not busy
  logic [31:0] aes_result;      // DOM unit output

  // AES instruction detection (scalar 1-lane vs fused 2-lane)
  logic aes_is_scalar, aes_is_wide;
  assign aes_is_scalar = alu_en_i &
                    ((alu_operator_i == ALU_AES32ESI) |
                     (alu_operator_i == ALU_AES32ESMI));
  assign aes_is_wide = alu_en_i &
                    ((alu_operator_i == ALU_AES32ESI2) |
                     (alu_operator_i == ALU_AES32ESMI2));
  assign aes_insn = aes_is_scalar | aes_is_wide;

  // One-shot pulse: only fire valid_i on the FIRST cycle the AES instruction
  // is in EX, not during the stall cycles that follow
  assign aes_valid_i_int = aes_insn & ~aes_in_flight;

  // Track in-flight state: set when we fire valid_i, clear when done
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      aes_in_flight <= 1'b0;
    else if (aes_valid_i_int)
      aes_in_flight <= 1'b1;
    else if (aes_valid_o_int)
      aes_in_flight <= 1'b0;
  end

  // Latch which kind of AES op is in flight (selects the result source and
  // steers en_i to the active unit only)
  logic aes_wide_q;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)               aes_wide_q <= 1'b0;
    else if (aes_valid_i_int) aes_wide_q <= aes_is_wide;
  end

  logic        sc_valid_o, sc_ready, wd_valid_o, wd_ready;
  logic [31:0] sc_result, wd_result;
  wire         aes_en = aes_in_flight | aes_valid_i_int;

  // DOM-protected scalar AES32 unit (1 lane): handles ESI / ESMI
  cv32e40p_zkne_dom zkne_dom_i (
      .clk         (clk),
      .rst_n       (rst_n),
      .operator_i  (alu_operator_i),
      .operand_a_i (alu_operand_a_i),
      .operand_b_i (alu_operand_b_i),
      .bs_i        (imm_vec_ext_i),
      .en_i        (aes_en & ~(aes_is_wide | aes_wide_q)),
      .valid_i     (aes_valid_i_int & aes_is_scalar),
      .valid_o     (sc_valid_o),
      .ready_o     (sc_ready),
      .result_o    (sc_result)
  );

  // DOM-protected fused 2-lane AES unit: handles ESI2 / ESMI2
  cv32e40p_zkne_dom2 zkne_dom2_i (
      .clk         (clk),
      .rst_n       (rst_n),
      .operator_i  (alu_operator_i),
      .operand_a_i (alu_operand_a_i),
      .operand_b_i (alu_operand_b_i),
      .bs_i        (imm_vec_ext_i),
      .en_i        (aes_en & (aes_is_wide | aes_wide_q)),
      .valid_i     (aes_valid_i_int & aes_is_wide),
      .valid_o     (wd_valid_o),
      .ready_o     (wd_ready),
      .result_o    (wd_result)
  );

  assign aes_valid_o_int = sc_valid_o | wd_valid_o;
  assign aes_ready_int   = sc_ready & wd_ready;
  assign aes_result      = aes_wide_q ? wd_result : sc_result;

  // =========================================================================
  // ALU write port mux
  // When an AES instruction is in flight, hold the forwarded write-enable low
  // until aes_valid_o fires. On that cycle, forward the DOM result.
  // =========================================================================
  always_comb begin
    regfile_alu_wdata_fw_o = '0;
    regfile_alu_waddr_fw_o = '0;
    regfile_alu_we_fw_o    = '0;
    wb_contention          = 1'b0;

    if (apu_valid & (apu_singlecycle | apu_multicycle)) begin
      regfile_alu_we_fw_o    = 1'b1;
      regfile_alu_waddr_fw_o = apu_waddr;
      regfile_alu_wdata_fw_o = apu_result;

      if (regfile_alu_we_i & ~apu_en_i)
        wb_contention = 1'b1;

    end else if (aes_valid_o_int) begin
      // AES instruction just finished — forward its result this cycle
      regfile_alu_we_fw_o    = regfile_alu_we_i;
      regfile_alu_waddr_fw_o = regfile_alu_waddr_i;
      regfile_alu_wdata_fw_o = aes_result;

    end else begin
      // Normal ALU/MUL/CSR forwarding (AES holds we=0 while in-flight)
      regfile_alu_we_fw_o    = regfile_alu_we_i & ~apu_en_i & ~aes_in_flight;
      regfile_alu_waddr_fw_o = regfile_alu_waddr_i;
      if (alu_en_i)    regfile_alu_wdata_fw_o = alu_result;
      if (mult_en_i)   regfile_alu_wdata_fw_o = mult_result;
      if (csr_access_i) regfile_alu_wdata_fw_o = csr_rdata_i;
    end
  end

  // LSU write port mux (unchanged)
  always_comb begin
    regfile_we_wb_o    = 1'b0;
    regfile_waddr_wb_o = regfile_waddr_lsu;
    regfile_wdata_wb_o = lsu_rdata_i;
    wb_contention_lsu  = 1'b0;

    if (regfile_we_lsu) begin
      regfile_we_wb_o = 1'b1;
      if (apu_valid & (!apu_singlecycle & !apu_multicycle))
        wb_contention_lsu = 1'b1;
    end else if (apu_valid & (!apu_singlecycle & !apu_multicycle)) begin
      regfile_we_wb_o    = 1'b1;
      regfile_waddr_wb_o = apu_waddr;
      regfile_wdata_wb_o = apu_result;
    end
  end

  assign branch_decision_o = alu_cmp_result;
  assign jump_target_o     = alu_operand_c_i;

  ////////////////////////////
  //        ALU             //
  ////////////////////////////

  cv32e40p_alu alu_i (
      .clk        (clk),
      .rst_n      (rst_n),
      .enable_i   (alu_en_i),
      .operator_i (alu_operator_i),
      .operand_a_i(alu_operand_a_i),
      .operand_b_i(alu_operand_b_i),
      .operand_c_i(alu_operand_c_i),

      .vector_mode_i(alu_vec_mode_i),
      .bmask_a_i    (bmask_a_i),
      .bmask_b_i    (bmask_b_i),
      .imm_vec_ext_i(imm_vec_ext_i),

      .is_clpx_i   (alu_is_clpx_i),
      .clpx_shift_i(alu_clpx_shift_i),
      .is_subrot_i (alu_is_subrot_i),

      .result_o           (alu_result),
      .comparison_result_o(alu_cmp_result),

      .ready_o   (alu_ready),
      .ex_ready_i(ex_ready_o)
  );

  ////////////////////////////
  //     MULTIPLIER         //
  ////////////////////////////

  cv32e40p_mult mult_i (
      .clk  (clk),
      .rst_n(rst_n),

      .enable_i  (mult_en_i),
      .operator_i(mult_operator_i),

      .short_subword_i(mult_sel_subword_i),
      .short_signed_i (mult_signed_mode_i),

      .op_a_i(mult_operand_a_i),
      .op_b_i(mult_operand_b_i),
      .op_c_i(mult_operand_c_i),
      .imm_i (mult_imm_i),

      .dot_op_a_i  (mult_dot_op_a_i),
      .dot_op_b_i  (mult_dot_op_b_i),
      .dot_op_c_i  (mult_dot_op_c_i),
      .dot_signed_i(mult_dot_signed_i),
      .is_clpx_i   (mult_is_clpx_i),
      .clpx_shift_i(mult_clpx_shift_i),
      .clpx_img_i  (mult_clpx_img_i),

      .result_o(mult_result),

      .multicycle_o(mult_multicycle_o),
      .ready_o     (mult_ready),
      .ex_ready_i  (ex_ready_o)
  );

  generate
    if (FPU == 1) begin : gen_apu
      cv32e40p_apu_disp apu_disp_i (
          .clk_i (clk),
          .rst_ni(rst_n),

          .enable_i   (apu_en_i),
          .apu_lat_i  (apu_lat_i),
          .apu_waddr_i(apu_waddr_i),

          .apu_waddr_o      (apu_waddr),
          .apu_multicycle_o (apu_multicycle),
          .apu_singlecycle_o(apu_singlecycle),

          .active_o(apu_active),
          .stall_o (apu_stall),

          .is_decoding_i     (is_decoding_i),
          .read_regs_i       (apu_read_regs_i),
          .read_regs_valid_i (apu_read_regs_valid_i),
          .read_dep_o        (apu_read_dep_o),
          .write_regs_i      (apu_write_regs_i),
          .write_regs_valid_i(apu_write_regs_valid_i),
          .write_dep_o       (apu_write_dep_o),

          .perf_type_o(apu_perf_type_o),
          .perf_cont_o(apu_perf_cont_o),

          .apu_req_o   (apu_req),
          .apu_gnt_i   (apu_gnt),
          .apu_rvalid_i(apu_valid)
      );

      assign apu_perf_wb_o   = wb_contention | wb_contention_lsu;
      assign apu_ready_wb_o  = ~(apu_active | apu_en_i | apu_stall) | apu_valid;
      assign apu_req_o       = apu_req;
      assign apu_gnt         = apu_gnt_i;
      assign apu_valid       = apu_rvalid_i;
      assign apu_operands_o  = apu_operands_i;
      assign apu_op_o        = apu_op_i;
      assign apu_result      = apu_result_i;
      assign fpu_fflags_we_o = apu_valid;

    end else begin : gen_no_apu
      assign apu_req_o         = '0;
      assign apu_operands_o[0] = '0;
      assign apu_operands_o[1] = '0;
      assign apu_operands_o[2] = '0;
      assign apu_op_o          = '0;
      assign apu_req           = 1'b0;
      assign apu_gnt           = 1'b0;
      assign apu_result        = 32'b0;
      assign apu_valid         = 1'b0;
      assign apu_waddr         = 6'b0;
      assign apu_stall         = 1'b0;
      assign apu_active        = 1'b0;
      assign apu_ready_wb_o    = 1'b1;
      assign apu_perf_wb_o     = 1'b0;
      assign apu_perf_cont_o   = 1'b0;
      assign apu_perf_type_o   = 1'b0;
      assign apu_singlecycle   = 1'b0;
      assign apu_multicycle    = 1'b0;
      assign apu_read_dep_o    = 1'b0;
      assign apu_write_dep_o   = 1'b0;
      assign fpu_fflags_we_o   = 1'b0;
    end
  endgenerate

  assign apu_busy_o = apu_active;

  ///////////////////////////////////////
  // EX/WB Pipeline Register           //
  ///////////////////////////////////////
  always_ff @(posedge clk, negedge rst_n) begin : EX_WB_Pipeline_Register
    if (~rst_n) begin
      regfile_waddr_lsu <= '0;
      regfile_we_lsu    <= 1'b0;
    end else begin
      if (ex_valid_o) begin
        regfile_we_lsu <= regfile_we_i & ~lsu_err_i;
        if (regfile_we_i & ~lsu_err_i)
          regfile_waddr_lsu <= regfile_waddr_i;
      end else if (wb_ready_i) begin
        regfile_we_lsu <= 1'b0;
      end
    end
  end

  // =========================================================================
  // Stall and valid logic
  //
  // aes_in_flight causes ex_ready_o to go low, stalling the pipeline.
  // The stall lasts until aes_valid_o fires (3 extra cycles after valid_i).
  // On the cycle aes_valid_o fires, aes_in_flight clears and ex_ready_o
  // returns high, allowing the pipeline to advance and write back the result.
  //
  // Original ready logic kept intact; AES stall added via ~aes_in_flight term.
  // =========================================================================

  assign ex_ready_o = (~apu_stall & alu_ready & mult_ready & lsu_ready_ex_i
                      & wb_ready_i & ~wb_contention
                      & (~aes_insn | aes_valid_o_int))
                      | (branch_in_ex_i);

  assign ex_valid_o = (apu_valid | alu_en_i | mult_en_i | csr_access_i | lsu_en_i)
                      & (alu_ready & mult_ready & lsu_ready_ex_i & wb_ready_i)
                      & (~aes_insn | aes_valid_o_int);

endmodule