# Generic synthesis report: `mips_cpu`

**Run date:** 2026-11-14  
**Host:** macOS, Apple Silicon  
**Tool:** Yosys 0.71+post (`5628c132`, Homebrew)  
**Top module:** `mips_cpu`  
**Flow:** generic Yosys `synth`, followed by `check` and `stat`  
**Target device:** none (no FPGA family or part was selected)

## Result

Synthesis completed successfully. Yosys `check` reported **0 problems**.

| Generic mapped cell group | Count |
|---|---:|
| Total cells in hierarchy | 22,625 |
| Sequential cells (`$_SDFFCE_PN0P_`) | 9,216 |
| Sequential cells (`$_SDFF_PP0_`) | 32 |
| Mux cells (`$_MUX_`) | 9,562 |
| AND cells (`$_AND_`) | 1,085 |
| NAND cells (`$_NAND_`) | 1,005 |
| NOR cells (`$_NOR_`) | 415 |
| Other simple logic cells | 2,730 |

Module totals from Yosys hierarchy statistics:

| Module | Generic cells |
|---|---:|
| `data_memory` | 16,996 |
| `register_file` | 4,586 |
| `pc` | 32 |
| ALU, control, branch/jump, sign extension, and integration logic | 1,011 |

The register and data memories account for most of the generic cells. In this RTL, data memory clears all 256 x 32 bits on reset and uses asynchronous reads. Yosys maps those arrays into generic logic and registers instead of reporting inferred FPGA block RAM. A vendor flow with a concrete part may produce different results.

## Limitations and integration finding

These are generic logic-cell counts after Yosys mapping, **not** FPGA LUT/CLB counts. This run has no device, pin constraints, clock constraint, placement, routing, or timing analysis; it therefore provides no maximum clock frequency or board utilization estimate.

At the time of this first run, `mips_cpu.v` left `register_file.reset` and `data_memory.reset` unconnected. **This has since been fixed:** `reset` is now wired to both blocks and `tb_mips_cpu.v` checks that reset clears them. The generic cell counts above are unchanged by the fix (22,625 cells, 0 problems on re-run).

## Reproduce

Run from the project directory:

```sh
yosys -p 'read_verilog rtl/*.v; synth -top mips_cpu; check; stat'
```

---

# FPGA synthesis, placement timing and maximum frequency

**Run date:** 2026-11-22  
**Tools:** Yosys 0.71+post, nextpnr-himbaechel (Gowin), Icarus Verilog 13.0  
**Scripts:** [`synthesis/run_yosys.sh`](../synthesis/run_yosys.sh) (open-source flow), [`synthesis/vivado_build.tcl`](../synthesis/vivado_build.tcl) + [`synthesis/basys3.xdc`](../synthesis/basys3.xdc) (Vivado flow)  
**Board wrapper:** [`synthesis/fpga_top.v`](../synthesis/fpga_top.v) folds the 64 debug output bits into 6 LEDs with XOR, so the design fits on a board and no CPU logic is optimised away.

## 1. Xilinx Artix-7 resource estimate (Yosys `synth_xilinx -family xc7`)

| Resource | Used | Basys3 xc7a35t available | Utilisation |
|---|---:|---:|---:|
| LUTs (LUT2-LUT6) | 4,190 | 20,800 | 20.1 % |
| Flip-flops (FDRE) | 9,216 | 41,600 | 22.2 % |
| CARRY4 | 35 | 8,150 | 0.4 % |
| Block RAM | 0 | 50 | 0 % |
| I/O (IBUF + OBUF) | 66 | 106 | 62 % |

| Module | Cells |
|---|---:|
| `data_memory` | 11,241 |
| `register_file` | 1,825 |
| `alu` | 183 |
| `branch_jump` | 80 |
| `pc` | 32 |
| `control_unit` + `alu_control` | 13 |
| **Total `mips_cpu`** | **13,510** |

Flip-flops: 8,192 for data memory (256 x 32), 992 for registers `$1-$31` (`$0` is constant and removed) and 32 for the PC = 9,216.

## 2. Gowin placement and static timing analysis (nextpnr)

Device: Gowin GW5AST-LV138FPG676AES (Sipeed Tang Mega 138K Pro), 50 MHz target clock, pins in [`synthesis/tang_mega_138k.cst`](../synthesis/tang_mega_138k.cst).

| Resource | Used | Available | Utilisation |
|---|---:|---:|---:|
| LUT4 | 25,695 | 138,240 | 18.6 % |
| MUX2 (LUT5-LUT8 wide muxes) | 11,488 | 138,240 | 8.3 % |
| DFF | 8,446 | 138,240 | 6.1 % |
| ALU (carry cells) | 106 | 103,680 | 0.1 % |
| Block RAM (BSRAM, instruction ROM) | 1 | 340 | 0.3 % |
| I/O (IOB) | 8 | 324 | 2.5 % |

**Maximum frequency: 30.46 MHz** (period about 32.8 ns), from nextpnr static timing analysis after placement, with a 50 MHz target clock. The 50 MHz target is not met, so the board would be clocked at or below 30 MHz.

This figure is nextpnr's static timing estimate after placement, before routing, so it is approximate. A post-routing figure was not available when this report was written. Gowin LUTs have 4 inputs, so the wide memory multiplexers need more logic levels than on a Xilinx 6-input LUT device. The CPU has not been run on a real board. The Vivado script in `synthesis/` gives the Artix-7 post-route frequency where Vivado is available.

## 3. Observations

- **Data memory dominates the area.** `data_memory.v` clears all 256 words on reset and reads asynchronously. FPGA block RAM supports neither, so the memory is built from 8,192 flip-flops plus large read multiplexers. Removing the memory-wide reset and using a synchronous read would let it map to a single block RAM and cut the area by roughly 80 %.
- **Critical path (expected).** In a single-cycle CPU the clock period must cover the whole LW path: PC -> instruction ROM -> register read -> ALU (address add) -> data memory read -> write-back mux -> register file setup. This is the expected longest path; the tool's path listing was not inspected. It is the main motivation for pipelining.
- A first attempt on the smaller GW2A-18 (Tang Primer 20K, 20,736 LUT4) did not fit: the design needs about 27.8k Gowin LUT4s because Gowin LUTs have 4 inputs (Xilinx LUT6 packs the same logic into 4.2k LUTs).
- The Vivado script produces the official Xilinx utilisation and timing reports (`synthesis/vivado_reports/`) for the Basys3 board if Vivado is available.
- The Gowin run kept 224 register-file flip-flops (8,446 in total) while the Xilinx estimate has 992 (9,216 in total). The reason was not investigated.
