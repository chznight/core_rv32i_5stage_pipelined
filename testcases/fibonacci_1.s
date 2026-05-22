.text

# Fibonacci sequence calculator.
# Calculates 20 values starting with 0, 1.
# Stores results in unified memory starting at byte address 0x400.

    addi x1, x0, 20      # Number of Fibonacci values to generate.
    addi x2, x0, 0       # Current Fibonacci value.
    addi x3, x0, 1       # Next Fibonacci value.
    addi x4, x0, 1024    # Output pointer.
    addi x5, x0, 0       # Loop counter.

fibonacci_loop:
    sw   x2, 0(x4)
    addi x5, x5, 1
    addi x4, x4, 4
    add  x6, x2, x3
    addi x2, x3, 0
    addi x3, x6, 0
    blt  x5, x1, fibonacci_loop

halt:
    jal  x0, halt
