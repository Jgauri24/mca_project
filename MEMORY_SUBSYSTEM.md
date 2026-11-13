# Memory Subsystem (Member 3)

Instruction Memory and Data Memory for the 32-bit single-cycle MIPS CPU.

| File | Purpose |
|------|---------|
| `instruction_memory.v` | 256 x 32-bit instruction ROM, combinational read, `$readmemh` init |
| `instruction_memory.mem` | Sample program (8 instructions) |
| `tb_instruction_memory.v` | Self-checking testbench (21 tests) |
| `data_memory.v` | 256 x 32-bit data RAM, sync write, sync reset, combinational read |
| `tb_data_memory.v` | Self-checking testbench (30 tests) |

## Addressing (both memories)

The CPU uses byte addresses, but every access is a 32-bit word, so the word
index is `address[9:2]`:

| Address | Word |
|---------|------|
| 0  | `memory[0]` |
| 4  | `memory[1]` |
| 8  | `memory[2]` |
| 12 | `memory[3]` |

An address is valid only if `address[31:10] == 0` (inside the 1 KB range)
and `address[1:0] == 2'b00` (word aligned). Without the upper-bit check,
address `0x400` would silently alias to word 0.

## Instruction Memory

* **Read:** `assign instruction = addr_valid ? memory[address[9:2]] : NOP;`
  There is no clock, so the instruction is available in the same cycle as the PC.
* **Invalid address:** returns `32'h00000000`. That is `sll $0,$0,0`, the MIPS
  NOP, so a bad fetch can't change any state.
* **Initialisation:** an `initial` block first fills all 256 words with NOP and
  then calls `$readmemh(INIT_FILE, memory)`. Words the file doesn't cover stay NOP
  rather than `x`. You can override `INIT_FILE` per instance with
  `instruction_memory #(.INIT_FILE("prog.mem")) ...`.
* **Simulation-only notes:** `initial` and `$readmemh` are honoured by simulators.
  Vivado and Quartus also use them to set ROM/BRAM power-up contents. ASIC flows
  ignore them. Icarus prints `Not enough words in the file`
  because the file holds fewer than 256 words. The warning is harmless.

### Sample program (`instruction_memory.mem`)

| Addr | Hex | Assembly |
|------|-----|----------|
| 0x00 | 20080005 | addi $t0, $zero, 5 |
| 0x04 | 2009000A | addi $t1, $zero, 10 |
| 0x08 | 01095020 | add  $t2, $t0, $t1 |
| 0x0C | AC0A0000 | sw   $t2, 0($zero) |
| 0x10 | 8C0B0000 | lw   $t3, 0($zero) |
| 0x14 | 114B0001 | beq  $t2, $t3, +1 |
| 0x18 | 01286022 | sub  $t4, $t1, $t0 (skipped) |
| 0x1C | 08000007 | j    0x1C (halt loop) |

The program only uses opcodes that `control_unit.v` supports.

## Data Memory

* **Write:** `always @(posedge clk)` with non-blocking assignments. A word is
  written only when `mem_write == 1`, `reset == 0` and the address is valid.
* **Reset:** active-high and synchronous. On a rising edge with `reset == 1`,
  all 256 words are cleared to 0. Reset takes priority over a write.
* **Read:** `always @(*)`. `read_data = memory[idx]` when `mem_read == 1` and the
  address is valid. Otherwise it is 0. Every path assigns `read_data`, so no latch
  is inferred.
* **Invalid / unaligned:** writes are ignored and reads return 0.
* **Simultaneous read + write (read-before-write):** during the cycle, `read_data`
  shows the old contents. The new value is stored at the rising edge and shows on
  `read_data` right after it. The control unit never asserts both signals together,
  but the behaviour is still defined.

### Test cases (`tb_data_memory.v`)

| # | Scenario | Expected |
|---|----------|----------|
| 1-2 | After reset, read word 0 / 255 | 0 |
| 3 | Write 100 @0, read @0 | 100 |
| 4 | Write 200 @4, read @4 | 200 |
| 5-9 | Write @8, @12, @0x3FC; read 0,4,8,12,0x3FC | stored values |
| 10 | Overwrite @4 with 250 | 250 |
| 11-12 | `mem_read = 0` | 0 |
| 13 | `mem_write = 0` with data on bus | old value kept |
| 14-17 | Write/read @0x400, @0xFFFFFFFC | no aliasing, read 0 |
| 18-21 | Unaligned write @9, @6; read @1, @14 | ignored, read 0 |
| 22-23 | `mem_read = mem_write = 1` | old before edge, new after |
| 24-29 | Reset while `mem_write = 1` | all words 0 |
| 30 | Write/read after reset | 42 |

### FPGA synthesis limitations

* **Clearing on reset prevents block RAM inference.** BRAM can't clear all
  words in one cycle, so the tools build the memory from about 8192 flip-flops
  plus a 256:1 read mux. That is fine for a 1 KB teaching design. To get BRAM
  instead, remove the clear loop from the reset branch and rely on the
  power-up / `$readmemh` initial value.
* **Combinational (asynchronous) read.** Most FPGA block RAMs only support
  synchronous reads. Without the reset clear, an async-read memory maps to
  distributed / LUT RAM, which is what a single-cycle CPU needs anyway.
* The instruction ROM has no reset and reads asynchronously, so it maps to
  LUT ROM, initialised by `$readmemh`.

## Integration note

`mips_cpu.v` (Member 1) instantiates `u_dmem` without connecting the
`reset` port. In simulation the port floats to `z` and `if (reset)` evaluates
as false, so the memory works but is never cleared. Member 1 can add
`.reset (reset)` to the `u_dmem` instantiation to connect it. This branch does
not change `mips_cpu.v`.

## Running with Icarus Verilog

```bash
iverilog -g2001 -Wall -o sim_imem instruction_memory.v tb_instruction_memory.v
vvp sim_imem

iverilog -g2001 -Wall -o sim_dmem data_memory.v tb_data_memory.v
vvp sim_dmem

gtkwave tb_data_memory.vcd   # optional waveform view
```

Run the commands from the repository root so `instruction_memory.mem` is found.

### Expected output (abridged)

```
Starting Instruction Memory Verification (Member 3)
[PASS] Test 01 | Read addr 0 -> mem[0] | Addr=0x00000000 => Instr=0x20080005
[PASS] Test 02 | Read addr 4 -> mem[1] | Addr=0x00000004 => Instr=0x2009000a
[PASS] Test 03 | Read addr 8 -> mem[2] | Addr=0x00000008 => Instr=0x01095020
...
[PASS] Test 14 | Addr 0x400 (aliases mem[0]) | Addr=0x00000400 => Instr=0x00000000
...
Total Tests: 21 | PASSED: 21 | FAILED: 0
STATUS: ALL TESTS PASSED
```

```
Starting Data Memory Verification (Member 3)
[PASS] Test 03 | Write 100 @0, read @0 | Addr=0x00000000 MemRead=1 => Data=0x00000064 (100)
[PASS] Test 04 | Write 200 @4, read @4 | Addr=0x00000004 MemRead=1 => Data=0x000000c8 (200)
...
[PASS] Test 22 | R&W before edge shows OLD data | Data=0xcafef00d
[PASS] Test 23 | R&W after edge shows NEW data  | Data=0x00000309 (777)
...
Total Tests: 30 | PASSED: 30 | FAILED: 0
STATUS: ALL TESTS PASSED
```
