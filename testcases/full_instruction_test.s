# Full Instruction Set Test - all 33 instructions
.text
    # --- Setup constants ---
    addi x1, x0, 255
    addi x2, x0, 10
    addi x3, x0, -1

    # --- R-type: ADD x4 = 265 ---
    add x4, x1, x2
    # --- R-type: SUB x5 = 245 ---
    sub x5, x1, x2
    # --- R-type: AND x6 = 10 ---
    and x6, x1, x2
    # --- R-type: OR x7 = 255 ---
    or x7, x1, x2
    # --- R-type: XOR x8 = 245 ---
    xor x8, x1, x2

    # SLL x9 = x1 << 3 = 2040
    addi x10, x0, 3
    sll x9, x1, x10

    # SRL x11 = x1 >> 2 = 63
    addi x10, x0, 2
    srl x11, x1, x10

    # SRA x12 = x3 >> 5 = -1
    addi x10, x0, 5
    sra x12, x3, x10

    # SLT x13 = (x2 < x1) signed = 1
    slt x13, x2, x1

    # SLTU x14 = (x15 < x2) unsigned = 1
    addi x15, x0, 5
    sltu x14, x15, x2

    # --- I-type: ADDI x16 = 17 ---
    addi x16, x2, 7
    # --- I-type: ANDI x17 = 15 ---
    andi x17, x1, 15
    # --- I-type: ORI x18 = 42 ---
    ori x18, x2, 32
    # --- I-type: XORI x19 = 0 ---
    xori x19, x2, 10
    # --- I-type: SLTI x20 = 1 ---
    slti x20, x2, 100
    # --- I-type: SLTIU x21 = 0 ---
    sltiu x21, x2, 5
    # --- I-type: SLLI x22 = 4080 ---
    slli x22, x1, 4
    # --- I-type: SRLI x23 = 15 ---
    srli x23, x1, 4
    # --- I-type: SRAI x24 = -1 ---
    srai x24, x3, 8

    # --- Memory: SW + LW ---
    sw x4, 0(x0)
    sw x5, 4(x0)
    lw x26, 0(x0)
    lw x27, 4(x0)

    # --- U-type: LUI x28 = 0x1000 = 4096 ---
    lui x28, 4096

    # --- U-type: AUIPC x29 ---
    # auipc x29, 0x1 => x29 = PC + 0x1000
    # PC at this instruction will be known at test time
    auipc x29, 4096

    # --- Branch tests (x30 = accumulator) ---
    addi x30, x0, 0

    # BEQ not taken (x1!=x2)
    beq x1, x2, beq_skip
    addi x30, x30, 1
beq_skip:

    # BNE taken (x1!=x2)
    bne x1, x2, bne_taken
    addi x30, x30, 10
    jal x0, bne_done
bne_taken:
    addi x30, x30, 2
bne_done:

    # BLT taken (10 < 255 signed)
    blt x2, x1, blt_taken
    addi x30, x30, 10
    jal x0, blt_done
blt_taken:
    addi x30, x30, 4
blt_done:

    # BGE taken (255 >= 10 signed)
    bge x1, x2, bge_taken
    addi x30, x30, 10
    jal x0, bge_done
bge_taken:
    addi x30, x30, 8
bge_done:

    # BLTU taken (10 < 255 unsigned)
    bltu x2, x1, bltu_taken
    addi x30, x30, 10
    jal x0, bltu_done
bltu_taken:
    addi x30, x30, 16
bltu_done:

    # BGEU taken (255 >= 10 unsigned)
    bgeu x1, x2, bgeu_taken
    addi x30, x30, 10
    jal x0, bgeu_done
bgeu_taken:
    addi x30, x30, 32
bgeu_done:

    # BNE not taken (x1==x1)
    bne x1, x1, bne_nt_skip
    addi x30, x30, 64
bne_nt_skip:

    # BLT not taken (255 not < 10 signed)
    blt x1, x2, blt_nt_skip
    addi x30, x30, 128
blt_nt_skip:

    # BEQ taken (x1==x1)
    beq x1, x1, beq_t_taken
    addi x30, x30, 10
    jal x0, beq_t_done
beq_t_taken:
    # no increment, just proving branch taken
beq_t_done:

    # BGE not taken (-1 not >= 10 signed)
    bge x3, x2, bge_neg_skip
    addi x30, x30, 256
bge_neg_skip:

    # BLTU not taken (0xFFFFFFFF not < 10 unsigned)
    bltu x3, x2, bltu_neg_skip
    addi x30, x30, 512
bltu_neg_skip:

    # BGEU not taken (10 not >= 0xFFFFFFFF unsigned)
    bgeu x2, x3, bgeu_neg_skip
    addi x30, x30, 1024
bgeu_neg_skip:

    # --- JAL: x31 = return address, jump forward ---
    jal x31, jal_target
    addi x30, x30, 1000
jal_target:

    # --- JALR: test return address and target jump ---
    # Use auipc+addi pattern to compute target address
    # auipc x25, 0 => x25 = PC (of this auipc instruction)
    auipc x25, 0
    # addi x25, x25, 16 => x25 = PC+16 (skip jalr + 2 nops + skipped instr)  
    addi x25, x25, 16
    # jalr x31, x25, 0 => x31 = PC+4 (return addr), jump to x25+0
    jalr x31, x25, 0
    addi x30, x30, 1000  # skipped
jalr_target:
    # 3 instructions after auipc = jalr_target

    # --- Store results ---
    addi x25, x0, 0
    sw x4, 0(x25)
    sw x5, 4(x25)

    # --- Halt ---
halt:
    jal x0, halt