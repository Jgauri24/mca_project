// ============================================================================
// File: data_memory.v
// Module: data_memory
// Description: Read/Write Data Memory (RAM) for the 32-bit single-cycle MIPS
//              processor. Holds 256 x 32-bit words (1 KB). Used by LW / SW.
// Standard: Verilog-2001
// Reset: Active-high synchronous reset (clears every word to zero)
// Lead: Member 3 (Memory Subsystem)
//
// Addressing:
//   - Byte-addressed 32-bit interface (address comes from the ALU result).
//   - Only word-aligned accesses are supported.
//   - Word index = address[9:2]  (8 bits -> 256 words)
//         address  0 -> memory[0]
//         address  4 -> memory[1]
//         address  8 -> memory[2]
//         address 12 -> memory[3]
//
// Read  : Combinational. read_data = memory[index] when mem_read = 1 and the
//         address is valid, otherwise read_data = 0.
// Write : Synchronous, on the rising edge of clk, only when mem_write = 1,
//         reset = 0 and the address is valid.
//
// Invalid / unaligned addresses:
//   - Valid address = (address[31:10] == 0) AND (address[1:0] == 2'b00).
//   - Writes to an invalid address are ignored (memory unchanged).
//   - Reads from an invalid address return 32'h0000_0000.
//
// Simultaneous mem_read = 1 and mem_write = 1 (read-before-write):
//   - During the cycle, read_data shows the OLD contents of the location.
//   - The new value is stored at the rising edge and becomes visible on
//     read_data immediately after that edge.
//   - The main control unit never asserts both, but the behaviour is fully
//     defined in case it happens.
//
// Reset priority:
//   - reset has priority over mem_write on the same clock edge.
// ============================================================================

`timescale 1ns / 1ps

module data_memory(
    input clk,
    input reset,
    input [31:0] address,
    input [31:0] write_data,
    input mem_read,
    input mem_write,
    output reg [31:0] read_data
);

    // ------------------------------------------------------------------------
    // Local parameters
    // ------------------------------------------------------------------------
    localparam MEM_DEPTH = 256;

    // ------------------------------------------------------------------------
    // Storage: 256 words x 32 bits
    // ------------------------------------------------------------------------
    reg [31:0] memory [0:MEM_DEPTH-1];

    // ------------------------------------------------------------------------
    // Address decode
    // ------------------------------------------------------------------------
    wire [7:0] word_index    = address[9:2];
    wire       addr_in_range = (address[31:10] == 22'd0);
    wire       addr_aligned  = (address[1:0]   == 2'b00);
    wire       addr_valid    = addr_in_range & addr_aligned;

    // ------------------------------------------------------------------------
    // Synchronous write / synchronous reset (non-blocking assignments)
    // ------------------------------------------------------------------------
    integer i;
    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < MEM_DEPTH; i = i + 1) begin
                memory[i] <= 32'h0000_0000;
            end
        end else if (mem_write && addr_valid) begin
            memory[word_index] <= write_data;
        end
    end

    // ------------------------------------------------------------------------
    // Combinational read. read_data is assigned on every path, so no latch
    // is inferred.
    // ------------------------------------------------------------------------
    always @(*) begin
        if (mem_read && addr_valid) begin
            read_data = memory[word_index];
        end else begin
            read_data = 32'h0000_0000;
        end
    end

endmodule
