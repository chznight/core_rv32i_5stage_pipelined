#!/bin/bash

# Compile the Verilog files
iverilog -g2012 -o fibonacci_tb rtl/bsram.v rtl/cpu.v rtl/control_unit.v rtl/register_file.v rtl/immediate_gen.v rtl/alu.v rtl/hazard_detection.v rtl/forwarding_unit.v tb/cpu_fibonacci_0_tb.v

# Run the simulation
vvp fibonacci_tb

# Open the waveform if GTKWave is available
#if command -v gtkwave >/dev/null 2>&1; then
#    gtkwave fibonacci_wave.gtkw &
#else
#    echo "GTKWave not found. Please install it to view the waveforms."
#fi
