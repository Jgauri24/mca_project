// ============================================================================
// File: alu.v
// Module: alu
// Description: 32-bit Arithmetic Logic Unit (ALU) for Single-Cycle MIPS CPU
// Standard: Verilog-2001
// Lead: Member 2 (Execution Unit)
// Supported Operations:
//   4'b0000: Bitwise AND
//   4'b0001: Bitwise OR
//   4'b0010: ADD (Signed / Unsigned Addition)
//   4'b0110: SUB (Signed / Unsigned Subtraction)
//   4'b0111: SLT (Set on Less Than - Signed Comparison)
// ============================================================================

`timescale 1ns / 1ps

module alu (
    input  wire [31:0] a,           // First ALU operand (from rs register)
    input  wire [31:0] b,           // Second ALU operand (from rt or sign-extended immediate)
    input  wire [3:0]  alu_control, // 4-bit ALU control code from alu_control decoder
    output reg  [31:0] result,      // 32-bit ALU operation result
    output wire        zero         // Zero condition flag (asserted 1 when result is zero)
);

    // ALU Operation Encodings - Exact match with alu_control.v
    localparam ALU_AND = 4'b0000;
    localparam ALU_OR  = 4'b0001;
    localparam ALU_ADD = 4'b0010;
    localparam ALU_SUB = 4'b0110;
    localparam ALU_SLT = 4'b0111;

    // Combinational ALU Computation
    always @(*) begin
        // Safe default assignment to guarantee latch-free combinational logic
        result = 32'h0000_0000;

        case (alu_control)
            ALU_AND: begin
                result = a & b;
            end

            ALU_OR: begin
                result = a | b;
            end

            ALU_ADD: begin
                result = a + b;
            end

            ALU_SUB: begin
                result = a - b;
            end

            ALU_SLT: begin
                // Signed comparison for Set on Less Than (SLT)
                // In Verilog-2001, $signed treats 32-bit operands as two's complement numbers
                if ($signed(a) < $signed(b)) begin
                    result = 32'h0000_0001;
                end else begin
                    result = 32'h0000_0000;
                end
            end

            default: begin
                // Safe default for undefined control codes
                result = 32'h0000_0000;
            end
        endcase
    end

    // Zero Flag Generation: Asserted when result equals 0 (used for BEQ branch decision)
    assign zero = (result == 32'h0000_0000) ? 1'b1 : 1'b0;

endmodule

