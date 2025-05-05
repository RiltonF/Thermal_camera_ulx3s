#!/bin/bash

# Usage: ./run_test.sh my_module
MODULE_NAME=$1
NO_WAVE=$2

# Check for missing argument
if [ -z "$MODULE_NAME" ]; then
  echo "Usage: $0 <module_name>"
  exit 1
fi

# File naming
TB_FILE="${MODULE_NAME}"
OUT_FILE="simv"

# Compile with Icarus Verilog (you can swap for Verilator if needed)
echo "[INFO] Running simulation..."
svutRun -test $TB_FILE -fst -define "SIMULATION"
# svutRun -test $TB_FILE -fst -sim verilator

if [ $? -ne 0 ]; then
  echo "[ERROR] Compilation failed."
  exit 2
fi

# Run the simulation
# echo "[INFO] Running simulation..."
# vvp $OUT_FILE -fst

if [ -z "$NO_WAVE" ]; then
	echo "Opening Wave file"
	# gtkwave --rcvar 'use_big_fonts 1' wave.vcd wave.gtkw	
	gtkwave --rcvar 'use_big_fonts 1' wave.fst wave.gtkw	
fi
