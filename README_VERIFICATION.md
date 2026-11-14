# MCA MIPS verification

All verification and sample programs are written in Verilog-2001. The CPU testbench embeds the machine-code words directly, so Python, an assembler, and external sample `.mem` files are not required. The original `instruction_memory.mem` remains the memory subsystem's existing standalone sample.

## Encoding and addressing assumptions

The tests match the supplied RTL's MIPS subset: R-type functions `20/22/24/25/2a` and opcodes `23/2b/08/04/02`. PC and memory interfaces use byte addresses; word index is `address[9:2]`. Branch offsets are signed instruction-word displacements from `PC+4`; jump fields contain the target word address.

## Verification files and strategy

- `tb_alu.v`: ADD, SUB, AND, OR, signed SLT, zero flag, negatives, overflow wraparound, and signed boundaries.
- `tb_register_file.v`: synchronous writes/reset, asynchronous dual reads, `$zero` protection, write enable, and all registers.
- `tb_data_memory.v`: reset, reads/writes, address mapping, disabled controls, invalid/unaligned accesses, and read-before-write.
- `tb_instruction_memory.v`: fetch, initialization, alignment and range behavior of the existing instruction ROM.
- `tb_mips_cpu.v`: three end-to-end Verilog machine-code programs; displays PC, instruction and working registers, checks final `$t2` and data memory, and emits a VCD.

The CPU programs compute array sum `[10,20,30,40,50]` (150), maximum of `[12,45,7,89,23]` (89), and `5!` (120). Each stores its answer at data-memory word 0.

## Run with Icarus Verilog

Run from the project directory:

```sh
iverilog -g2001 -Wall -s tb_alu -o /tmp/tb_alu alu.v tb_alu.v && vvp /tmp/tb_alu
iverilog -g2001 -Wall -s tb_register_file -o /tmp/tb_rf register_file.v tb_register_file.v && vvp /tmp/tb_rf
iverilog -g2001 -Wall -s tb_data_memory -o /tmp/tb_mem data_memory.v tb_data_memory.v && vvp /tmp/tb_mem
iverilog -g2001 -Wall -s tb_instruction_memory -o /tmp/tb_imem instruction_memory.v tb_instruction_memory.v && vvp /tmp/tb_imem
iverilog -g2001 -Wall -s tb_mips_cpu -o /tmp/tb_cpu pc.v branch_jump.v instruction_memory.v control_unit.v alu_control.v register_file.v sign_extend.v alu.v data_memory.v mips_cpu.v tb_mips_cpu.v && vvp /tmp/tb_cpu
```

## Verified results

Verified locally with Icarus Verilog 13.0: ALU 29/29, register file 20/20, data memory 30/30, instruction memory 21/21, and CPU 6/6 checks passed. The CPU checks expect `$t2` and data memory word 0 to contain 150, 89, and 120 for the respective programs. Waveforms are written as `tb_alu.vcd`, `tb_register_file.vcd`, `tb_data_memory.vcd`, `tb_instruction_memory.vcd`, and `tb_mips_cpu.vcd`.

The current `mips_cpu` RTL does not connect reset to the register file or data memory. The CPU testbench initializes those internal arrays through simulation hierarchy so it can test the existing CPU without modifying another member's RTL. Icarus may report nonfatal sensitivity warnings for asynchronous array reads and a short memory initialization warning for the existing ROM sample file.

## Failure diagnosis

- A wrong `debug_instruction` suggests program loading or PC/fetch trouble; a wrong register result with a correct instruction suggests control, ALU, or writeback trouble.
- A correct register result with incorrect data memory usually points to SW control or address mapping.
- Inspect `tb_mips_cpu.vcd` with GTKWave to follow PC, instruction, and registers.

## Synthesis

A generic Yosys synthesis report for `mips_cpu` is in [SYNTHESIS_REPORT.md](SYNTHESIS_REPORT.md). It records the Yosys version, command, generic cell counts, limitations, and the unconnected register-file/data-memory reset ports. It is not a vendor-specific FPGA fit or timing report.
