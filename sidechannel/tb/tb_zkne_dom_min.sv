`timescale 1ns/1ps

module tb_zkne_dom_min
  import cv32e40p_pkg::*;
();

  logic clk = 0;
  logic rst_n;
  always #5 clk = ~clk;

  alu_opcode_e operator;
  logic [31:0] op_a, op_b;
  logic [1:0]  bs;
  logic [31:0] result;
  logic        ready;

  cv32e40p_zkne dut (
    .clk         (clk),
    .rst_n       (rst_n),
    .operator_i  (operator),
    .operand_a_i (op_a),
    .operand_b_i (op_b),
    .bs_i        (bs),
    .result_o    (result),
    .ready_o     (ready)
  );

  initial begin
    rst_n    = 0;
    operator = ALU_ADD;
    op_a     = 0;
    op_b     = 0;
    bs       = 0;
    repeat (3) @(posedge clk);
    rst_n    = 1;
    @(negedge clk);

    operator = ALU_AES32ESI;
    op_b     = 32'h00000000;
    bs       = 0;
    repeat (10) @(posedge clk);
    $display("AES x=0x00 result=0x%08x  ready=%0d  (expect lower 8 == 0x63 when ready=1)", result, ready);
    $finish;
  end
endmodule
