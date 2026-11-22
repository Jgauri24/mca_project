#!/bin/sh
# Open-source synthesis flow used for SYNTHESIS_REPORT.md.
# Needs: yosys, nextpnr-himbaechel (brew install yosys nextpnr-himbaechel)
# Run from the repository root:  sh synthesis/run_yosys.sh
set -e
SRC="alu.v alu_control.v branch_jump.v control_unit.v data_memory.v instruction_memory.v mips_cpu.v pc.v register_file.v sign_extend.v"
OUT=synthesis/out
mkdir -p $OUT

echo "== 1. Xilinx 7-series (Artix-7) resource estimate =="
yosys -q -l $OUT/yosys_xilinx.log -p "read_verilog $SRC; synth_xilinx -top mips_cpu -family xc7; check; stat"

echo "== 2. Gowin GW5AST-138 synthesis + place-and-route (gives Fmax) =="
yosys -q -l $OUT/yosys_gowin.log -p "read_verilog $SRC synthesis/fpga_top.v; synth_gowin -family gw5a -top fpga_top -json $OUT/fpga_top.json"
nextpnr-himbaechel --json $OUT/fpga_top.json \
    --device GW5AST-LV138FPG676AES --vopt family=GW5AST-138C \
    --vopt cst=synthesis/tang_mega_138k.cst --freq 50 \
    --write $OUT/fpga_top_pnr.json 2>&1 | tee $OUT/nextpnr_gowin.log | grep -E "utilisation|LUT4|DFF|IOB|Max frequency"
