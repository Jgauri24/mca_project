#!/usr/bin/env python3
"""
scripts/plot_waveforms.py
Reads VCD files produced by iverilog and draws digital waveform PNGs into diagrams/.
Requires: vcdvcd  matplotlib  (pip install vcdvcd matplotlib)

Usage (run from repo root after vvp sim_cpu and vvp sim_alu):
    python3 scripts/plot_waveforms.py
"""

import os
import sys
import math
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.collections import LineCollection

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _parse_vcd_manual(vcd_path):
    """
    Minimal hand-rolled VCD parser that returns:
      signals : dict  name -> list of (time_ns, int_value)
      endtime : int   last timestamp in native VCD time units
      timescale_ns : float
    """
    signals = {}      # wire-name -> [(time, value)]
    id_map  = {}      # vcd-id -> wire-name
    scope   = []
    cur_time = 0
    timescale_ns = 1.0

    with open(vcd_path) as f:
        lines = f.readlines()

    # --- header pass: build id_map ---
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        if line.startswith("$timescale"):
            # collect until $end
            ts_text = ""
            while "$end" not in line:
                ts_text += line + " "
                i += 1
                line = lines[i].strip()
            ts_text += line
            ts_text = ts_text.replace("$timescale", "").replace("$end", "").strip()
            # parse e.g. "1ns", "1 ns", "100ps"
            ts_text = ts_text.replace(" ", "")
            multipliers = {"fs": 1e-6, "ps": 1e-3, "ns": 1.0, "us": 1e3, "ms": 1e6, "s": 1e9}
            for unit, mult in multipliers.items():
                if ts_text.endswith(unit):
                    timescale_ns = float(ts_text[:-len(unit)]) * mult
                    break
        elif line.startswith("$scope"):
            parts = line.split()
            if len(parts) >= 3:
                scope.append(parts[2])
        elif line.startswith("$upscope"):
            if scope:
                scope.pop()
        elif line.startswith("$var"):
            parts = line.split()
            if len(parts) >= 5:
                vcd_id = parts[3]
                raw_name = parts[4].split("[")[0]
                full_name = ".".join(scope + [raw_name]) if scope else raw_name
                if vcd_id not in id_map:
                    id_map[vcd_id] = full_name
                    signals[full_name] = []
        elif line.startswith("$dumpvars") or line.startswith("$end") or line.startswith("$dump"):
            if "$dumpvars" in line:
                # found start of values
                i += 1
                break
        i += 1

    # --- value pass ---
    while i < len(lines):
        line = lines[i].strip()
        if not line or line.startswith("$"):
            i += 1
            continue
        if line.startswith("#"):
            cur_time = int(line[1:])
        elif line[0] in ("0", "1", "x", "z") and len(line) > 1:
            val_char = line[0]
            vcd_id   = line[1:]
            val = 0 if val_char in ("x","z") else int(val_char)
            if vcd_id in id_map:
                name = id_map[vcd_id]
                signals[name].append((cur_time, val))
        elif line.startswith("b") or line.startswith("B"):
            parts = line.split()
            if len(parts) >= 2:
                bin_str = parts[0][1:]
                vcd_id  = parts[1]
                try:
                    val = int(bin_str.lstrip("xXzZ") or "0", 2)
                except ValueError:
                    val = 0
                if vcd_id in id_map:
                    name = id_map[vcd_id]
                    signals[name].append((cur_time, val))
        i += 1

    endtime = cur_time
    return signals, endtime, timescale_ns


def get_signal(signals, *candidates):
    """Return first matching signal name from candidates, or None."""
    for c in candidates:
        if c in signals:
            return c
        # partial match
        for k in signals:
            if k.endswith(c) or c in k:
                return k
    return None


def step_xy(events, t_start, t_end, timescale_ns):
    """Convert list of (raw_time, value) events to step-plot xs, ys in ns."""
    xs, ys = [], []
    if not events:
        return [t_start * timescale_ns, t_end * timescale_ns], [0, 0]
    cur_val = events[0][1]
    xs.append(t_start * timescale_ns)
    ys.append(cur_val)
    for t, v in events:
        t_ns = t * timescale_ns
        if t_ns < t_start * timescale_ns or t_ns > t_end * timescale_ns:
            continue
        xs.extend([t_ns, t_ns])
        ys.extend([cur_val, v])
        cur_val = v
    xs.append(t_end * timescale_ns)
    ys.append(cur_val)
    return xs, ys


def filter_range(events, t_start, t_end):
    """Return events within [t_start, t_end] raw time, with leading context."""
    # find last event before t_start to get initial value
    before = [e for e in events if e[0] < t_start]
    inside = [e for e in events if t_start <= e[0] <= t_end]
    seed   = [before[-1]] if before else []
    return seed + inside


def draw_waveforms(ax, rows, t_start, t_end, timescale_ns, is_bus_map):
    """
    rows: list of (label, signal_name, events_list)
    is_bus_map: set of signal_names that should be shown as bus (hex labels)
    """
    n = len(rows)
    row_height = 1.0
    bus_color  = "#1565C0"
    bit_color  = "#1B5E20"
    ax.set_xlim(t_start * timescale_ns, t_end * timescale_ns)
    ax.set_ylim(-0.5, n * row_height)
    ax.set_yticks([i * row_height + 0.5 for i in range(n)])
    ax.set_yticklabels([r[0] for r in reversed(rows)], fontsize=8, fontfamily="monospace")
    ax.set_xlabel("Time (ns)", fontsize=9)
    ax.grid(axis="x", linestyle=":", alpha=0.4)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.spines["left"].set_visible(False)

    for idx, (label, sname, events) in enumerate(reversed(rows)):
        y_base = idx * row_height
        evs = filter_range(events, t_start, t_end)
        is_bus = sname in is_bus_map

        if is_bus:
            # Draw filled bus: outline + hex value labels
            pts = [(t_start * timescale_ns, evs[0][1] if evs else 0)]
            for t, v in evs:
                pts.append((t * timescale_ns, v))
            pts.append((t_end * timescale_ns, pts[-1][1]))

            prev_t, prev_v = pts[0]
            for cur_t, cur_v in pts[1:]:
                if cur_t == prev_t:
                    prev_v = cur_v
                    continue
                # draw filled trapezoid
                xs = [prev_t, prev_t + 0.3, cur_t - 0.3, cur_t,
                      cur_t, cur_t - 0.3, prev_t + 0.3, prev_t]
                ys = [y_base + 0.5, y_base + 0.9, y_base + 0.9, y_base + 0.5,
                      y_base + 0.5, y_base + 0.1, y_base + 0.1, y_base + 0.5]
                ax.fill(xs, ys, color="#BBDEFB", linewidth=0, zorder=2)
                ax.plot([prev_t, prev_t + 0.3, cur_t - 0.3, cur_t],
                        [y_base + 0.5, y_base + 0.9, y_base + 0.9, y_base + 0.5],
                        color=bus_color, linewidth=1.0, zorder=3)
                ax.plot([prev_t, prev_t + 0.3, cur_t - 0.3, cur_t],
                        [y_base + 0.5, y_base + 0.1, y_base + 0.1, y_base + 0.5],
                        color=bus_color, linewidth=1.0, zorder=3)
                mid = (prev_t + cur_t) / 2
                label_str = f"0x{prev_v:08X}" if prev_v >= 0x1000 else f"{prev_v}"
                ax.text(mid, y_base + 0.5, label_str,
                        ha="center", va="center", fontsize=6.5,
                        fontfamily="monospace", color=bus_color, zorder=4,
                        clip_on=True)
                prev_t, prev_v = cur_t, cur_v
        else:
            # 1-bit signal
            xs, ys = step_xy(evs, t_start, t_end, timescale_ns)
            ys_scaled = [y_base + 0.1 + v * 0.8 for v in ys]
            ax.plot(xs, ys_scaled, color=bit_color, linewidth=1.2, zorder=3)
            ax.fill_between(xs, [y_base + 0.1] * len(xs), ys_scaled,
                            alpha=0.15, color=bit_color, step=None, zorder=2)


# ---------------------------------------------------------------------------
# Plot factory
# ---------------------------------------------------------------------------

def make_fig(title, rows, t_start, t_end, timescale_ns, is_bus_set, out_path):
    fig_h = max(3, len(rows) * 0.9 + 1.2)
    fig, ax = plt.subplots(figsize=(14, fig_h))
    fig.suptitle(title, fontsize=11, fontweight="bold", y=1.0)
    ax.set_facecolor("white")
    fig.patch.set_facecolor("white")
    draw_waveforms(ax, rows, t_start, t_end, timescale_ns, is_bus_set)
    plt.tight_layout()
    fig.savefig(out_path, dpi=120, bbox_inches="tight", facecolor="white")
    plt.close(fig)
    print(f"  Wrote {out_path}")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    os.makedirs("diagrams", exist_ok=True)
    os.makedirs("scripts",  exist_ok=True)

    # -----------------------------------------------------------------------
    # CPU waveforms  (tb_mips_cpu.vcd)
    # -----------------------------------------------------------------------
    cpu_vcd = "tb_mips_cpu.vcd"
    if not os.path.exists(cpu_vcd):
        print(f"[WARN] {cpu_vcd} not found – skipping CPU waveforms")
    else:
        print(f"Parsing {cpu_vcd} ...")
        sig, endtime, ts = _parse_vcd_manual(cpu_vcd)
        print(f"  Signals: {len(sig)}  endtime={endtime}  timescale={ts} ns")

        # Discover signal names (tolerant)
        clk_s   = get_signal(sig, "tb_mips_cpu.clk", "clk")
        rst_s   = get_signal(sig, "tb_mips_cpu.reset", "reset")
        pc_s    = get_signal(sig, "uut.debug_pc", "debug_pc")
        inst_s  = get_signal(sig, "uut.debug_instruction", "debug_instruction")
        t2_s    = get_signal(sig, "uut.u_register_file.registers[10]",
                                  "registers[10]", "reg_write_data")
        mwr_s   = get_signal(sig, "uut.mem_write", "mem_write")
        alur_s  = get_signal(sig, "uut.alu_result", "alu_result")
        branch_s= get_signal(sig, "uut.branch", "branch")
        zero_s  = get_signal(sig, "uut.alu_zero", "alu_zero", "zero")
        jump_s  = get_signal(sig, "uut.jump", "jump")

        def ev(name): return sig.get(name, [])

        # ---- 08: array sum (program 1 runs first, t=0 to ~280 ns) ----------
        # from tb: clear_state at t=0, program 1 runs for 14 cycles @ 10 ns/cycle
        # reset pulses at t=0 for 2 cycles, then program starts at t≈20
        t0, t1 = 0, 300
        rows = [
            ("clk",          clk_s,  ev(clk_s)),
            ("reset",        rst_s,  ev(rst_s)),
            ("debug_pc",     pc_s,   ev(pc_s)),
            ("debug_instr",  inst_s, ev(inst_s)),
            ("$t2 (reg[10])",t2_s,   ev(t2_s)),
            ("mem_write",    mwr_s,  ev(mwr_s)),
            ("alu_result",   alur_s, ev(alur_s)),
        ]
        bus_set = {pc_s, inst_s, t2_s, alur_s}
        make_fig("CPU Waveform – Array Sum [10,20,30,40,50] → $t2=150",
                 rows, t0, t1, ts, bus_set,
                 "diagrams/08_wave_array_sum.png")

        # ---- 09: factorial (program 3)
        # program 3 starts after program 1 (≈300 ns) and 2 (≈530 ns)
        # rough offsets; use a wide window
        t0, t1 = 580, 1850
        rows = [
            ("clk",          clk_s,  ev(clk_s)),
            ("reset",        rst_s,  ev(rst_s)),
            ("debug_pc",     pc_s,   ev(pc_s)),
            ("$t2 (reg[10])",t2_s,   ev(t2_s)),
            ("branch",       branch_s, ev(branch_s)),
            ("alu_zero",     zero_s,   ev(zero_s)),
            ("jump",         jump_s,   ev(jump_s)),
            ("alu_result",   alur_s,   ev(alur_s)),
        ]
        bus_set = {pc_s, t2_s, alur_s}
        make_fig("CPU Waveform – Factorial 5! → $t2=120  (branch/jump visible)",
                 rows, t0, t1, ts, bus_set,
                 "diagrams/09_wave_factorial.png")

        # ---- 10: reset waveform – zoom on a reset pulse --------------------
        # First reset at t≈0 (2 cycles = 20 ns)
        t0, t1 = 0, 50
        rows = [
            ("clk",          clk_s,  ev(clk_s)),
            ("reset",        rst_s,  ev(rst_s)),
            ("debug_pc",     pc_s,   ev(pc_s)),
            ("$t2 (reg[10])",t2_s,   ev(t2_s)),
        ]
        bus_set = {pc_s, t2_s}
        make_fig("CPU Waveform – Reset clears PC and registers to 0",
                 rows, t0, t1, ts, bus_set,
                 "diagrams/10_wave_reset.png")

        # ---- 11: jump test (program 4) – PC jumps 0x08 → 0x10 -------------
        # program 4 runs last; find approximate start from endtime
        # program 4 is ≈9 instructions; it starts after prog 3 finishes
        t0, t1 = 1860, 2080
        rows = [
            ("clk",          clk_s,  ev(clk_s)),
            ("debug_pc",     pc_s,   ev(pc_s)),
            ("debug_instr",  inst_s, ev(inst_s)),
            ("jump",         jump_s, ev(jump_s)),
            ("mem_write",    mwr_s,  ev(mwr_s)),
            ("alu_result",   alur_s, ev(alur_s)),
        ]
        bus_set = {pc_s, inst_s, alur_s}
        make_fig("CPU Waveform – Jump Test: J skips 0x0C (PC 0x08→0x10), SW/LW at addr 4",
                 rows, t0, t1, ts, bus_set,
                 "diagrams/11_wave_jump_test.png")

    # -----------------------------------------------------------------------
    # ALU waveform (tb_alu.vcd)
    # -----------------------------------------------------------------------
    alu_vcd = "tb_alu.vcd"
    if not os.path.exists(alu_vcd):
        print(f"[WARN] {alu_vcd} not found – skipping ALU waveform")
    else:
        print(f"Parsing {alu_vcd} ...")
        sig, endtime, ts = _parse_vcd_manual(alu_vcd)
        print(f"  Signals: {len(sig)}  endtime={endtime}  timescale={ts} ns")

        a_s    = get_signal(sig, "uut.a", "a")
        b_s    = get_signal(sig, "uut.b", "b")
        ctrl_s = get_signal(sig, "uut.alu_control", "alu_control")
        res_s  = get_signal(sig, "uut.result", "result")
        z_s    = get_signal(sig, "uut.zero", "zero")

        def ev(name): return sig.get(name, [])

        t0, t1 = 0, min(endtime, int(500 / ts))
        rows = [
            ("a",           a_s,    ev(a_s)),
            ("b",           b_s,    ev(b_s)),
            ("alu_control", ctrl_s, ev(ctrl_s)),
            ("result",      res_s,  ev(res_s)),
            ("zero",        z_s,    ev(z_s)),
        ]
        bus_set = {a_s, b_s, res_s, ctrl_s}
        make_fig("ALU Waveform – a, b, alu_control, result, zero  (first 500 ns)",
                 rows, t0, t1, ts, bus_set,
                 "diagrams/12_wave_alu.png")

    print("Done.")


if __name__ == "__main__":
    main()
