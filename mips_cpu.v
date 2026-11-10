// ============================================================================
// File: mips_cpu.v
// Module: mips_cpu
// Description: Top-Level 32-bit Single-Cycle MIPS Processor
// Standard: Verilog-2001
// Lead: Member 1 (Control Unit & Processor Integration)
// ============================================================================

module mips_cpu (
    input  wire        clk,
    input  wire        reset,
    output wire [31:0] debug_pc,
    output wire [31:0] debug_instruction
);

    // ========================================================================
    // Internal Datapath Wires & Buses
    // ========================================================================

    // PC & Instruction
    wire [31:0] pc_current;
    wire [31:0] pc_next;
    wire [31:0] instruction;

    // Control Unit Signals (Member 1)
    wire        reg_dst;
    wire        reg_write;
    wire        alu_src;
    wire [1:0]  alu_op;
    wire        mem_read;
    wire        mem_write;
    wire        mem_to_reg;
    wire        branch;
    wire        jump;

    // Register File Wires (Member 2)
    wire [4:0]  write_reg_addr;
    wire [31:0] reg_write_data;
    wire [31:0] reg_read_data1;
    wire [31:0] reg_read_data2;

    // Sign Extension Wires (Member 2)
    wire [31:0] sign_extended_imm;

    // ALU Control & ALU Wires (Member 1 & Member 2)
    wire [3:0]  alu_control_signal;
    wire [31:0] alu_operand2;
    wire [31:0] alu_result;
    wire        alu_zero;

    // Data Memory Wires (Member 3)
    wire [31:0] mem_read_data;

    // Assign Debug Outputs
    assign debug_pc          = pc_current;
    assign debug_instruction = instruction;

    // ========================================================================
    // Member 1 Modules: PC & Fetch/Branch Control
    // ========================================================================

    // 1. Program Counter Register
    pc u_pc (
        .clk        (clk),
        .reset      (reset),
        .next_pc    (pc_next),
        .current_pc (pc_current)
    );

    // 2. Branch & Jump Calculation Logic
    branch_jump u_branch_jump (
        .pc                (pc_current),
        .immediate         (sign_extended_imm),
        .instruction_index (instruction[25:0]),
        .branch            (branch),
        .jump              (jump),
        .zero              (alu_zero),
        .next_pc           (pc_next)
    );

    // ========================================================================
    // Member 3 Module: Instruction Memory
    // ========================================================================

    instruction_memory u_imem (
        .address     (pc_current),
        .instruction (instruction)
    );

    // ========================================================================
    // Member 1 Modules: Control Logic
    // ========================================================================

    // Main Control Unit
    control_unit u_control_unit (
        .opcode   (instruction[31:26]),
        .RegDst   (reg_dst),
        .RegWrite (reg_write),
        .ALUSrc   (alu_src),
        .ALUOp    (alu_op),
        .MemRead  (mem_read),
        .MemWrite (mem_write),
        .MemToReg (mem_to_reg),
        .Branch   (branch),
        .Jump     (jump)
    );

    // ALU Control Decoder
    alu_control u_alu_control (
        .ALUOp      (alu_op),
        .funct      (instruction[5:0]),
        .ALUControl (alu_control_signal)
    );

    // ========================================================================
    // Member 2 Modules: Register File & Immediate Extension
    // ========================================================================

    // RegDst Multiplexer: Select rd (15:11) for R-type or rt (20:16) for I-type
    assign write_reg_addr = (reg_dst) ? instruction[15:11] : instruction[20:16];

    // Register File
    register_file u_register_file (
        .clk        (clk),
        .reg_write  (reg_write),
        .read_reg1  (instruction[25:21]), // rs
        .read_reg2  (instruction[20:16]), // rt
        .write_reg  (write_reg_addr),
        .write_data (reg_write_data),
        .read_data1 (reg_read_data1),
        .read_data2 (reg_read_data2)
    );

    // Sign Extension Unit
    sign_extend u_sign_extend (
        .in  (instruction[15:0]),
        .out (sign_extended_imm)
    );

    // ========================================================================
    // Member 2 Module: Arithmetic Logic Unit (ALU)
    // ========================================================================

    // ALUSrc Multiplexer: Select register rt or sign-extended immediate
    assign alu_operand2 = (alu_src) ? sign_extended_imm : reg_read_data2;

    // ALU
    alu u_alu (
        .a           (reg_read_data1),
        .b           (alu_operand2),
        .alu_control (alu_control_signal),
        .result      (alu_result),
        .zero        (alu_zero)
    );

    // ========================================================================
    // Member 3 Module: Data Memory
    // ========================================================================

    data_memory u_dmem (
        .clk        (clk),
        .mem_read   (mem_read),
        .mem_write  (mem_write),
        .address    (alu_result),
        .write_data (reg_read_data2),
        .read_data  (mem_read_data)
    );

    // ========================================================================
    // Writeback Multiplexer: ALU Result vs Memory Read Data
    // ========================================================================

    // MemToReg Multiplexer: Select memory data (LW) or ALU result
    assign reg_write_data = (mem_to_reg) ? mem_read_data : alu_result;

endmodule

