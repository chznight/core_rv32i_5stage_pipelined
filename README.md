# 32-bit RISC-V CPU

This project implements a synthesizable 32-bit RISCV CPU with pipeline hazard
detection/handling. The CPU design is based on RV32I ISA and is
structured for simulation and FPGA deployment. This design includes a 2 bit saturating counter branch predictor.

## Architecture Overview

The CPU features a 6-stage pipeline:
1. **Instruction Fetch (IF)**: Fetches instructions from memory
2. **Instruction Decode (ID)**: Decodes instructions and reads register values
3. **Execute (EX)**: Performs ALU operations
4. **Memory Stage 1 (MEM1)**: Issues load/store requests to synchronous block SRAM
5. **Memory Stage 2 (MEM2)**: Captures synchronous block SRAM read data
6. **Write Back (WB)**: Writes results back to registers

## Memory System

The simulation and FPGA-oriented test flows use one unified dual-port block
SRAM image:

- Port 1 is the instruction fetch port.
- Port 2 is the data load/store port.
- Program code starts at word `0`.
- Testbench memory images are loaded from `tb/*.hex` with `$readmemh`.

This keeps instruction and data sections in a single memory image while still
allowing the pipeline to fetch an instruction and access data in the same cycle.
The RTL memory model matches FPGA block SRAM behavior.

## Hazard Handling

The CPU includes mechanisms to handle pipeline hazards:

1. **Data Hazards**: 
   - Forwarding unit detects data dependencies and forwards values from later pipeline stages
   - Handles RAW (Read-After-Write) hazards

2. **Load-Use Hazards**: 
   - Hazard detection unit stalls the pipeline for two cycle when a load is followed by an instruction that uses the loaded value.

3. **Control Hazards**: 
   - Branch outcomes are determined in the EX stage
   - Pipeline is flushed on branch taken

## Instruction Set

The CPU supports a RISC-V like instruction set with the following types:

- **R-type**: Register-to-register operations (ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU)
- **I-type**: Register-immediate operations (ADDI, ANDI, ORI, XORI, SLTI, SLTIU, SLLI, SRLI, SRAI, LW)
- **S-type**: Store operations (SW)
- **B-type**: Branch operations (BEQ, BNE, BLT, BGE, BLTU, BGEU)
- **U-type**: Upper immediate operations (LUI, AUIPC)
- **J-type**: Jump operations (JAL, JALR)

## Project Structure

- `rtl/cpu.v`: Top-level CPU module
- `rtl/bsram.v`: Dual-port synchronous block SRAM model
- `rtl/alu.v`: Arithmetic Logic Unit
- `rtl/register_file.v`: Register file with 32 32-bit registers
- `rtl/control_unit.v`: Instruction decoder and control signal generator
- `rtl/immediate_gen.v`: Immediate value generator for different instruction types
- `rtl/hazard_detection.v`: Detects load-use hazards
- `rtl/forwarding_unit.v`: Implements data forwarding
- `testcases/*.s`: Assembly programs used to generate memory images
- `tb/*.hex`: Unified memory initialization files for simulation
- `tb/cpu_*_tb.v`: Testbenches for CPU validation

## Simulation

Each testbench instantiates one dual-port `bsram` and loads a matching unified
memory image from `tb/*.hex`. For example, `tb/cpu_gcd_tb.v` loads
`tb/gcd.hex`, which contains both the GCD program and its initial data section.

Example with Icarus Verilog:

```sh
iverilog -g2005 -o /tmp/cpu_full_test_tb \
  rtl/alu.v rtl/control_unit.v rtl/bsram.v rtl/cpu.v \
  rtl/forwarding_unit.v rtl/hazard_detection.v rtl/immediate_gen.v \
  rtl/register_file.v tb/cpu_full_test_tb.v
vvp /tmp/cpu_full_test_tb
```

The regression testbenches cover arithmetic, memory operations, branches,
forwarding/load-use hazards, Fibonacci, GCD, bubble sort, and a longer ALU
benchmark.

## FPGA

Design has been tested on FGPA running at 50mhz
