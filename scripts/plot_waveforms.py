#!/usr/bin/env python3
"""Render simulation waveforms (VCD) to PNG images for the documentation.

Usage (from the repository root, after `make all`):
    pip install vcdvcd matplotlib
    python3 scripts/plot_waveforms.py

Reads   sim/tb_mips_cpu.vcd, sim/tb_alu.vcd
Writes  docs/waveforms/*.png

The plots use the same layout as a logic analyser / GTKWave view:
1-bit signals are drawn as square waves, buses as labelled value segments.
The instruction bus is shown as disassembled MIPS assembly.
"""

import os
import sys

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
from vcdvcd import VCDVCD  # noqa: E402

SIM_DIR = "sim"
OUT_DIR = os.path.join("docs", "waveforms")
CLK_PS = 10_000  # 10 ns clock period in the testbenches (VCD time unit = 1 ps)

REG_NAMES = ["$zero", "$at", "$v0", "$v1", "$a0", "$a1", "$a2", "$a3",
             "$t0", "$t1", "$t2", "$t3", "$t4", "$t5", "$t6", "$t7",
             "$s0", "$s1", "$s2", "$s3", "$s4", "$s5", "$s6", "$s7",
             "$t8", "$t9", "$k0", "$k1", "$gp", "$sp", "$fp", "$ra"]
FUNCT = {0x20: "add", 0x22: "sub", 0x24: "and", 0x25: "or", 0x2A: "slt"}
ALU_OPS = {0: "AND", 1: "OR", 2: "ADD", 6: "SUB", 7: "SLT"}


# --------------------------------------------------------------------------
# Value formatting
# --------------------------------------------------------------------------
def disasm(word):
    """Disassemble one instruction of the supported MIPS subset."""
    op = (word >> 26) & 0x3F
    rs, rt, rd = (word >> 21) & 31, (word >> 16) & 31, (word >> 11) & 31
    imm = word & 0xFFFF
    simm = imm - 0x10000 if imm & 0x8000 else imm
    if word == 0:
        return "nop"
    if op == 0:
        name = FUNCT.get(word & 0x3F, "r?")
        return f"{name} {REG_NAMES[rd]},{REG_NAMES[rs]},{REG_NAMES[rt]}"
    if op == 0x08:
        return f"addi {REG_NAMES[rt]},{REG_NAMES[rs]},{simm}"
    if op == 0x23:
        return f"lw {REG_NAMES[rt]},{simm}({REG_NAMES[rs]})"
    if op == 0x2B:
        return f"sw {REG_NAMES[rt]},{simm}({REG_NAMES[rs]})"
    if op == 0x04:
        return f"beq {REG_NAMES[rs]},{REG_NAMES[rt]},{simm}"
    if op == 0x02:
        return f"j 0x{(word & 0x3FFFFFF) << 2:x}"
    return f"0x{word:08x}"


def fmt(kind, value):
    if value is None:
        return "x"
    if kind == "hex":
        return f"{value:x}"
    if kind == "pc":
        return f"{value:02x}"
    if kind == "asm":
        return disasm(value)
    if kind == "alu":
        return ALU_OPS.get(value, f"invalid ({value})")
    if kind == "sdec":
        return str(value - (1 << 32) if value & 0x80000000 else value)
    return str(value)


def to_int(raw):
    if raw is None:
        return None
    raw = raw.lower()
    if any(c in raw for c in "xz"):
        return None
    return int(raw, 2)


# --------------------------------------------------------------------------
# VCD helpers
# --------------------------------------------------------------------------
class Wave:
    def __init__(self, path):
        self.vcd = VCDVCD(path)
        self.names = {n.split("[")[0]: n for n in self.vcd.signals}

    def tv(self, name):
        """Return the (time, int value) change list of a signal."""
        sig = self.vcd[self.names[name]]
        return [(t, to_int(v)) for t, v in sig.tv]

    def segments(self, name, t0, t1):
        """Value segments [(start, end, value)] clipped to the window [t0, t1]."""
        tv = self.tv(name)
        out = []
        cur = None
        for t, v in tv:
            if t <= t0:
                cur = v
                continue
            if t >= t1:
                break
            out.append([t0 if not out else out[-1][1], t, cur])
            cur = v
        start = out[-1][1] if out else t0
        out.append([start, t1, cur])
        merged = []
        for s in out:
            if s[1] <= s[0]:
                continue
            if merged and merged[-1][2] == s[2]:
                merged[-1][1] = s[1]
            else:
                merged.append(s)
        return merged

    def low_intervals(self, name):
        """Intervals in which a 1-bit signal is 0 (used to find program runs)."""
        tv = self.tv(name)
        res, start = [], None
        for t, v in tv:
            if v == 0 and start is None:
                start = t
            elif v == 1 and start is not None:
                res.append((start, t))
                start = None
        if start is not None:
            res.append((start, self.vcd.endtime))
        return res


# --------------------------------------------------------------------------
# Drawing
# --------------------------------------------------------------------------
BIT_COLOR = "#1a7f37"
BUS_COLOR = "#0b5cad"
BUS_FILL = "#e8f1fb"
HL_FILL = "#fff3c4"


def plot(wave, rows, t0, t1, title, out_name, highlight=None, width=None, unit="cycle"):
    """rows: list of (signal, label, kind). kind = bit|clk|hex|dec|sdec|pc|asm|alu"""
    n = len(rows)
    span_cycles = (t1 - t0) / CLK_PS
    if width is None:
        width = min(max(10, span_cycles * 0.75 + 3), 22)
    fig, ax = plt.subplots(figsize=(width, 0.62 * n + 1.4), dpi=150)
    row_h = 1.0
    px_per_ps = (width - 2.6) * 150 / (t1 - t0)

    for i, (sig, label, kind) in enumerate(rows):
        y = (n - 1 - i) * row_h
        lo, hi = y + 0.15, y + 0.75
        ax.text(t0 - (t1 - t0) * 0.005, (lo + hi) / 2, label, ha="right", va="center",
                fontsize=9, family="monospace", fontweight="bold", parse_math=False)
        segs = wave.segments(sig, t0, t1)
        if kind in ("bit", "clk"):
            xs, ys = [], []
            for s, e, v in segs:
                lvl = hi if v == 1 else lo
                xs += [s, e]
                ys += [lvl, lvl]
            ax.plot(xs, ys, color=BIT_COLOR, lw=1.4, drawstyle="default")
            # vertical edges
            for (s, e, v), (s2, e2, v2) in zip(segs, segs[1:]):
                ax.plot([e, e], [lo, hi], color=BIT_COLOR, lw=1.4)
        else:
            for s, e, v in segs:
                d = min((e - s) * 0.12, CLK_PS * 0.12)
                xs = [s, s + d, e - d, e, e - d, s + d, s]
                ys = [(lo + hi) / 2, hi, hi, (lo + hi) / 2, lo, lo, (lo + hi) / 2]
                ax.fill(xs, ys, color=BUS_FILL if v is not None else "#f4d6d6", zorder=1)
                ax.plot(xs, ys, color=BUS_COLOR, lw=1.0, zorder=2)
                text = fmt(kind, v)
                avail = (e - s) * px_per_ps
                if kind == "asm" and " " in text and len(text) * 9.6 + 8 >= avail:
                    text = text.replace(" ", "\n", 1)  # mnemonic / operands on two lines
                    if max(len(x) for x in text.split("\n")) * 8.2 + 6 < avail:
                        ax.text((s + e) / 2, (lo + hi) / 2, text, ha="center", va="center",
                                fontsize=6.5, family="monospace", zorder=3, linespacing=1.0,
                                parse_math=False)
                    continue
                if len(text) * 9.6 + 8 < avail:
                    ax.text((s + e) / 2, (lo + hi) / 2, text, ha="center", va="center",
                            fontsize=7.5, family="monospace", zorder=3, parse_math=False)
                elif avail > 18 and kind in ("dec", "sdec", "hex", "pc"):
                    ax.text((s + e) / 2, (lo + hi) / 2, text, ha="center", va="center",
                            fontsize=5.5, family="monospace", zorder=3, rotation=90, parse_math=False)

    if highlight:
        for hs, he, htxt in highlight:
            ax.axvspan(hs, he, color=HL_FILL, zorder=0)
            ax.text((hs + he) / 2, n * row_h + 0.05, htxt, ha="center", va="bottom",
                    fontsize=8, color="#7a5a00", parse_math=False)

    # cycle grid on rising edges
    first = (t0 // CLK_PS) * CLK_PS + CLK_PS // 2
    ticks = []
    t = first
    while t < t1:
        if t >= t0:
            ax.axvline(t, color="#d0d0d0", lw=0.5, zorder=0)
            ticks.append(t)
        t += CLK_PS
    step = max(1, len(ticks) // 25)
    ax.set_xticks(ticks[::step])
    if unit == "cycle":
        ax.set_xticklabels([str(int((tk - ticks[0]) / CLK_PS)) for tk in ticks[::step]], fontsize=8)
        ax.set_xlabel("rising clock edge number (10 ns clock period)", fontsize=9)
    else:
        ax.set_xticklabels([f"{tk / 1000:.0f}" for tk in ticks[::step]], fontsize=8)
        ax.set_xlabel("simulation time (ns)", fontsize=9)
    ax.set_xlim(t0, t1)
    ax.set_ylim(-0.2, n * row_h + (0.45 if highlight else 0.1))
    ax.set_yticks([])
    for side in ("top", "right", "left"):
        ax.spines[side].set_visible(False)
    # The caption is given in the README / report, so no title is drawn on the image.
    fig.tight_layout()
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, out_name)
    fig.savefig(path, facecolor="white")
    plt.close(fig)
    print("wrote", path)


def edge(start, k):
    """Time of the k-th rising clock edge after reset is released at `start`.
    The instruction executed in cycle k is the one between edge(k-1) and edge(k)."""
    return start + CLK_PS // 2 + k * CLK_PS


def cyc(start, k):
    return edge(start, k)


def main():
    for f in ("tb_mips_cpu.vcd", "tb_alu.vcd"):
        if not os.path.exists(os.path.join(SIM_DIR, f)):
            sys.exit(f"missing {SIM_DIR}/{f}: run `make all` first")

    cpu = Wave(os.path.join(SIM_DIR, "tb_mips_cpu.vcd"))
    runs = cpu.low_intervals("tb_mips_cpu.reset")  # one interval per program
    P = "tb_mips_cpu."
    U = P + "uut."

    # 1. Array sum ---------------------------------------------------------
    s, e = runs[0]
    plot(cpu, [
        (P + "clk", "clk", "clk"),
        (P + "reset", "reset", "bit"),
        (U + "pc_current", "PC", "pc"),
        (U + "instruction", "instruction", "asm"),
        (U + "alu_result", "alu_result", "dec"),
        (U + "reg_write", "RegWrite", "bit"),
        (U + "mem_write", "MemWrite", "bit"),
        (P + "t0_reg", "$t0", "dec"),
        (P + "t2_reg", "$t2 (sum)", "dec"),
        (P + "dmem_word0", "MEM[0]", "dec"),
    ], s, edge(s, 11) + CLK_PS // 2,
        "Fig. A - Array sum [10,20,30,40,50]: $t2 accumulates to 150, SW stores it to MEM[0]",
        "01_array_sum.png",
        highlight=[(edge(s, 8), edge(s, 9), "sw $t2,0($zero)")])

    # 2. Maximum search ----------------------------------------------------
    s, e = runs[1]
    plot(cpu, [
        (P + "clk", "clk", "clk"),
        (U + "pc_current", "PC", "pc"),
        (U + "instruction", "instruction", "asm"),
        (U + "branch", "Branch", "bit"),
        (U + "alu_zero", "Zero", "bit"),
        (U + "pc_next", "next PC", "pc"),
        (P + "t1_reg", "$t1 (elem)", "dec"),
        (P + "t3_reg", "$t3 (slt)", "dec"),
        (P + "t2_reg", "$t2 (max)", "dec"),
        (P + "dmem_word0", "MEM[0]", "dec"),
    ], s, edge(s, 18) + CLK_PS // 2,
        "Fig. B - Maximum search [12,45,7,89,23]: BEQ taken (skip update) when slt = 0, result 89",
        "02_max_search.png", width=20)

    # 3. Factorial ---------------------------------------------------------
    s, e = runs[2]
    plot(cpu, [
        (P + "clk", "clk", "clk"),
        (U + "pc_current", "PC", "pc"),
        (U + "branch", "Branch", "bit"),
        (U + "alu_zero", "Zero", "bit"),
        (U + "jump", "Jump", "bit"),
        (P + "t0_reg", "$t0 (n)", "dec"),
        (P + "t1_reg", "$t1 (i)", "dec"),
        (P + "t3_reg", "$t3 (acc)", "dec"),
        (P + "t2_reg", "$t2 (fact)", "dec"),
        (P + "dmem_word0", "MEM[0]", "dec"),
    ], s, edge(s, 106) + CLK_PS // 2,
        "Fig. C - Factorial 5! by repeated addition: $t2 = 1, 5, 20, 60, 120; stored to MEM[0]",
        "03_factorial.png", width=22)

    # 4. Jump / logic test -------------------------------------------------
    s, e = runs[3]
    plot(cpu, [
        (P + "clk", "clk", "clk"),
        (U + "pc_current", "PC", "pc"),
        (U + "instruction", "instruction", "asm"),
        (U + "jump", "Jump", "bit"),
        (U + "alu_control_signal", "ALU op", "alu"),
        (U + "alu_result", "alu_result", "dec"),
        (U + "mem_write", "MemWrite", "bit"),
        (U + "mem_read", "MemRead", "bit"),
        (U + "mem_read_data", "mem_rdata", "dec"),
        (P + "t2_reg", "$t2 sub", "dec"),
        (P + "t3_reg", "$t3 and", "dec"),
        (P + "t4_reg", "$t4 or", "dec"),
        (P + "t5_reg", "$t5 slt", "dec"),
        (P + "t6_reg", "$t6 lw", "dec"),
    ], s, edge(s, 10) + CLK_PS // 2,
        "Fig. D - Jump/logic test: J at 0x08 skips 0x0C; SUB/AND/OR/SLT, then SW/LW at address 4",
        "04_jump_logic.png",
        highlight=[(edge(s, 1), edge(s, 2), "j 0x10: PC 08 -> 10")])

    # 5. Reset -------------------------------------------------------------
    s3, e3 = runs[2]
    s4, e4 = runs[3]
    plot(cpu, [
        (P + "clk", "clk", "clk"),
        (P + "reset", "reset", "bit"),
        (U + "pc_current", "PC", "pc"),
        (P + "t2_reg", "$t2", "dec"),
        (P + "t3_reg", "$t3", "dec"),
        (P + "dmem_word0", "MEM[0]", "dec"),
    ], e3 - 3 * CLK_PS, s4 + 3 * CLK_PS,
        "Fig. E - Synchronous reset clears PC, register file and data memory on the next rising edge",
        "05_reset.png", highlight=[(e3, s4, "reset = 1")])

    # 6. ALU unit test -----------------------------------------------------
    alu = Wave(os.path.join(SIM_DIR, "tb_alu.vcd"))
    tv = [t for t, _ in alu.tv("tb_alu.alu_control")] + [t for t, _ in alu.tv("tb_alu.a")]
    a_t0 = sorted(set(tv))[1] if len(set(tv)) > 1 else 0
    plot(alu, [
        ("tb_alu.alu_control", "alu_control", "alu"),
        ("tb_alu.a", "a", "sdec"),
        ("tb_alu.b", "b", "sdec"),
        ("tb_alu.result", "result", "sdec"),
        ("tb_alu.zero", "zero", "bit"),
    ], max(0, a_t0 - 1000), a_t0 + 16 * CLK_PS,
        "Fig. F - ALU testbench: ADD, SUB, AND, OR, signed SLT and zero flag",
        "06_alu.png", width=20, unit="ns")


if __name__ == "__main__":
    main()
