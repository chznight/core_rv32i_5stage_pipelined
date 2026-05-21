.text

# Bubble sort benchmark.
#
# Memory layout:
# - mem[0] contains the array length.
# - mem[1..n] contains the array elements.
# - The sorted array is written back in place.
#
# Register usage:
# - x1: base byte address of mem[1]
# - x2: outer loop counter i
# - x3: inner loop counter j
# - x4: array length n
# - x5: temporary address / loop-bound value
# - x6: data[j]
# - x7: data[j + 1]
# - x8: n - 1
# - x20: completion flag

    addi x1, x0, 4          # Base address, skipping length word.
    lw   x4, -4(x1)         # Load n from mem[0].
    addi x8, x4, -1         # Last sortable index.
    addi x2, x0, 0          # i = 0.

outer_loop:
    bge  x2, x8, sort_done  # Stop when i >= n - 1.
    addi x3, x0, 0          # j = 0.

inner_loop:
    sub  x5, x8, x2         # Inner limit: n - 1 - i.
    bge  x3, x5, next_outer # Stop inner loop when j >= limit.

    slli x5, x3, 2          # Byte offset for j.
    add  x5, x1, x5         # Address of data[j].

    lw   x6, 0(x5)
    lw   x7, 4(x5)
    blt  x6, x7, skip_swap  # Already ordered when data[j] < data[j + 1].

    sw   x7, 0(x5)
    sw   x6, 4(x5)

skip_swap:
    addi x3, x3, 1
    jal  x0, inner_loop

next_outer:
    addi x2, x2, 1
    jal  x0, outer_loop

sort_done:
    addi x20, x0, 1

halt:
    jal  x0, halt
