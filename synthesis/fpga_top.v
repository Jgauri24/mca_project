// ============================================================================
// File: synthesis/fpga_top.v
// Module: fpga_top
// Description: Board wrapper used only for FPGA synthesis / place-and-route.
//   The CPU exposes 64 debug output bits, which is more than a small board has
//   LEDs. This wrapper folds debug_pc and debug_instruction into 6 LEDs with
//   XOR so that all CPU logic stays observable and is not optimised away.
// Target boards: Digilent Basys3 (Artix-7, basys3.xdc) and
//               Sipeed Tang Mega 138K Pro (Gowin GW5AST, tang_mega_138k.cst)
// ============================================================================

`timescale 1ns / 1ps

module fpga_top (
    input  wire       clk,
    input  wire       reset,
    output wire [5:0] led
);
    wire [31:0] debug_pc;
    wire [31:0] debug_instruction;

    mips_cpu u_cpu (
        .clk               (clk),
        .reset             (reset),
        .debug_pc          (debug_pc),
        .debug_instruction (debug_instruction)
    );

    wire [31:0] folded = debug_pc ^ debug_instruction;

    assign led[0] = ^folded[5:0];
    assign led[1] = ^folded[11:6];
    assign led[2] = ^folded[17:12];
    assign led[3] = ^folded[23:18];
    assign led[4] = ^folded[29:24];
    assign led[5] = ^folded[31:30];
endmodule
