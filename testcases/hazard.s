.text

# Pipeline hazard test program.
# Exercises RAW forwarding, load-use behavior, load/store ordering, branches,
# and jump-link behavior.

# Test 1: RAW data hazards.
    addi x1, x0, 5
    addi x2, x0, 10
    add  x3, x1, x2         # x3 = 15.
    sub  x4, x3, x1         # x4 = 10.

# Test 2: load-use hazard.
    sw   x2, 0(x0)          # mem[0] = 10.
    lw   x5, 0(x0)
    add  x6, x5, x1         # x6 = 15.

# Test 3: load after store.
    addi x7, x0, 20
    sw   x7, 4(x0)          # mem[1] = 20.
    lw   x8, 4(x0)

# Test 4: store after load.
    lw   x9, 0(x0)
    sw   x9, 8(x0)          # mem[2] = 10.

# Test 5: branch control hazard.
    addi x10, x0, 5
    addi x11, x0, 5
    beq  x10, x11, branch_target
    addi x12, x0, 1         # Skipped.
branch_target:
    addi x13, x0, 30

# Test 6: jump and link hazard.
    jal  x14, jump_target
    addi x15, x0, 2         # Skipped.
jump_target:
    addi x16, x0, 3
    addi x17, x14, 0        # x17 = link address from jal.
