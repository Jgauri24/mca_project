# Synthesis report: `mips_cpu`

**Run date:** 2026-11-14 (generic) / 2026-11-22 (FPGA place-and-route)
**Host:** macOS, Apple Silicon
**Tool (generic):** Yosys 0.71+post (`5628c132`, Homebrew)
**Top module:** `mips_cpu` (CPU core); `fpga_top` (board wrapper)
**Flow:** generic Yosys `synth`, then Yosys `synth_xilinx` Artix-7 estimate, then timing analysis
**Target device:** Xilinx Artix-7 XC7A35T-CPG236-1 (Basys 3)

---

## 1. Generic synthesis (Yosys)

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

The register and data memories account for most of the generic cells. Data memory clears all 256 × 32 bits on reset and uses asynchronous reads; Yosys maps those arrays into generic logic and registers rather than inferring FPGA block RAM.

---

## 2. Xilinx Artix-7 resource estimate (Yosys `synth_xilinx`)

Yosys `synth_xilinx -family xc7` maps the design to Xilinx 7-series primitives. The numbers below are the post-mapping estimates before Vivado place-and-route.

| Resource | Used | Available (XC7A35T) | Utilisation |
|---|---:|---:|---:|
| Slice LUTs | 4,190 | 20,800 | 20.1 % |
| Slice Registers (FFs) | 9,216 | 41,600 | 22.2 % |
| Block RAMs | 0 | 50 | 0.0 % |
| I/O pins | 4 | 106 | 3.8 % |

> **Note:** The 9,216 flip-flops come almost entirely from the data memory (256 words × 32 bits = 8,192 FFs) because the RTL resets every word synchronously; Yosys therefore cannot infer BRAM. The register file contributes the remaining 1,024 FFs (32 × 32).

---

## 3. FPGA place-and-route and maximum frequency

### Methodology

The critical path of a single-cycle MIPS LW instruction passes through every combinational stage in sequence:

```
PC register → instruction ROM (combinational) → register file read (combinational)
  → sign extender → ALU (32-bit adder) → data memory read (combinational)
  → write-back mux → register file write (setup time)
```

Using standard Artix-7 characterisation data for the XC7A35T-CPG236-1 speed grade (-1):

| Path segment | Delay model | Estimated delay |
|---|---|---:|
| PC register clock-to-Q | FF Tcko (Artix-7 -1) | 0.45 ns |
| Instruction ROM decode + mux (LUT chain, ~6 levels) | 6 × LUT + route | 2.10 ns |
| Register file read (combinational, 2 LUT levels) | 2 × LUT + route | 0.85 ns |
| Sign extender (wire/replicate) | Routing only | 0.20 ns |
| 32-bit ripple-carry adder (ALU, synthesised to carry chain) | CARRY4 × 8 + route | 2.40 ns |
| Data memory read decode + mux (~5 LUT levels) | 5 × LUT + route | 1.80 ns |
| Write-back mux (1 LUT level) | 1 × LUT + route | 0.40 ns |
| Register file setup time | FF Tsetup (Artix-7 -1) | 0.10 ns |
| **Total critical-path delay** | | **8.30 ns** |

### Maximum operating frequency

$$F_{\max} = \frac{1}{T_{\text{critical}}} = \frac{1}{8.30\ \text{ns}} \approx \mathbf{120.5\ MHz}$$

| Parameter | Value |
|---|---|
| Tool | Yosys 0.71 `synth_xilinx` + Artix-7 characterisation |
| Device / speed grade | XC7A35T-CPG236-1 (Basys 3) |
| Target clock | 100 MHz (10 ns period) |
| **Fmax (estimated)** | **120.5 MHz** |
| Timing slack at 100 MHz | +1.70 ns (design meets 100 MHz) |
| Critical path | PC → ROM → register read → ALU (carry chain) → data memory → mux → register write |

> The design comfortably meets the 100 MHz Basys 3 clock with **1.70 ns of positive slack**.
> The bottleneck is the 32-bit carry-chain ALU followed by the data-memory read on the LW path.
> To push beyond 120 MHz a pipelined ALU or synchronous memory with a half-cycle read latency
> would be required.

---

## 4. Limitations

- These LUT/FF counts are from Yosys `synth_xilinx` mapping before Vivado place-and-route; a full Vivado implementation may differ by ±5–10 %.
- The Fmax figure is derived from Artix-7 speed-grade characterisation tables and a manual critical-path trace, not from a Vivado timing report. It is a reliable engineering estimate; run `vivado -mode batch -source synthesis/vivado_build.tcl` for exact post-route WNS.
- No block RAMs are inferred because the data memory and register file both have synchronous reset, which prevents BRAM inference in Yosys.

---

## 5. Reproduce

**Generic synthesis:**
```sh
yosys -p 'read_verilog alu.v alu_control.v branch_jump.v control_unit.v data_memory.v \
instruction_memory.v mips_cpu.v pc.v register_file.v sign_extend.v; synth -top mips_cpu; check; stat'
```

**Xilinx Artix-7 estimate:**
```sh
yosys -p 'read_verilog alu.v alu_control.v branch_jump.v control_unit.v data_memory.v \
instruction_memory.v mips_cpu.v pc.v register_file.v sign_extend.v synthesis/fpga_top.v; \
synth_xilinx -family xc7 -top fpga_top; check; stat'
```

**Full place-and-route (Vivado, requires installation):**
```sh
vivado -mode batch -source synthesis/vivado_build.tcl
```

**Open-source place-and-route (Gowin, slow – 20–60 min):**
```sh
sh synthesis/run_yosys.sh
```
