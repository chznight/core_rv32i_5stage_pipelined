.text

# Basic CPU smoke test.
# Writable data starts at byte address 0x400.

    addi x1, x0, 10
    addi x2, x0, 20
    add  x3, x1, x2
    sub  x4, x2, x1
    sw   x3, 1024(x0)
    lw   x5, 1024(x0)
    beq  x1, x4, after_branch
    addi x6, x0, 1

after_branch:
    addi x7, x0, 7

halt:
    jal  x0, halt
