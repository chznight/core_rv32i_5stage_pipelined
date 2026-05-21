.text

# GCD test program.
#
# Data memory layout:
# - mem[0] contains the number of input pairs.
# - mem[1..10] contains five input pairs.
# - mem[11..15] receives the GCD results.
#
# Register usage:
# - x1: current A value
# - x2: current B value
# - x4: byte pointer for reading input pairs
# - x5: number of pairs
# - x6: processed-pair counter
# - x7: byte pointer for writing results

    addi x4, x0, 0          # Input pointer starts at mem[0].
    lw   x5, 0(x4)          # Load number of pairs.
    addi x4, x4, 4          # Advance to first input value.
    addi x6, x0, 0          # Processed-pair counter.
    addi x7, x0, 44         # Result pointer: mem[11].

process_pair:
    lw   x1, 0(x4)          # Load A.
    addi x4, x4, 4
    lw   x2, 0(x4)          # Load B.
    addi x4, x4, 4

gcd_loop:
    beq  x1, x2, gcd_done
    blt  x1, x2, a_less
    sub  x1, x1, x2         # A = A - B.
    beq  x0, x0, gcd_loop

a_less:
    sub  x2, x2, x1         # B = B - A.
    beq  x0, x0, gcd_loop

gcd_done:
    sw   x1, 0(x7)
    addi x7, x7, 4
    addi x6, x6, 1
    blt  x6, x5, process_pair
