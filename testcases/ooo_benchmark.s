.text

# OoO-friendly ALU benchmark:
# - five independent accumulator chains in the loop body
# - one loop counter branch
# - final checksum stored to memory[0]
# - x20 is set to 1 on completion

    addi x1,  x0, 2000   # loop count

    addi x10, x0, 1
    addi x11, x0, 2
    addi x12, x0, 3
    addi x13, x0, 4
    addi x14, x0, 5
    addi x15, x0, 6
    addi x16, x0, 7
    addi x17, x0, 8
    addi x18, x0, 9
    addi x19, x0, 10

    addi x0,  x0, 0      # nop: align loop target to an 8-byte fetch boundary
loop:
    add  x10, x10, x11
    add  x12, x12, x13
    add  x14, x14, x15
    add  x16, x16, x17
    add  x18, x18, x19
    addi x1,  x1, -1
    bne  x1,  x0, loop

    add  x24, x10, x12
    add  x25, x14, x16
    add  x26, x18, x24
    add  x27, x25, x26
    sw   x27, 0(x0)
    addi x20, x0, 1

done:
    jal  x0, done
