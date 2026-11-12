// ============================================================================
// File: tb_alu.v
// Module: tb_alu
// Description: Comprehensive Self-Checking Testbench for 32-bit ALU
// Standard: Verilog-2001
// Lead: Member 2 (Execution Unit)
// Coverage:
//   - All supported operations (ADD, SUB, AND, OR, SLT, Undefined)
//   - Positive and negative numbers (Two's complement)
//   - Zero results and Zero flag verification
//   - Boundary values (0x00000000, 0xFFFFFFFF, 0x7FFFFFFF, 0x80000000)
//   - Signed comparison correctness for SLT
// ============================================================================

`timescale 1ns / 1ps

module tb_alu;

    // Testbench Stimulus Signals
    reg  [31:0] a;
    reg  [31:0] b;
    reg  [3:0]  alu_control;

    // Unit Under Test (UUT) Outputs
    wire [31:0] result;
    wire        zero;

    // Test Tracking Variables
    integer pass_count;
    integer fail_count;
    integer test_id;

    // Instantiate UUT
    alu uut (
        .a           (a),
        .b           (b),
        .alu_control (alu_control),
        .result      (result),
        .zero        (zero)
    );

    // ALU Operation Codes
    localparam ALU_AND = 4'b0000;
    localparam ALU_OR  = 4'b0001;
    localparam ALU_ADD = 4'b0010;
    localparam ALU_SUB = 4'b0110;
    localparam ALU_SLT = 4'b0111;

    // Task to check outputs and report errors
    task check_alu;
        input [31:0] exp_result;
        input        exp_zero;
        input [127:0] test_name;
        begin
            #5; // Wait for combinational propagation
            test_id = test_id + 1;
            if (result === exp_result && zero === exp_zero) begin
                $display("[PASS] Test %02d | %s | A=%h, B=%h, Ctrl=%b => Result=%h, Zero=%b",
                         test_id, test_name, a, b, alu_control, result, zero);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %02d | %s | A=%h, B=%h, Ctrl=%b => Expected Result=%h, Zero=%b | Got Result=%h, Zero=%b",
                         test_id, test_name, a, b, alu_control, exp_result, exp_zero, result, zero);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        // VCD waveform generation for GTKWave
        $dumpfile("tb_alu.vcd");
        $dumpvars(0, tb_alu);

        pass_count = 0;
        fail_count = 0;
        test_id    = 0;

        $display("==================================================================");
        $display("Starting ALU Comprehensive Verification (Member 2)");
        $display("==================================================================");

        // --------------------------------------------------------------------
        // 1. ADD Operation (4'b0010)
        // --------------------------------------------------------------------
        $display("\n--- Testing ADD Operation (ALUControl = 0010) ---");
        // Positive + Positive
        a = 32'd25; b = 32'd15; alu_control = ALU_ADD;
        check_alu(32'd40, 1'b0, "ADD Pos+Pos");

        // Positive + Negative
        a = 32'd50; b = -32'd20; alu_control = ALU_ADD;
        check_alu(32'd30, 1'b0, "ADD Pos+Neg");

        // Negative + Negative
        a = -32'd10; b = -32'd30; alu_control = ALU_ADD;
        check_alu(-32'd40, 1'b0, "ADD Neg+Neg");

        // Zero Result (Zero flag assertion)
        a = 32'd100; b = -32'd100; alu_control = ALU_ADD;
        check_alu(32'd0, 1'b1, "ADD Zero Result");

        // Boundary: Overflow Wraparound (0x7FFFFFFF + 1 = 0x80000000)
        a = 32'h7FFF_FFFF; b = 32'h0000_0001; alu_control = ALU_ADD;
        check_alu(32'h8000_0000, 1'b0, "ADD MaxInt+1");

        // Boundary: 0xFFFFFFFF + 1 = 0x00000000
        a = 32'hFFFF_FFFF; b = 32'h0000_0001; alu_control = ALU_ADD;
        check_alu(32'h0000_0000, 1'b1, "ADD WraparoundZero");

        // --------------------------------------------------------------------
        // 2. SUB Operation (4'b0110)
        // --------------------------------------------------------------------
        $display("\n--- Testing SUB Operation (ALUControl = 0110) ---");
        // Positive - Positive
        a = 32'd100; b = 32'd40; alu_control = ALU_SUB;
        check_alu(32'd60, 1'b0, "SUB Pos-Pos");

        // Equal Values (BEQ condition: Zero Flag asserted)
        a = 32'hA5A5_5A5A; b = 32'hA5A5_5A5A; alu_control = ALU_SUB;
        check_alu(32'd0, 1'b1, "SUB Equal (BEQ=1)");

        // Unequal Values (BEQ condition: Zero Flag deasserted)
        a = 32'd100; b = 32'd99; alu_control = ALU_SUB;
        check_alu(32'd1, 1'b0, "SUB Unequal (BEQ=0)");

        // Positive - Negative
        a = 32'd20; b = -32'd10; alu_control = ALU_SUB;
        check_alu(32'd30, 1'b0, "SUB Pos-Neg");

        // Negative - Positive
        a = -32'd20; b = 32'd10; alu_control = ALU_SUB;
        check_alu(-32'd30, 1'b0, "SUB Neg-Pos");

        // Boundary: 0x80000000 - 1 = 0x7FFFFFFF
        a = 32'h8000_0000; b = 32'h0000_0001; alu_control = ALU_SUB;
        check_alu(32'h7FFF_FFFF, 1'b0, "SUB MinInt-1");

        // --------------------------------------------------------------------
        // 3. AND Operation (4'b0000)
        // --------------------------------------------------------------------
        $display("\n--- Testing AND Operation (ALUControl = 0000) ---");
        // Complementary bit patterns (Result 0 => Zero = 1)
        a = 32'hAAAA_AAAA; b = 32'h5555_5555; alu_control = ALU_AND;
        check_alu(32'h0000_0000, 1'b1, "AND Complementary");

        // All 1s mask
        a = 32'hFFFF_FFFF; b = 32'h1234_5678; alu_control = ALU_AND;
        check_alu(32'h1234_5678, 1'b0, "AND Mask All 1s");

        // High bit only
        a = 32'h8000_0000; b = 32'h8000_0000; alu_control = ALU_AND;
        check_alu(32'h8000_0000, 1'b0, "AND MSB Only");

        // --------------------------------------------------------------------
        // 4. OR Operation (4'b0001)
        // --------------------------------------------------------------------
        $display("\n--- Testing OR Operation (ALUControl = 0001) ---");
        // Complementary bit patterns (Result 0xFFFFFFFF)
        a = 32'hAAAA_AAAA; b = 32'h5555_5555; alu_control = ALU_OR;
        check_alu(32'hFFFF_FFFF, 1'b0, "OR Complementary");

        // Zero OR Zero (Result 0 => Zero = 1)
        a = 32'h0000_0000; b = 32'h0000_0000; alu_control = ALU_OR;
        check_alu(32'h0000_0000, 1'b1, "OR Zero|Zero");

        // Lower and Upper Half Merge
        a = 32'h0000_FFFF; b = 32'hFFFF_0000; alu_control = ALU_OR;
        check_alu(32'hFFFF_FFFF, 1'b0, "OR Halves Merge");

        // --------------------------------------------------------------------
        // 5. SLT Operation (4'b0111) - Signed Comparisons
        // --------------------------------------------------------------------
        $display("\n--- Testing SLT Operation (ALUControl = 0111 - Signed) ---");
        // Positive vs Positive: 5 < 10 => 1
        a = 32'd5; b = 32'd10; alu_control = ALU_SLT;
        check_alu(32'd1, 1'b0, "SLT Pos < Pos (True)");

        // Positive vs Positive: 10 < 5 => 0
        a = 32'd10; b = 32'd5; alu_control = ALU_SLT;
        check_alu(32'd0, 1'b1, "SLT Pos < Pos (False)");

        // Positive vs Positive: Equal: 5 < 5 => 0
        a = 32'd5; b = 32'd5; alu_control = ALU_SLT;
        check_alu(32'd0, 1'b1, "SLT Equal (False)");

        // Negative vs Positive: -5 < 2 => 1 (Critical: tests signed vs unsigned)
        a = -32'd5; b = 32'd2; alu_control = ALU_SLT;
        check_alu(32'd1, 1'b0, "SLT Neg < Pos (True)");

        // Positive vs Negative: 2 < -5 => 0
        a = 32'd2; b = -32'd5; alu_control = ALU_SLT;
        check_alu(32'd0, 1'b1, "SLT Pos < Neg (False)");

        // Negative vs Negative: -10 < -5 => 1
        a = -32'd10; b = -32'd5; alu_control = ALU_SLT;
        check_alu(32'd1, 1'b0, "SLT Neg < Neg (True)");

        // Negative vs Negative: -5 < -10 => 0
        a = -32'd5; b = -32'd10; alu_control = ALU_SLT;
        check_alu(32'd0, 1'b1, "SLT Neg < Neg (False)");

        // Extreme Boundary: MinInt < MaxInt (0x80000000 < 0x7FFFFFFF) => 1
        a = 32'h8000_0000; b = 32'h7FFF_FFFF; alu_control = ALU_SLT;
        check_alu(32'd1, 1'b0, "SLT MinInt < MaxInt");

        // Extreme Boundary: MaxInt < MinInt (0x7FFFFFFF < 0x80000000) => 0
        a = 32'h7FFF_FFFF; b = 32'h8000_0000; alu_control = ALU_SLT;
        check_alu(32'd0, 1'b1, "SLT MaxInt < MinInt");

        // -1 vs +1: 0xFFFFFFFF < 0x00000001 => 1
        a = 32'hFFFF_FFFF; b = 32'h0000_0001; alu_control = ALU_SLT;
        check_alu(32'd1, 1'b0, "SLT -1 < +1");

        // --------------------------------------------------------------------
        // 6. Default / Undefined Control Code Fallback
        // --------------------------------------------------------------------
        $display("\n--- Testing Default Fallback ---");
        a = 32'h1234_5678; b = 32'h9ABC_DEF0; alu_control = 4'b1111;
        check_alu(32'h0000_0000, 1'b1, "ALU Default Fallback");

        // --------------------------------------------------------------------
        // Final Summary
        // --------------------------------------------------------------------
        $display("\n==================================================================");
        $display("ALU Test Summary: %0d Passed, %0d Failed", pass_count, fail_count);
        $display("==================================================================");

        if (fail_count == 0) begin
            $display(">>> ALL ALU TESTS PASSED SUCCESSFULLY! <<<\n");
        end else begin
            $display(">>> SOME ALU TESTS FAILED! <<<\n");
        end

        $finish;
    end

endmodule

