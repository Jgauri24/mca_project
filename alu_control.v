// ============================================================================
// File: alu_control.v
// Module: alu_control
// Description: ALU Control Decoder for 32-bit single-cycle MIPS CPU.
// Standard: Verilog-2001
// Supported ALU Operations: ADD (0010), SUB (0110), AND (0000), OR (0001), SLT (0111)
// ============================================================================

module alu_control (
    input  wire [1:0] ALUOp,
    input  wire [5:0] funct,
    output reg  [3:0] ALUControl
);

    // ALUControl Operation Codes
    localparam ALU_AND = 4'b0000;
    localparam ALU_OR  = 4'b0001;
    localparam ALU_ADD = 4'b0010;
    localparam ALU_SUB = 4'b0110;
    localparam ALU_SLT = 4'b0111;

    // R-Type Function Codes
    localparam FUNCT_ADD = 6'b100000;
    localparam FUNCT_SUB = 6'b100010;
    localparam FUNCT_AND = 6'b100100;
    localparam FUNCT_OR  = 6'b100101;
    localparam FUNCT_SLT = 6'b101010;

    always @(*) begin
        // Safe default assignment to prevent latches
        ALUControl = ALU_AND;

        case (ALUOp)
            2'b00: begin
                // LW, SW, ADDI: Perform Addition
                ALUControl = ALU_ADD;
            end

            2'b01: begin
                // BEQ: Perform Subtraction
                ALUControl = ALU_SUB;
            end

            2'b10: begin
                // R-Type: Decode function code
                case (funct)
                    FUNCT_ADD: ALUControl = ALU_ADD;
                    FUNCT_SUB: ALUControl = ALU_SUB;
                    FUNCT_AND: ALUControl = ALU_AND;
                    FUNCT_OR:  ALUControl = ALU_OR;
                    FUNCT_SLT: ALUControl = ALU_SLT;
                    default:   ALUControl = ALU_AND; // Safe default for unknown funct
                endcase
            end

            default: begin
                // Safe default for undefined ALUOp
                ALUControl = ALU_AND;
            end
        endcase
    end

endmodule

