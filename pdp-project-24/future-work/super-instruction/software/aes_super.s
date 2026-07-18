	.attribute	4, 16
	.attribute	5, "rv32i2p1_m2p0_c2p0_zmmul1p0_zca1p0_zkne1p0"
	.file	"main.c"
	.text
	.globl	expand_key                      # -- Begin function expand_key
	.p2align	1
	.type	expand_key,@function
expand_key:                             # @expand_key
# %bb.0:
	addi	sp, sp, -32
	sw	ra, 28(sp)                      # 4-byte Folded Spill
	sw	s0, 24(sp)                      # 4-byte Folded Spill
	addi	s0, sp, 32
	sw	a0, 20(sp)
	sw	a1, 16(sp)
	li	a0, 0
	sw	a0, 12(sp)
	j	.LBB0_1
.LBB0_1:                                # =>This Inner Loop Header: Depth=1
	lw	a1, 12(sp)
	li	a0, 15
	blt	a0, a1, .LBB0_4
	j	.LBB0_2
.LBB0_2:                                #   in Loop: Header=BB0_1 Depth=1
	lw	a0, 20(sp)
	lw	a2, 12(sp)
	add	a0, a0, a2
	lbu	a0, 0(a0)
	lw	a1, 16(sp)
	add	a1, a1, a2
	sb	a0, 0(a1)
	j	.LBB0_3
.LBB0_3:                                #   in Loop: Header=BB0_1 Depth=1
	lw	a0, 12(sp)
	addi	a0, a0, 1
	sw	a0, 12(sp)
	j	.LBB0_1
.LBB0_4:
	li	a0, 16
	sw	a0, 12(sp)
	j	.LBB0_5
.LBB0_5:                                # =>This Inner Loop Header: Depth=1
	lw	a1, 12(sp)
	li	a0, 175
	blt	a0, a1, .LBB0_10
	j	.LBB0_6
.LBB0_6:                                #   in Loop: Header=BB0_5 Depth=1
	lw	a1, 16(sp)
	lw	a0, 12(sp)
	add	a0, a0, a1
	lbu	a0, -4(a0)
	sb	a0, 8(sp)
	lw	a1, 16(sp)
	lw	a0, 12(sp)
	add	a0, a0, a1
	lbu	a0, -3(a0)
	sb	a0, 9(sp)
	lw	a1, 16(sp)
	lw	a0, 12(sp)
	add	a0, a0, a1
	lbu	a0, -2(a0)
	sb	a0, 10(sp)
	lw	a1, 16(sp)
	lw	a0, 12(sp)
	add	a0, a0, a1
	lbu	a0, -1(a0)
	sb	a0, 11(sp)
	lw	a0, 12(sp)
	srai	a1, a0, 31
	srli	a1, a1, 28
	add	a1, a1, a0
	andi	a1, a1, -16
	sub	a0, a0, a1
	bnez	a0, .LBB0_8
	j	.LBB0_7
.LBB0_7:                                #   in Loop: Header=BB0_5 Depth=1
	lbu	a0, 8(sp)
	sb	a0, 7(sp)
	lbu	a1, 9(sp)
	lui	a0, %hi(sbox)
	addi	a0, a0, %lo(sbox)
	add	a1, a1, a0
	lbu	a1, 0(a1)
	sb	a1, 8(sp)
	lbu	a1, 10(sp)
	add	a1, a1, a0
	lbu	a1, 0(a1)
	sb	a1, 9(sp)
	lbu	a1, 11(sp)
	add	a1, a1, a0
	lbu	a1, 0(a1)
	sb	a1, 10(sp)
	lbu	a1, 7(sp)
	add	a0, a0, a1
	lbu	a0, 0(a0)
	sb	a0, 11(sp)
	lw	a0, 12(sp)
	srai	a1, a0, 31
	srli	a1, a1, 28
	add	a0, a0, a1
	srai	a0, a0, 4
	lui	a1, %hi(rcon)
	addi	a1, a1, %lo(rcon)
	add	a0, a0, a1
	lbu	a1, -1(a0)
	lbu	a0, 8(sp)
	xor	a0, a0, a1
	sb	a0, 8(sp)
	j	.LBB0_8
.LBB0_8:                                #   in Loop: Header=BB0_5 Depth=1
	lw	a0, 16(sp)
	lw	a1, 12(sp)
	add	a1, a1, a0
	lbu	a0, -16(a1)
	lbu	a2, 8(sp)
	xor	a0, a0, a2
	sb	a0, 0(a1)
	lw	a1, 16(sp)
	lw	a0, 12(sp)
	add	a1, a1, a0
	lbu	a0, -15(a1)
	lbu	a2, 9(sp)
	xor	a0, a0, a2
	sb	a0, 1(a1)
	lw	a1, 16(sp)
	lw	a0, 12(sp)
	add	a1, a1, a0
	lbu	a0, -14(a1)
	lbu	a2, 10(sp)
	xor	a0, a0, a2
	sb	a0, 2(a1)
	lw	a1, 16(sp)
	lw	a0, 12(sp)
	add	a1, a1, a0
	lbu	a0, -13(a1)
	lbu	a2, 11(sp)
	xor	a0, a0, a2
	sb	a0, 3(a1)
	j	.LBB0_9
.LBB0_9:                                #   in Loop: Header=BB0_5 Depth=1
	lw	a0, 12(sp)
	addi	a0, a0, 4
	sw	a0, 12(sp)
	j	.LBB0_5
.LBB0_10:
	lw	ra, 28(sp)                      # 4-byte Folded Reload
	lw	s0, 24(sp)                      # 4-byte Folded Reload
	addi	sp, sp, 32
	ret
.Lfunc_end0:
	.size	expand_key, .Lfunc_end0-expand_key
                                        # -- End function
	.globl	sub_bytes                       # -- Begin function sub_bytes
	.p2align	1
	.type	sub_bytes,@function
sub_bytes:                              # @sub_bytes
# %bb.0:
	addi	sp, sp, -16
	sw	ra, 12(sp)                      # 4-byte Folded Spill
	sw	s0, 8(sp)                       # 4-byte Folded Spill
	addi	s0, sp, 16
	sw	a0, 4(sp)
	li	a0, 0
	sw	a0, 0(sp)
	j	.LBB1_1
.LBB1_1:                                # =>This Inner Loop Header: Depth=1
	lw	a1, 0(sp)
	li	a0, 15
	blt	a0, a1, .LBB1_4
	j	.LBB1_2
.LBB1_2:                                #   in Loop: Header=BB1_1 Depth=1
	lw	a0, 4(sp)
	lw	a1, 0(sp)
	add	a1, a1, a0
	lbu	a2, 0(a1)
	lui	a0, %hi(sbox)
	addi	a0, a0, %lo(sbox)
	add	a0, a0, a2
	lbu	a0, 0(a0)
	sb	a0, 0(a1)
	j	.LBB1_3
.LBB1_3:                                #   in Loop: Header=BB1_1 Depth=1
	lw	a0, 0(sp)
	addi	a0, a0, 1
	sw	a0, 0(sp)
	j	.LBB1_1
.LBB1_4:
	lw	ra, 12(sp)                      # 4-byte Folded Reload
	lw	s0, 8(sp)                       # 4-byte Folded Reload
	addi	sp, sp, 16
	ret
.Lfunc_end1:
	.size	sub_bytes, .Lfunc_end1-sub_bytes
                                        # -- End function
	.globl	shift_rows                      # -- Begin function shift_rows
	.p2align	1
	.type	shift_rows,@function
shift_rows:                             # @shift_rows
# %bb.0:
	addi	sp, sp, -16
	sw	ra, 12(sp)                      # 4-byte Folded Spill
	sw	s0, 8(sp)                       # 4-byte Folded Spill
	addi	s0, sp, 16
	sw	a0, 4(sp)
	lw	a0, 4(sp)
	lbu	a0, 1(a0)
	sb	a0, 3(sp)
	lw	a1, 4(sp)
	lbu	a0, 5(a1)
	sb	a0, 1(a1)
	lw	a1, 4(sp)
	lbu	a0, 9(a1)
	sb	a0, 5(a1)
	lw	a1, 4(sp)
	lbu	a0, 13(a1)
	sb	a0, 9(a1)
	lbu	a0, 3(sp)
	lw	a1, 4(sp)
	sb	a0, 13(a1)
	lw	a0, 4(sp)
	lbu	a0, 2(a0)
	sb	a0, 3(sp)
	lw	a1, 4(sp)
	lbu	a0, 10(a1)
	sb	a0, 2(a1)
	lbu	a0, 3(sp)
	lw	a1, 4(sp)
	sb	a0, 10(a1)
	lw	a0, 4(sp)
	lbu	a0, 6(a0)
	sb	a0, 3(sp)
	lw	a1, 4(sp)
	lbu	a0, 14(a1)
	sb	a0, 6(a1)
	lbu	a0, 3(sp)
	lw	a1, 4(sp)
	sb	a0, 14(a1)
	lw	a0, 4(sp)
	lbu	a0, 15(a0)
	sb	a0, 3(sp)
	lw	a1, 4(sp)
	lbu	a0, 11(a1)
	sb	a0, 15(a1)
	lw	a1, 4(sp)
	lbu	a0, 7(a1)
	sb	a0, 11(a1)
	lw	a1, 4(sp)
	lbu	a0, 3(a1)
	sb	a0, 7(a1)
	lbu	a0, 3(sp)
	lw	a1, 4(sp)
	sb	a0, 3(a1)
	lw	ra, 12(sp)                      # 4-byte Folded Reload
	lw	s0, 8(sp)                       # 4-byte Folded Reload
	addi	sp, sp, 16
	ret
.Lfunc_end2:
	.size	shift_rows, .Lfunc_end2-shift_rows
                                        # -- End function
	.globl	gf_mult                         # -- Begin function gf_mult
	.p2align	1
	.type	gf_mult,@function
gf_mult:                                # @gf_mult
# %bb.0:
	addi	sp, sp, -32
	sw	ra, 28(sp)                      # 4-byte Folded Spill
	sw	s0, 24(sp)                      # 4-byte Folded Spill
	addi	s0, sp, 32
                                        # kill: def $x12 killed $x11
                                        # kill: def $x12 killed $x10
	sb	a0, 23(sp)
	sb	a1, 22(sp)
	li	a0, 0
	sb	a0, 21(sp)
	sw	a0, 16(sp)
	j	.LBB3_1
.LBB3_1:                                # =>This Inner Loop Header: Depth=1
	lw	a1, 16(sp)
	li	a0, 7
	blt	a0, a1, .LBB3_8
	j	.LBB3_2
.LBB3_2:                                #   in Loop: Header=BB3_1 Depth=1
	lbu	a0, 22(sp)
	andi	a0, a0, 1
	beqz	a0, .LBB3_4
	j	.LBB3_3
.LBB3_3:                                #   in Loop: Header=BB3_1 Depth=1
	lbu	a1, 23(sp)
	lbu	a0, 21(sp)
	xor	a0, a0, a1
	sb	a0, 21(sp)
	j	.LBB3_4
.LBB3_4:                                #   in Loop: Header=BB3_1 Depth=1
	lbu	a0, 23(sp)
	andi	a0, a0, 128
	sb	a0, 15(sp)
	lbu	a0, 23(sp)
	slli	a0, a0, 1
	sb	a0, 23(sp)
	lbu	a0, 15(sp)
	beqz	a0, .LBB3_6
	j	.LBB3_5
.LBB3_5:                                #   in Loop: Header=BB3_1 Depth=1
	lbu	a0, 23(sp)
	xori	a0, a0, 27
	sb	a0, 23(sp)
	j	.LBB3_6
.LBB3_6:                                #   in Loop: Header=BB3_1 Depth=1
	lbu	a0, 22(sp)
	srli	a0, a0, 1
	sb	a0, 22(sp)
	j	.LBB3_7
.LBB3_7:                                #   in Loop: Header=BB3_1 Depth=1
	lw	a0, 16(sp)
	addi	a0, a0, 1
	sw	a0, 16(sp)
	j	.LBB3_1
.LBB3_8:
	lbu	a0, 21(sp)
	lw	ra, 28(sp)                      # 4-byte Folded Reload
	lw	s0, 24(sp)                      # 4-byte Folded Reload
	addi	sp, sp, 32
	ret
.Lfunc_end3:
	.size	gf_mult, .Lfunc_end3-gf_mult
                                        # -- End function
	.globl	mix_columns                     # -- Begin function mix_columns
	.p2align	1
	.type	mix_columns,@function
mix_columns:                            # @mix_columns
# %bb.0:
	addi	sp, sp, -80
	sw	ra, 76(sp)                      # 4-byte Folded Spill
	sw	s0, 72(sp)                      # 4-byte Folded Spill
	addi	s0, sp, 80
	sw	a0, 68(sp)
	li	a0, 0
	sw	a0, 48(sp)
	j	.LBB4_1
.LBB4_1:                                # =>This Inner Loop Header: Depth=1
	lw	a1, 48(sp)
	li	a0, 3
	blt	a0, a1, .LBB4_4
	j	.LBB4_2
.LBB4_2:                                #   in Loop: Header=BB4_1 Depth=1
	lw	a0, 48(sp)
	slli	a0, a0, 2
	sw	a0, 44(sp)
	lw	a0, 68(sp)
	lw	a1, 44(sp)
	add	a0, a0, a1
	lbu	a1, 0(a0)
	li	a0, 2
	sw	a0, 28(sp)                      # 4-byte Folded Spill
	call	gf_mult
	sw	a0, 4(sp)                       # 4-byte Folded Spill
	lw	a1, 68(sp)
	lw	a0, 44(sp)
	add	a0, a0, a1
	lbu	a1, 1(a0)
	li	a0, 3
	sw	a0, 24(sp)                      # 4-byte Folded Spill
	call	gf_mult
	lw	a1, 4(sp)                       # 4-byte Folded Reload
	mv	a2, a0
	lw	a0, 28(sp)                      # 4-byte Folded Reload
	xor	a1, a1, a2
	lw	a2, 68(sp)
	lw	a3, 44(sp)
	add	a2, a2, a3
	lbu	a4, 2(a2)
	xor	a1, a1, a4
	lbu	a2, 3(a2)
	xor	a1, a1, a2
	addi	a2, sp, 52
	sw	a2, 32(sp)                      # 4-byte Folded Spill
	add	a2, a2, a3
	sb	a1, 0(a2)
	lw	a1, 68(sp)
	lw	a2, 44(sp)
	add	a1, a1, a2
	lbu	a2, 0(a1)
	sw	a2, 8(sp)                       # 4-byte Folded Spill
	lbu	a1, 1(a1)
	call	gf_mult
	lw	a1, 8(sp)                       # 4-byte Folded Reload
	mv	a2, a0
	lw	a0, 24(sp)                      # 4-byte Folded Reload
	xor	a1, a1, a2
	sw	a1, 12(sp)                      # 4-byte Folded Spill
	lw	a2, 68(sp)
	lw	a1, 44(sp)
	add	a1, a1, a2
	lbu	a1, 2(a1)
	call	gf_mult
	lw	a1, 12(sp)                      # 4-byte Folded Reload
	lw	a3, 32(sp)                      # 4-byte Folded Reload
	mv	a2, a0
	lw	a0, 28(sp)                      # 4-byte Folded Reload
	xor	a1, a1, a2
	lw	a4, 68(sp)
	lw	a2, 44(sp)
	add	a4, a4, a2
	lbu	a4, 3(a4)
	xor	a1, a1, a4
	add	a2, a2, a3
	sb	a1, 1(a2)
	lw	a1, 68(sp)
	lw	a2, 44(sp)
	add	a1, a1, a2
	lbu	a2, 0(a1)
	lbu	a3, 1(a1)
	xor	a2, a2, a3
	sw	a2, 16(sp)                      # 4-byte Folded Spill
	lbu	a1, 2(a1)
	call	gf_mult
	lw	a1, 16(sp)                      # 4-byte Folded Reload
	mv	a2, a0
	lw	a0, 24(sp)                      # 4-byte Folded Reload
	xor	a1, a1, a2
	sw	a1, 20(sp)                      # 4-byte Folded Spill
	lw	a2, 68(sp)
	lw	a1, 44(sp)
	add	a1, a1, a2
	lbu	a1, 3(a1)
	call	gf_mult
	lw	a1, 20(sp)                      # 4-byte Folded Reload
	lw	a3, 32(sp)                      # 4-byte Folded Reload
	mv	a2, a0
	lw	a0, 24(sp)                      # 4-byte Folded Reload
	xor	a1, a1, a2
	lw	a2, 44(sp)
	add	a2, a2, a3
	sb	a1, 2(a2)
	lw	a1, 68(sp)
	lw	a2, 44(sp)
	add	a1, a1, a2
	lbu	a1, 0(a1)
	call	gf_mult
	mv	a2, a0
	lw	a0, 28(sp)                      # 4-byte Folded Reload
	lw	a3, 68(sp)
	lw	a1, 44(sp)
	add	a1, a1, a3
	lbu	a3, 1(a1)
	xor	a2, a2, a3
	lbu	a3, 2(a1)
	xor	a2, a2, a3
	sw	a2, 36(sp)                      # 4-byte Folded Spill
	lbu	a1, 3(a1)
	call	gf_mult
	lw	a2, 32(sp)                      # 4-byte Folded Reload
	mv	a1, a0
	lw	a0, 36(sp)                      # 4-byte Folded Reload
	xor	a0, a0, a1
	lw	a1, 44(sp)
	add	a1, a1, a2
	sb	a0, 3(a1)
	j	.LBB4_3
.LBB4_3:                                #   in Loop: Header=BB4_1 Depth=1
	lw	a0, 48(sp)
	addi	a0, a0, 1
	sw	a0, 48(sp)
	j	.LBB4_1
.LBB4_4:
	li	a0, 0
	sw	a0, 40(sp)
	j	.LBB4_5
.LBB4_5:                                # =>This Inner Loop Header: Depth=1
	lw	a1, 40(sp)
	li	a0, 15
	blt	a0, a1, .LBB4_8
	j	.LBB4_6
.LBB4_6:                                #   in Loop: Header=BB4_5 Depth=1
	lw	a2, 40(sp)
	addi	a0, sp, 52
	add	a0, a0, a2
	lbu	a0, 0(a0)
	lw	a1, 68(sp)
	add	a1, a1, a2
	sb	a0, 0(a1)
	j	.LBB4_7
.LBB4_7:                                #   in Loop: Header=BB4_5 Depth=1
	lw	a0, 40(sp)
	addi	a0, a0, 1
	sw	a0, 40(sp)
	j	.LBB4_5
.LBB4_8:
	lw	ra, 76(sp)                      # 4-byte Folded Reload
	lw	s0, 72(sp)                      # 4-byte Folded Reload
	addi	sp, sp, 80
	ret
.Lfunc_end4:
	.size	mix_columns, .Lfunc_end4-mix_columns
                                        # -- End function
	.globl	add_round_key                   # -- Begin function add_round_key
	.p2align	1
	.type	add_round_key,@function
add_round_key:                          # @add_round_key
# %bb.0:
	addi	sp, sp, -32
	sw	ra, 28(sp)                      # 4-byte Folded Spill
	sw	s0, 24(sp)                      # 4-byte Folded Spill
	addi	s0, sp, 32
	sw	a0, 20(sp)
	sw	a1, 16(sp)
	li	a0, 0
	sw	a0, 12(sp)
	j	.LBB5_1
.LBB5_1:                                # =>This Inner Loop Header: Depth=1
	lw	a1, 12(sp)
	li	a0, 15
	blt	a0, a1, .LBB5_4
	j	.LBB5_2
.LBB5_2:                                #   in Loop: Header=BB5_1 Depth=1
	lw	a0, 16(sp)
	lw	a1, 12(sp)
	add	a0, a0, a1
	lbu	a2, 0(a0)
	lw	a0, 20(sp)
	add	a1, a1, a0
	lbu	a0, 0(a1)
	xor	a0, a0, a2
	sb	a0, 0(a1)
	j	.LBB5_3
.LBB5_3:                                #   in Loop: Header=BB5_1 Depth=1
	lw	a0, 12(sp)
	addi	a0, a0, 1
	sw	a0, 12(sp)
	j	.LBB5_1
.LBB5_4:
	lw	ra, 28(sp)                      # 4-byte Folded Reload
	lw	s0, 24(sp)                      # 4-byte Folded Reload
	addi	sp, sp, 32
	ret
.Lfunc_end5:
	.size	add_round_key, .Lfunc_end5-add_round_key
                                        # -- End function
	.globl	aes128_encrypt_block            # -- Begin function aes128_encrypt_block
	.p2align	1
	.type	aes128_encrypt_block,@function
aes128_encrypt_block:                   # @aes128_encrypt_block
# %bb.0:
	addi	sp, sp, -96
	sw	ra, 92(sp)                      # 4-byte Folded Spill
	sw	s0, 88(sp)                      # 4-byte Folded Spill
	addi	s0, sp, 96
	sw	a0, 84(sp)
	sw	a1, 80(sp)
	sw	a2, 76(sp)
	lw	a0, 84(sp)
	sw	a0, 56(sp)
	lw	a0, 56(sp)
	lw	a0, 0(a0)
	sw	a0, 72(sp)
	lw	a0, 56(sp)
	lw	a0, 4(a0)
	sw	a0, 68(sp)
	lw	a0, 56(sp)
	lw	a0, 8(a0)
	sw	a0, 64(sp)
	lw	a0, 56(sp)
	lw	a0, 12(a0)
	sw	a0, 60(sp)
	lw	a0, 80(sp)
	sw	a0, 52(sp)
	lw	a0, 52(sp)
	lw	a1, 0(a0)
	lw	a0, 72(sp)
	xor	a0, a0, a1
	sw	a0, 72(sp)
	lw	a0, 52(sp)
	lw	a1, 4(a0)
	lw	a0, 68(sp)
	xor	a0, a0, a1
	sw	a0, 68(sp)
	lw	a0, 52(sp)
	lw	a1, 8(a0)
	lw	a0, 64(sp)
	xor	a0, a0, a1
	sw	a0, 64(sp)
	lw	a0, 52(sp)
	lw	a1, 12(a0)
	lw	a0, 60(sp)
	xor	a0, a0, a1
	sw	a0, 60(sp)
	li	a0, 1
	sw	a0, 48(sp)
	j	.LBB6_1
.LBB6_1:                                # =>This Inner Loop Header: Depth=1
	lw	a1, 48(sp)
	li	a0, 9
	blt	a0, a1, .LBB6_4
	j	.LBB6_2
.LBB6_2:                                #   in Loop: Header=BB6_1 Depth=1
	lw	a0, 72(sp)
	lw	a1, 68(sp)
	lw	a2, 64(sp)
	lw	a3, 60(sp)
	#APP
	aes32esmi_super	a0, a0, a1, a2, a3
	#NO_APP
	sw	a0, 44(sp)
	lw	a0, 68(sp)
	lw	a1, 64(sp)
	lw	a2, 60(sp)
	lw	a3, 72(sp)
	#APP
	aes32esmi_super	a0, a0, a1, a2, a3
	#NO_APP
	sw	a0, 40(sp)
	lw	a0, 64(sp)
	lw	a1, 60(sp)
	lw	a2, 72(sp)
	lw	a3, 68(sp)
	#APP
	aes32esmi_super	a0, a0, a1, a2, a3
	#NO_APP
	sw	a0, 36(sp)
	lw	a0, 60(sp)
	lw	a1, 72(sp)
	lw	a2, 68(sp)
	lw	a3, 64(sp)
	#APP
	aes32esmi_super	a0, a0, a1, a2, a3
	#NO_APP
	sw	a0, 32(sp)
	lw	a0, 52(sp)
	addi	a0, a0, 16
	sw	a0, 52(sp)
	lw	a0, 44(sp)
	lw	a1, 52(sp)
	lw	a1, 0(a1)
	xor	a0, a0, a1
	sw	a0, 72(sp)
	lw	a0, 40(sp)
	lw	a1, 52(sp)
	lw	a1, 4(a1)
	xor	a0, a0, a1
	sw	a0, 68(sp)
	lw	a0, 36(sp)
	lw	a1, 52(sp)
	lw	a1, 8(a1)
	xor	a0, a0, a1
	sw	a0, 64(sp)
	lw	a0, 32(sp)
	lw	a1, 52(sp)
	lw	a1, 12(a1)
	xor	a0, a0, a1
	sw	a0, 60(sp)
	j	.LBB6_3
.LBB6_3:                                #   in Loop: Header=BB6_1 Depth=1
	lw	a0, 48(sp)
	addi	a0, a0, 1
	sw	a0, 48(sp)
	j	.LBB6_1
.LBB6_4:
	lw	a0, 72(sp)
	lw	a1, 68(sp)
	lw	a2, 64(sp)
	lw	a3, 60(sp)
	#APP
	aes32esi_super	a0, a0, a1, a2, a3
	#NO_APP
	sw	a0, 28(sp)
	lw	a0, 68(sp)
	lw	a1, 64(sp)
	lw	a2, 60(sp)
	lw	a3, 72(sp)
	#APP
	aes32esi_super	a0, a0, a1, a2, a3
	#NO_APP
	sw	a0, 24(sp)
	lw	a0, 64(sp)
	lw	a1, 60(sp)
	lw	a2, 72(sp)
	lw	a3, 68(sp)
	#APP
	aes32esi_super	a0, a0, a1, a2, a3
	#NO_APP
	sw	a0, 20(sp)
	lw	a0, 60(sp)
	lw	a1, 72(sp)
	lw	a2, 68(sp)
	lw	a3, 64(sp)
	#APP
	aes32esi_super	a0, a0, a1, a2, a3
	#NO_APP
	sw	a0, 16(sp)
	lw	a0, 52(sp)
	addi	a0, a0, 16
	sw	a0, 52(sp)
	lw	a0, 52(sp)
	lw	a1, 0(a0)
	lw	a0, 28(sp)
	xor	a0, a0, a1
	sw	a0, 28(sp)
	lw	a0, 52(sp)
	lw	a1, 4(a0)
	lw	a0, 24(sp)
	xor	a0, a0, a1
	sw	a0, 24(sp)
	lw	a0, 52(sp)
	lw	a1, 8(a0)
	lw	a0, 20(sp)
	xor	a0, a0, a1
	sw	a0, 20(sp)
	lw	a0, 52(sp)
	lw	a1, 12(a0)
	lw	a0, 16(sp)
	xor	a0, a0, a1
	sw	a0, 16(sp)
	lw	a0, 76(sp)
	sw	a0, 12(sp)
	lw	a0, 28(sp)
	lw	a1, 12(sp)
	sw	a0, 0(a1)
	lw	a0, 24(sp)
	lw	a1, 12(sp)
	sw	a0, 4(a1)
	lw	a0, 20(sp)
	lw	a1, 12(sp)
	sw	a0, 8(a1)
	lw	a0, 16(sp)
	lw	a1, 12(sp)
	sw	a0, 12(a1)
	lw	ra, 92(sp)                      # 4-byte Folded Reload
	lw	s0, 88(sp)                      # 4-byte Folded Reload
	addi	sp, sp, 96
	ret
.Lfunc_end6:
	.size	aes128_encrypt_block, .Lfunc_end6-aes128_encrypt_block
                                        # -- End function
	.globl	aes128_ecb_encrypt              # -- Begin function aes128_ecb_encrypt
	.p2align	1
	.type	aes128_ecb_encrypt,@function
aes128_ecb_encrypt:                     # @aes128_ecb_encrypt
# %bb.0:
	addi	sp, sp, -208
	sw	ra, 204(sp)                     # 4-byte Folded Spill
	sw	s0, 200(sp)                     # 4-byte Folded Spill
	addi	s0, sp, 208
	sw	a0, 196(sp)
	sw	a1, 192(sp)
	sw	a2, 188(sp)
	sw	a3, 184(sp)
	lbu	a0, 192(sp)
	andi	a0, a0, 15
	beqz	a0, .LBB7_2
	j	.LBB7_1
.LBB7_1:
	j	.LBB7_6
.LBB7_2:
	lw	a0, 188(sp)
	addi	a1, sp, 8
	call	expand_key
	li	a0, 0
	sw	a0, 4(sp)
	j	.LBB7_3
.LBB7_3:                                # =>This Inner Loop Header: Depth=1
	lw	a0, 4(sp)
	lw	a1, 192(sp)
	bgeu	a0, a1, .LBB7_6
	j	.LBB7_4
.LBB7_4:                                #   in Loop: Header=BB7_3 Depth=1
	lw	a0, 196(sp)
	lw	a2, 4(sp)
	add	a0, a0, a2
	lw	a1, 184(sp)
	add	a2, a2, a1
	addi	a1, sp, 8
	call	aes128_encrypt_block
	j	.LBB7_5
.LBB7_5:                                #   in Loop: Header=BB7_3 Depth=1
	lw	a0, 4(sp)
	addi	a0, a0, 16
	sw	a0, 4(sp)
	j	.LBB7_3
.LBB7_6:
	lw	ra, 204(sp)                     # 4-byte Folded Reload
	lw	s0, 200(sp)                     # 4-byte Folded Reload
	addi	sp, sp, 208
	ret
.Lfunc_end7:
	.size	aes128_ecb_encrypt, .Lfunc_end7-aes128_ecb_encrypt
                                        # -- End function
	.globl	write_to_address                # -- Begin function write_to_address
	.p2align	1
	.type	write_to_address,@function
write_to_address:                       # @write_to_address
# %bb.0:
	addi	sp, sp, -16
	sw	ra, 12(sp)                      # 4-byte Folded Spill
	sw	s0, 8(sp)                       # 4-byte Folded Spill
	addi	s0, sp, 16
	sw	a0, 4(sp)
	sw	a1, 0(sp)
	lw	a0, 0(sp)
	lw	a1, 4(sp)
	sw	a0, 0(a1)
	lw	ra, 12(sp)                      # 4-byte Folded Reload
	lw	s0, 8(sp)                       # 4-byte Folded Reload
	addi	sp, sp, 16
	ret
.Lfunc_end8:
	.size	write_to_address, .Lfunc_end8-write_to_address
                                        # -- End function
	.globl	write_v_to_address              # -- Begin function write_v_to_address
	.p2align	1
	.type	write_v_to_address,@function
write_v_to_address:                     # @write_v_to_address
# %bb.0:
	addi	sp, sp, -32
	sw	ra, 28(sp)                      # 4-byte Folded Spill
	sw	s0, 24(sp)                      # 4-byte Folded Spill
	addi	s0, sp, 32
	sw	a0, 20(sp)
	sw	a1, 16(sp)
	lw	a0, 16(sp)
	sw	a0, 12(sp)
	li	a0, 0
	sw	a0, 8(sp)
	j	.LBB9_1
.LBB9_1:                                # =>This Inner Loop Header: Depth=1
	lw	a1, 8(sp)
	li	a0, 3
	blt	a0, a1, .LBB9_4
	j	.LBB9_2
.LBB9_2:                                #   in Loop: Header=BB9_1 Depth=1
	lw	a0, 20(sp)
	lw	a1, 8(sp)
	slli	a2, a1, 2
	add	a0, a0, a2
	lw	a1, 12(sp)
	add	a1, a1, a2
	lw	a1, 0(a1)
	call	write_to_address
	j	.LBB9_3
.LBB9_3:                                #   in Loop: Header=BB9_1 Depth=1
	lw	a0, 8(sp)
	addi	a0, a0, 1
	sw	a0, 8(sp)
	j	.LBB9_1
.LBB9_4:
	lw	ra, 28(sp)                      # 4-byte Folded Reload
	lw	s0, 24(sp)                      # 4-byte Folded Reload
	addi	sp, sp, 32
	ret
.Lfunc_end9:
	.size	write_v_to_address, .Lfunc_end9-write_v_to_address
                                        # -- End function
	.globl	main                            # -- Begin function main
	.p2align	1
	.type	main,@function
main:                                   # @main
# %bb.0:
	addi	sp, sp, -112
	sw	ra, 108(sp)                     # 4-byte Folded Spill
	sw	s0, 104(sp)                     # 4-byte Folded Spill
	addi	s0, sp, 112
	li	a0, 0
	sw	a0, 16(sp)                      # 4-byte Folded Spill
	sw	a0, 100(sp)
	lui	a0, 197379
	addi	a0, a0, 33
	sw	a0, 96(sp)
	lui	a0, 411335
	addi	a0, a0, 623
	sw	a0, 92(sp)
	lui	a0, 356867
	addi	a0, a0, -913
	sw	a0, 88(sp)
	lui	a0, 444102
	addi	a0, a0, 1352
	sw	a0, 84(sp)
	lui	a0, 411431
	addi	a0, a0, -137
	sw	a0, 80(sp)
	lui	a0, 472886
	addi	a0, a0, 368
	sw	a0, 76(sp)
	lui	a0, 197443
	addi	a0, a0, 52
	sw	a0, 72(sp)
	lui	a0, 415542
	addi	a0, a0, 1379
	sw	a0, 68(sp)
	lui	a0, 700305
	addi	a0, a0, -2033
	sw	a0, 64(sp)
	lui	a0, 189019
	addi	a0, a0, -1346
	sw	a0, 60(sp)
	lui	a0, 464063
	addi	a0, a0, 1055
	sw	a0, 56(sp)
	lui	a0, 1030737
	addi	a0, a0, -1772
	sw	a0, 52(sp)
	li	a0, 16
	sw	a0, 32(sp)
	lw	a1, 32(sp)
	addi	a0, sp, 84
	addi	a2, sp, 68
	addi	a3, sp, 36
	sw	a3, 8(sp)                       # 4-byte Folded Spill
	call	aes128_ecb_encrypt
	lui	a0, 258
	sw	a0, 12(sp)                      # 4-byte Folded Spill
	addi	a0, a0, 48
	sw	a0, 28(sp)
	lw	a0, 28(sp)
	addi	a1, sp, 52
	call	write_v_to_address
	lw	a1, 8(sp)                       # 4-byte Folded Reload
	lw	a0, 12(sp)                      # 4-byte Folded Reload
	addi	a0, a0, 64
	sw	a0, 28(sp)
	lw	a0, 28(sp)
	call	write_v_to_address
	lw	a1, 12(sp)                      # 4-byte Folded Reload
	lw	a0, 16(sp)                      # 4-byte Folded Reload
	addi	a1, a1, 4
	sw	a1, 28(sp)
	lui	a1, 831468
	addi	a1, a1, -1346
	sw	a1, 24(sp)
	sw	a0, 20(sp)
	j	.LBB10_1
.LBB10_1:                               # =>This Inner Loop Header: Depth=1
	lw	a1, 20(sp)
	li	a0, 15
	blt	a0, a1, .LBB10_6
	j	.LBB10_2
.LBB10_2:                               #   in Loop: Header=BB10_1 Depth=1
	lw	a2, 20(sp)
	addi	a0, sp, 36
	add	a0, a0, a2
	lbu	a0, 0(a0)
	addi	a1, sp, 52
	add	a1, a1, a2
	lbu	a1, 0(a1)
	beq	a0, a1, .LBB10_4
	j	.LBB10_3
.LBB10_3:
	lui	a0, 764587
	addi	a0, a0, -1363
	sw	a0, 24(sp)
	j	.LBB10_6
.LBB10_4:                               #   in Loop: Header=BB10_1 Depth=1
	j	.LBB10_5
.LBB10_5:                               #   in Loop: Header=BB10_1 Depth=1
	lw	a0, 20(sp)
	addi	a0, a0, 1
	sw	a0, 20(sp)
	j	.LBB10_1
.LBB10_6:
	lw	a0, 28(sp)
	lw	a1, 24(sp)
	call	write_to_address
	call	test_zkne
	lui	a0, 258
	sw	a0, 28(sp)
	lui	a0, 912092
	addi	a0, a0, -273
	sw	a0, 24(sp)
	lw	a0, 28(sp)
	lw	a1, 24(sp)
	call	write_to_address
	li	a0, 0
	lw	ra, 108(sp)                     # 4-byte Folded Reload
	lw	s0, 104(sp)                     # 4-byte Folded Reload
	addi	sp, sp, 112
	ret
.Lfunc_end10:
	.size	main, .Lfunc_end10-main
                                        # -- End function
	.p2align	1                               # -- Begin function test_zkne
	.type	test_zkne,@function
test_zkne:                              # @test_zkne
# %bb.0:
	addi	sp, sp, -64
	sw	ra, 60(sp)                      # 4-byte Folded Spill
	sw	s0, 56(sp)                      # 4-byte Folded Spill
	addi	s0, sp, 64
	lui	a0, 74565
	addi	a0, a0, 1656
	sw	a0, 52(sp)
	lui	a1, 699325
	addi	a4, a1, -803
	sw	a4, 48(sp)
	li	a1, 1
	sw	a1, 44(sp)
	mv	a1, a0
	mv	a2, a4
	mv	a3, a4
	mv	a5, a4
	#APP
	aes32esi_super	a1, a1, a2, a3, a5
	#NO_APP
	sw	a1, 40(sp)
	mv	a1, a0
	mv	a2, a4
	mv	a3, a4
	#APP
	aes32esmi_super	a1, a1, a2, a3, a4
	#NO_APP
	sw	a1, 36(sp)
	sw	a0, 32(sp)
	sw	a0, 28(sp)
	li	a0, 0
	sw	a0, 24(sp)
	j	.LBB11_1
.LBB11_1:                               # =>This Inner Loop Header: Depth=1
	lw	a1, 24(sp)
	li	a0, 3
	blt	a0, a1, .LBB11_4
	j	.LBB11_2
.LBB11_2:                               #   in Loop: Header=BB11_1 Depth=1
	lw	a0, 32(sp)
	lw	a2, 24(sp)
	lui	a1, 699325
	addi	a1, a1, -803
	sw	a1, 16(sp)                      # 4-byte Folded Spill
	call	sw_aes32esi
	lw	a1, 16(sp)                      # 4-byte Folded Reload
	sw	a0, 32(sp)
	lw	a0, 28(sp)
	lw	a2, 24(sp)
	call	sw_aes32esmi
	sw	a0, 28(sp)
	j	.LBB11_3
.LBB11_3:                               #   in Loop: Header=BB11_1 Depth=1
	lw	a0, 24(sp)
	addi	a0, a0, 1
	sw	a0, 24(sp)
	j	.LBB11_1
.LBB11_4:
	lw	a0, 40(sp)
	lw	a1, 32(sp)
	beq	a0, a1, .LBB11_6
	j	.LBB11_5
.LBB11_5:
	li	a0, 0
	sw	a0, 44(sp)
	j	.LBB11_6
.LBB11_6:
	lw	a0, 36(sp)
	lw	a1, 28(sp)
	beq	a0, a1, .LBB11_8
	j	.LBB11_7
.LBB11_7:
	li	a0, 0
	sw	a0, 44(sp)
	j	.LBB11_8
.LBB11_8:
	lui	a0, 258
	sw	a0, 20(sp)
	lw	a0, 20(sp)
	addi	a0, a0, 16
	lw	a1, 40(sp)
	call	write_to_address
	lw	a0, 20(sp)
	addi	a0, a0, 32
	lw	a1, 36(sp)
	call	write_to_address
	lw	a0, 20(sp)
	addi	a0, a0, 8
	sw	a0, 4(sp)                       # 4-byte Folded Spill
	lw	a0, 44(sp)
	lui	a1, 764587
	addi	a1, a1, -1363
	sw	a1, 8(sp)                       # 4-byte Folded Spill
	lui	a1, 831468
	addi	a1, a1, -1346
	sw	a1, 12(sp)                      # 4-byte Folded Spill
	bnez	a0, .LBB11_10
# %bb.9:
	lw	a0, 8(sp)                       # 4-byte Folded Reload
	sw	a0, 12(sp)                      # 4-byte Folded Spill
.LBB11_10:
	lw	a0, 4(sp)                       # 4-byte Folded Reload
	lw	a1, 12(sp)                      # 4-byte Folded Reload
	call	write_to_address
	lw	ra, 60(sp)                      # 4-byte Folded Reload
	lw	s0, 56(sp)                      # 4-byte Folded Reload
	addi	sp, sp, 64
	ret
.Lfunc_end11:
	.size	test_zkne, .Lfunc_end11-test_zkne
                                        # -- End function
	.p2align	1                               # -- Begin function sw_aes32esi
	.type	sw_aes32esi,@function
sw_aes32esi:                            # @sw_aes32esi
# %bb.0:
	addi	sp, sp, -32
	sw	ra, 28(sp)                      # 4-byte Folded Spill
	sw	s0, 24(sp)                      # 4-byte Folded Spill
	addi	s0, sp, 32
	sw	a0, 20(sp)
	sw	a1, 16(sp)
	sw	a2, 12(sp)
	lw	a0, 16(sp)
	lw	a1, 12(sp)
	slli	a1, a1, 3
	srl	a0, a0, a1
	sb	a0, 11(sp)
	lbu	a1, 11(sp)
	lui	a0, %hi(sbox)
	addi	a0, a0, %lo(sbox)
	add	a0, a0, a1
	lbu	a0, 0(a0)
	sb	a0, 10(sp)
	lw	a0, 20(sp)
	lbu	a1, 10(sp)
	lw	a2, 12(sp)
	slli	a2, a2, 3
	sll	a1, a1, a2
	xor	a0, a0, a1
	lw	ra, 28(sp)                      # 4-byte Folded Reload
	lw	s0, 24(sp)                      # 4-byte Folded Reload
	addi	sp, sp, 32
	ret
.Lfunc_end12:
	.size	sw_aes32esi, .Lfunc_end12-sw_aes32esi
                                        # -- End function
	.p2align	1                               # -- Begin function sw_aes32esmi
	.type	sw_aes32esmi,@function
sw_aes32esmi:                           # @sw_aes32esmi
# %bb.0:
	addi	sp, sp, -48
	sw	ra, 44(sp)                      # 4-byte Folded Spill
	sw	s0, 40(sp)                      # 4-byte Folded Spill
	addi	s0, sp, 48
	sw	a0, 36(sp)
	sw	a1, 32(sp)
	sw	a2, 28(sp)
	lw	a0, 32(sp)
	lw	a1, 28(sp)
	slli	a1, a1, 3
	srl	a0, a0, a1
	sb	a0, 27(sp)
	lbu	a1, 27(sp)
	lui	a0, %hi(sbox)
	addi	a0, a0, %lo(sbox)
	add	a0, a0, a1
	lbu	a0, 0(a0)
	sb	a0, 26(sp)
	lbu	a0, 26(sp)
	call	xt2
	sb	a0, 25(sp)
	lbu	a1, 25(sp)
	lbu	a2, 26(sp)
	xor	a0, a1, a2
	slli	a0, a0, 24
	slli	a3, a2, 16
	or	a0, a0, a3
	slli	a2, a2, 8
	or	a0, a0, a2
	or	a0, a0, a1
	sw	a0, 20(sp)
	lw	a0, 28(sp)
	slli	a0, a0, 3
	sw	a0, 16(sp)
	lw	a0, 16(sp)
	beqz	a0, .LBB13_2
	j	.LBB13_1
.LBB13_1:
	lw	a1, 20(sp)
	lw	a2, 16(sp)
	sll	a0, a1, a2
	neg	a2, a2
	srl	a1, a1, a2
	or	a0, a0, a1
	sw	a0, 8(sp)                       # 4-byte Folded Spill
	j	.LBB13_3
.LBB13_2:
	lw	a0, 20(sp)
	sw	a0, 8(sp)                       # 4-byte Folded Spill
	j	.LBB13_3
.LBB13_3:
	lw	a0, 8(sp)                       # 4-byte Folded Reload
	sw	a0, 12(sp)
	lw	a0, 36(sp)
	lw	a1, 12(sp)
	xor	a0, a0, a1
	lw	ra, 44(sp)                      # 4-byte Folded Reload
	lw	s0, 40(sp)                      # 4-byte Folded Reload
	addi	sp, sp, 48
	ret
.Lfunc_end13:
	.size	sw_aes32esmi, .Lfunc_end13-sw_aes32esmi
                                        # -- End function
	.p2align	1                               # -- Begin function xt2
	.type	xt2,@function
xt2:                                    # @xt2
# %bb.0:
	addi	sp, sp, -16
	sw	ra, 12(sp)                      # 4-byte Folded Spill
	sw	s0, 8(sp)                       # 4-byte Folded Spill
	addi	s0, sp, 16
                                        # kill: def $x11 killed $x10
	sb	a0, 7(sp)
	lbu	a1, 7(sp)
	slli	a0, a1, 1
	srli	a2, a1, 7
	li	a1, 0
	sub	a1, a1, a2
	andi	a1, a1, 27
	xor	a0, a0, a1
	zext.b	a0, a0
	lw	ra, 12(sp)                      # 4-byte Folded Reload
	lw	s0, 8(sp)                       # 4-byte Folded Reload
	addi	sp, sp, 16
	ret
.Lfunc_end14:
	.size	xt2, .Lfunc_end14-xt2
                                        # -- End function
	.type	sbox,@object                    # @sbox
	.section	.rodata,"a",@progbits
sbox:
	.ascii	"c|w{\362ko\3050\001g+\376\327\253v\312\202\311}\372YG\360\255\324\242\257\234\244r\300\267\375\223&6?\367\3144\245\345\361q\3301\025\004\307#\303\030\226\005\232\007\022\200\342\353'\262u\t\203,\032\033nZ\240R;\326\263)\343/\204S\321\000\355 \374\261[j\313\2769JLX\317\320\357\252\373CM3\205E\371\002\177P<\237\250Q\243@\217\222\2358\365\274\266\332!\020\377\363\322\315\f\023\354_\227D\027\304\247~=d]\031s`\201O\334\"*\220\210F\356\270\024\336^\013\333\3402:\nI\006$\\\302\323\254b\221\225\344y\347\3107m\215\325N\251lV\364\352ez\256\b\272x%.\034\246\264\306\350\335t\037K\275\213\212p>\265fH\003\366\016a5W\271\206\301\035\236\341\370\230\021i\331\216\224\233\036\207\351\316U(\337\214\241\211\r\277\346BhA\231-\017\260T\273\026"
	.size	sbox, 256

	.type	rcon,@object                    # @rcon
rcon:
	.ascii	"\001\002\004\b\020 @\200\0336"
	.size	rcon, 10

	.type	.L__const.main.plaintext,@object # @__const.main.plaintext
	.section	.rodata.cst16,"aM",@progbits,16
.L__const.main.plaintext:
	.ascii	"Hello, World!000"
	.size	.L__const.main.plaintext, 16

	.type	.L__const.main.key,@object      # @__const.main.key
.L__const.main.key:
	.ascii	"cese4040password"
	.size	.L__const.main.key, 16

	.type	.L__const.main.expected_output,@object # @__const.main.expected_output
.L__const.main.expected_output:
	.ascii	"\024\t\245\373\037\364Kq\276\252%.\017\b\371\252"
	.size	.L__const.main.expected_output, 16

	.ident	"clang version 23.0.0git (https://github.com/llvm/llvm-project.git dbdb2edfe8e02935e12749a6cb0eb0b991328990)"
	.section	".note.GNU-stack","",@progbits
	.addrsig
	.addrsig_sym expand_key
	.addrsig_sym gf_mult
	.addrsig_sym aes128_encrypt_block
	.addrsig_sym aes128_ecb_encrypt
	.addrsig_sym write_to_address
	.addrsig_sym write_v_to_address
	.addrsig_sym test_zkne
	.addrsig_sym sw_aes32esi
	.addrsig_sym sw_aes32esmi
	.addrsig_sym xt2
	.addrsig_sym sbox
	.addrsig_sym rcon
