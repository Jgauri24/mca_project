# Verification

- **Prototype Demo Video:** [Google Drive Link](https://drive.google.com/file/d/14KFQ28BnsEGIQnmpHRSVrq3OwRP9Rdy6/view?usp=sharing)

All verification and sample programs are written in Verilog-2001. The CPU testbench embeds the machine-code words directly, so Python, an assembler, and external sample `.mem` files are not required. The original `programs/instruction_memory.mem` remains the memory subsystem's existing standalone sample.

## Encoding and addressing assumptions

The tests match the supplied RTL's MIPS subset: R-type functions `20/22/24/25/2a` and opcodes `23/2b/08/04/02`. PC and memory interfaces use byte addresses; word index is `address[9:2]`. Branch offsets are signed instruction-word displacements from `PC+4`; jump fields contain the target word address.

## Verification files and strategy

- `tb/tb_alu.v`: ADD, SUB, AND, OR, signed SLT, zero flag, negatives, overflow wraparound, and signed boundaries.
- `tb/tb_register_file.v`: synchronous writes/reset, asynchronous dual reads, `$zero` protection, write enable, and all registers.
- `tb/tb_data_memory.v`: reset, reads/writes, address mapping, disabled controls, invalid/unaligned accesses, and read-before-write.
- `tb/tb_instruction_memory.v`: fetch, initialization, alignment and range behavior of the existing instruction ROM.
- `tb/tb_mips_cpu.v`: four end-to-end Verilog machine-code programs; displays PC, instruction and working registers, checks final registers and data memory, checks that the CPU reset clears the PC, register file and data memory, and emits a VCD.
- `tb/tb_performance.v`: runs every program until its halt loop, counts the dynamic instruction mix and reports instruction count, cycles, CPI and execution time against a multi-cycle baseline.

The CPU programs compute array sum `[10,20,30,40,50]` (150), maximum of `[12,45,7,89,23]` (89), and `5!` (120); each stores its answer at data-memory word 0. Program 4 (jump/logic test) jumps over an `addi` that must not execute, then checks SUB (2), AND (8), OR (14), SLT (1), SW to byte address 4 and LW back (14), and that the PC stays at the halt loop.

## Run with Icarus Verilog

Run from the repository root (VCD waveforms go to `sim/`):

```sh
make all     # every testbench
make cpu     # tb/tb_mips_cpu.v only
make perf    # tb/tb_performance.v only
```

Individual targets: `alu`, `rf`, `se`, `imem`, `dmem`, `cpu`, `perf`.

## Verified results

Verified locally with Icarus Verilog 13.0: ALU 29/29, register file 20/20, sign extension 11/11, data memory 30/30, instruction memory 21/21, and CPU 18/18 checks passed (4 programs + reset checks). The performance testbench reports all 4 programs correct. Waveforms are written to `sim/` as `tb_alu.vcd`, `tb_register_file.vcd`, `tb_sign_extend.vcd`, `tb_data_memory.vcd`, `tb_instruction_memory.vcd`, `tb_mips_cpu.vcd` and `tb_performance.vcd`. Annotated waveform screenshots are in [`waveforms/`](waveforms/).

Reset integration (fixed): earlier versions of `mips_cpu.v` left the `reset` port of the register file and data memory unconnected, so the testbench had to clear them through the simulation hierarchy. `reset` is now wired to both blocks, the testbench no longer clears them by hand, and `tb_mips_cpu.v` checks before every program (and once more at the end) that the hardware reset cleared the PC, all registers and all 256 data-memory words.

Icarus may report nonfatal sensitivity warnings for asynchronous array reads and a short memory initialization warning for the existing ROM sample file.

## Failure diagnosis

- A wrong `debug_instruction` suggests program loading or PC/fetch trouble; a wrong register result with a correct instruction suggests control, ALU, or writeback trouble.
- A correct register result with incorrect data memory usually points to SW control or address mapping.
- Inspect `sim/tb_mips_cpu.vcd` with GTKWave to follow PC, instruction, and registers.

## Synthesis

Synthesis results (generic Yosys cells, Xilinx Artix-7 LUT/FF estimate, and Gowin place-and-route with maximum frequency) are in [SYNTHESIS_REPORT.md](SYNTHESIS_REPORT.md). Scripts are in [`synthesis/`](../synthesis/).
