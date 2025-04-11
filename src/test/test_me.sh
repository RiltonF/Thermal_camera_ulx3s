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
SRC_FILE="../${MODULE_NAME}.sv"
TB_FILE="tb_${MODULE_NAME}.sv"
OUT_FILE="simv"

# Compile with Icarus Verilog (you can swap for Verilator if needed)
echo "[INFO] Compiling $SRC_FILE and $TB_FILE..."
iverilog -Wall -g2012 -o $OUT_FILE $SRC_FILE $TB_FILE

if [ $? -ne 0 ]; then
  echo "[ERROR] Compilation failed."
  exit 2
fi

# Run the simulation
echo "[INFO] Running simulation..."
vvp $OUT_FILE

if [ -z "$NO_WAVE" ]; then
	echo "Opening Wave file"
	gtkwave wave.vcd wave.gtkw	
fi
