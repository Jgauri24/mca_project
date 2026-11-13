// ============================================================================
// File: instruction_memory.v
// Module: instruction_memory
// Description: Read-only Instruction Memory (ROM) for the 32-bit single-cycle
//              MIPS processor. Holds 256 x 32-bit instructions (1 KB).
// Standard: Verilog-2001
// Lead: Member 3 (Memory Subsystem)
//
// Addressing:
//   - The CPU presents a 32-bit BYTE address (the PC).
//   - Every instruction is 4 bytes, so instructions are word-aligned and
//     the two least-significant address bits are always 2'b00.
//   - Word index = address[9:2]  (8 bits -> 256 words)
//         address 0x00 -> memory[0]
//         address 0x04 -> memory[1]
//         address 0x08 -> memory[2]
//
// Read behaviour:
//   - Purely combinational (asynchronous) read, no clock. The instruction
//     appears on the output in the same cycle the PC changes, which is what
//     a single-cycle datapath requires.
//
// Invalid address handling:
//   - Out-of-range address (any of address[31:10] set, i.e. >= 1024) or
//     unaligned address (address[1:0] != 2'b00) returns 32'h0000_0000.
//   - 32'h0000_0000 decodes as "sll $zero, $zero, 0", the canonical MIPS
//     NOP, so a stray fetch can never write a register or memory.
// ============================================================================

`timescale 1ns / 1ps

module instruction_memory #(
    parameter INIT_FILE = "instruction_memory.mem"
)(
    input  [31:0] address,
    output [31:0] instruction
);

    // ------------------------------------------------------------------------
    // Local parameters
    // ------------------------------------------------------------------------
    localparam MEM_DEPTH = 256;            // number of 32-bit words
    localparam NOP       = 32'h0000_0000;  // returned for invalid addresses

    // ------------------------------------------------------------------------
    // Storage: 256 words x 32 bits
    // ------------------------------------------------------------------------
    reg [31:0] memory [0:MEM_DEPTH-1];

    // ------------------------------------------------------------------------
    // Address decode
    //   word_index    : selects one of the 256 words
    //   addr_in_range : upper bits must be zero (address < 1024 bytes)
    //   addr_aligned  : lower two bits must be zero (word aligned)
    // ------------------------------------------------------------------------
    wire [7:0] word_index    = address[9:2];
    wire       addr_in_range = (address[31:10] == 22'd0);
    wire       addr_aligned  = (address[1:0]   == 2'b00);
    wire       addr_valid    = addr_in_range & addr_aligned;

    // ------------------------------------------------------------------------
    // Combinational read with safe default for invalid addresses
    // ------------------------------------------------------------------------
    assign instruction = addr_valid ? memory[word_index] : NOP;

    // ------------------------------------------------------------------------
    // Memory initialisation
    //   1. Fill every word with NOP so that locations not listed in the
    //      .mem file read as a defined value instead of 'x'.
    //   2. Load the program from INIT_FILE with $readmemh. The file holds one
    //      32-bit hexadecimal word per line, starting at memory[0].
    //
    //   NOTE: initial blocks and $readmemh are honoured by simulators
    //   (Icarus, ModelSim, Vivado XSim). FPGA synthesis tools such as Vivado
    //   and Quartus also support $readmemh in an initial block to set the
    //   power-up contents of ROM/BRAM. ASIC flows ignore initial blocks.
    // ------------------------------------------------------------------------
    integer i;
    initial begin
        for (i = 0; i < MEM_DEPTH; i = i + 1) begin
            memory[i] = NOP;
        end
        $readmemh(INIT_FILE, memory);
    end

endmodule
