// ============================================================================
// File: sign_extend.v
// Module: sign_extend
// Description: 16-bit to 32-bit Sign Extension Unit for MIPS Immediate Operands
// Standard: Verilog-2001
// Lead: Member 2 (Execution Unit)
// Operation:
//   Replicates sign bit (bit 15) across the upper 16 bits of the 32-bit output.
//   Preserves two's complement value for negative and positive immediates.
// ============================================================================

`timescale 1ns / 1ps

module sign_extend (
    input  wire [15:0] in,  // 16-bit immediate input from instruction[15:0]
    output wire [31:0] out  // 32-bit sign-extended output
);

    // Combinational Sign Extension:
    // Upper 16 bits replicate the MSB (sign bit: in[15]), lower 16 bits retain original input.
    assign out = {{16{in[15]}}, in};

endmodule

