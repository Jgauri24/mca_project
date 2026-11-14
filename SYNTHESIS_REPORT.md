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

The existing `mips_cpu.v` instantiations leave `register_file.reset` and `data_memory.reset` unconnected. This was already noted during simulation. The synthesis command completes, but the processor reset does not clear those blocks in the integrated RTL. Their reset connections should be reviewed by the RTL owners before FPGA implementation. No teammate RTL was changed to generate this report.

## Reproduce

Run from the project directory:

```sh
yosys -p 'read_verilog alu.v alu_control.v branch_jump.v control_unit.v data_memory.v instruction_memory.v mips_cpu.v pc.v register_file.v sign_extend.v; synth -top mips_cpu; check; stat'
```
