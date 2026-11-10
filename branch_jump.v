// ============================================================================
// File: branch_jump.v
// Module: branch_jump
// Description: Branch and Jump Target Calculation & Next PC Selection Logic
// Standard: Verilog-2001
// ============================================================================

module branch_jump (
    input  wire [31:0] pc,
    input  wire [31:0] immediate,
    input  wire [25:0] instruction_index,
    input  wire        branch,
    input  wire        jump,
    input  wire        zero,
    output reg  [31:0] next_pc
);

    // 1. Calculate PC + 4 in a separate wire for Verilog-2001 compatibility
    wire [31:0] pc_plus_4;
    assign pc_plus_4 = pc + 32'd4;

    // 2. Calculate branch target: PC + 4 + (immediate << 2)
    wire [31:0] branch_target;
    assign branch_target = pc_plus_4 + (immediate << 2);

    // 3. Calculate jump target: {(PC + 4)[31:28], instruction_index, 2'b00}
    wire [31:0] jump_target;
    assign jump_target = {pc_plus_4[31:28], instruction_index, 2'b00};

    // 4. Branch taken condition
    wire take_branch;
    assign take_branch = branch & zero;

    // 5. Next PC Selection Priority
    // Priority: Jump > Branch (taken) > PC + 4
    always @(*) begin
        if (jump) begin
            next_pc = jump_target;
        end else if (take_branch) begin
            next_pc = branch_target;
        end else begin
            next_pc = pc_plus_4;
        end
    end

endmodule

