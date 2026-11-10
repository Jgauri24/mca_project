// ============================================================================
// File: control_unit.v
// Module: control_unit
// Description: Main control decoder for 32-bit single-cycle MIPS CPU.
// Standard: Verilog-2001
// Supported Instructions: R-type, LW, SW, ADDI, BEQ, J
// ============================================================================

module control_unit (
    input  wire [5:0] opcode,
    output reg        RegDst,
    output reg        RegWrite,
    output reg        ALUSrc,
    output reg  [1:0] ALUOp,
    output reg        MemRead,
    output reg        MemWrite,
    output reg        MemToReg,
    output reg        Branch,
    output reg        Jump
);

    // MIPS Opcode Definitions
    localparam OP_RTYPE = 6'b000000;
    localparam OP_LW    = 6'b100011;
    localparam OP_SW    = 6'b101011;
    localparam OP_ADDI  = 6'b001000;
    localparam OP_BEQ   = 6'b000100;
    localparam OP_J     = 6'b000010;

    always @(*) begin
        // Default values to prevent unintended latches
        // and guarantee all signals are 0 for unsupported opcodes
        RegDst   = 1'b0;
        RegWrite = 1'b0;
        ALUSrc   = 1'b0;
        ALUOp    = 2'b00;
        MemRead  = 1'b0;
        MemWrite = 1'b0;
        MemToReg = 1'b0;
        Branch   = 1'b0;
        Jump     = 1'b0;

        case (opcode)
            OP_RTYPE: begin
                RegDst   = 1'b1;     // Destination is rd (instruction[15:11])
                RegWrite = 1'b1;     // Write result to register file
                ALUSrc   = 1'b0;     // Second ALU operand from register (rt)
                ALUOp    = 2'b10;    // Function field specifies operation
                MemRead  = 1'b0;
                MemWrite = 1'b0;
                MemToReg = 1'b0;     // Write ALU result back to register
                Branch   = 1'b0;
                Jump     = 1'b0;
            end

            OP_LW: begin
                RegDst   = 1'b0;     // Destination is rt (instruction[20:16])
                RegWrite = 1'b1;     // Write loaded word to register file
                ALUSrc   = 1'b1;     // Second ALU operand is sign-extended immediate
                ALUOp    = 2'b00;    // Add for address computation (base + offset)
                MemRead  = 1'b1;     // Read data from memory
                MemWrite = 1'b0;
                MemToReg = 1'b1;     // Write memory data back to register
                Branch   = 1'b0;
                Jump     = 1'b0;
            end

            OP_SW: begin
                RegDst   = 1'b0;     // Don't care (no register write)
                RegWrite = 1'b0;     // No register file write
                ALUSrc   = 1'b1;     // Second ALU operand is sign-extended immediate
                ALUOp    = 2'b00;    // Add for address computation (base + offset)
                MemRead  = 1'b0;
                MemWrite = 1'b1;     // Write data to memory
                MemToReg = 1'b0;     // Don't care
                Branch   = 1'b0;
                Jump     = 1'b0;
            end

            OP_ADDI: begin
                RegDst   = 1'b0;     // Destination is rt (instruction[20:16])
                RegWrite = 1'b1;     // Write result to register file
                ALUSrc   = 1'b1;     // Second ALU operand is sign-extended immediate
                ALUOp    = 2'b00;    // Add operation (rs + immediate)
                MemRead  = 1'b0;
                MemWrite = 1'b0;
                MemToReg = 1'b0;     // Write ALU result back to register
                Branch   = 1'b0;
                Jump     = 1'b0;
            end

            OP_BEQ: begin
                RegDst   = 1'b0;     // Don't care
                RegWrite = 1'b0;     // No register write
                ALUSrc   = 1'b0;     // Second ALU operand from register (rt)
                ALUOp    = 2'b01;    // Subtract to compare rs and rt
                MemRead  = 1'b0;
                MemWrite = 1'b0;
                MemToReg = 1'b0;     // Don't care
                Branch   = 1'b1;     // Branch signal asserted
                Jump     = 1'b0;
            end

            OP_J: begin
                RegDst   = 1'b0;     // Don't care
                RegWrite = 1'b0;     // No register write
                ALUSrc   = 1'b0;     // Don't care
                ALUOp    = 2'b00;    // Don't care
                MemRead  = 1'b0;
                MemWrite = 1'b0;
                MemToReg = 1'b0;     // Don't care
                Branch   = 1'b0;
                Jump     = 1'b1;     // Unconditional jump asserted
            end

            default: begin
                // All outputs remain 1'b0 as assigned in defaults above
                RegDst   = 1'b0;
                RegWrite = 1'b0;
                ALUSrc   = 1'b0;
                ALUOp    = 2'b00;
                MemRead  = 1'b0;
                MemWrite = 1'b0;
                MemToReg = 1'b0;
                Branch   = 1'b0;
                Jump     = 1'b0;
            end
        endcase
    end

endmodule

