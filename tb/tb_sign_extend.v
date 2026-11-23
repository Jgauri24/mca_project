// ============================================================================
// File: tb_sign_extend.v
// Module: tb_sign_extend
// Description: Comprehensive Self-Checking Testbench for Sign Extension Unit
// Standard: Verilog-2001
// Lead: Member 2 (Execution Unit)
// Coverage:
//   - Positive 16-bit immediates (sign bit 15 = 0, zero-extended upper 16 bits)
//   - Negative 16-bit immediates (sign bit 15 = 1, one-extended upper 16 bits)
//   - Boundary values (0x0000, 0x0001, 0x7FFF, 0x8000, 0xFFFF)
//   - Immediate combinational propagation verification
// ============================================================================

`timescale 1ns / 1ps

module tb_sign_extend;

    // Testbench Stimulus Signal
    reg  [15:0] in;

    // UUT Output Signal
    wire [31:0] out;

    // Test Tracking Variables
    integer pass_count;
    integer fail_count;
    integer test_id;

    // Instantiate Sign Extension UUT
    sign_extend uut (
        .in  (in),
        .out (out)
    );

    // Helper task to check and report sign extension
    task check_ext;
        input [31:0]  exp_out;
        input [127:0] test_name;
        begin
            #2; // Combinational propagation delay
            test_id = test_id + 1;
            if (out === exp_out) begin
                $display("[PASS] Test %02d | %s | In=%h (%b) => Out=%h",
                         test_id, test_name, in, in[15], out);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %02d | %s | In=%h (%b) => Expected Out=%h | Got=%h",
                         test_id, test_name, in, in[15], exp_out, out);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        // VCD waveform dump for GTKWave
        $dumpfile("tb_sign_extend.vcd");
        $dumpvars(0, tb_sign_extend);

        in         = 16'h0000;
        pass_count = 0;
        fail_count = 0;
        test_id    = 0;

        $display("==================================================================");
        $display("Starting Sign Extension Comprehensive Verification (Member 2)");
        $display("==================================================================");

        // --------------------------------------------------------------------
        // 1. Positive Immediates (MSB in[15] == 0)
        // --------------------------------------------------------------------
        $display("\n--- 1. Testing Positive Immediates (Upper 16 bits must be 0x0000) ---");
        // Zero
        in = 16'h0000;
        check_ext(32'h0000_0000, "Zero Immediate (0)");

        // Small positive number (+1)
        in = 16'h0001;
        check_ext(32'h0000_0001, "Small Positive (+1)");

        // Typical offset / immediate (+42)
        in = 16'h002A;
        check_ext(32'h0000_002A, "Positive Immediate (+42)");

        // Alternating bit pattern with MSB = 0
        in = 16'h5555;
        check_ext(32'h0000_5555, "Alternating Bits (0x5555)");

        // Maximum 16-bit positive signed integer (+32767)
        in = 16'h7FFF;
        check_ext(32'h0000_7FFF, "Max Positive 16-bit Int (0x7FFF)");

        // --------------------------------------------------------------------
        // 2. Negative Immediates (MSB in[15] == 1)
        // --------------------------------------------------------------------
        $display("\n--- 2. Testing Negative Immediates (Upper 16 bits must be 0xFFFF) ---");
        // Minus One (-1, 0xFFFF)
        in = 16'hFFFF;
        check_ext(32'hFFFF_FFFF, "Minus One (-1)");

        // Minus Two (-2, 0xFFFE)
        in = 16'hFFFE;
        check_ext(32'hFFFF_FFFE, "Minus Two (-2)");

        // Small negative offset (-16, 0xFFF0)
        in = 16'hFFF0;
        check_ext(32'hFFFF_FFF0, "Branch Backwards (-16)");

        // Alternating bit pattern with MSB = 1
        in = 16'hAAAA;
        check_ext(32'hFFFF_AAAA, "Alternating Bits (0xAAAA)");

        // Minimum 16-bit negative signed integer (-32768, 0x8000)
        in = 16'h8000;
        check_ext(32'hFFFF_8000, "Min Negative 16-bit Int (0x8000)");

        // Min Negative + 1 (-32767, 0x8001)
        in = 16'h8001;
        check_ext(32'hFFFF_8001, "Negative Boundary (0x8001)");

        // --------------------------------------------------------------------
        // Final Summary
        // --------------------------------------------------------------------
        $display("\n==================================================================");
        $display("Sign Extension Test Summary: %0d Passed, %0d Failed", pass_count, fail_count);
        $display("==================================================================");

        if (fail_count == 0) begin
            $display(">>> ALL SIGN EXTENSION TESTS PASSED SUCCESSFULLY! <<<\n");
        end else begin
            $display(">>> SOME SIGN EXTENSION TESTS FAILED! <<<\n");
        end

        $finish;
    end

endmodule

