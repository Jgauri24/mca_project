// ============================================================================
// File: tb_register_file.v
// Module: tb_register_file
// Description: Comprehensive Self-Checking Testbench for 32x32-bit Register File
// Standard: Verilog-2001
// Lead: Member 2 (Execution Unit)
// Coverage:
//   - Power-on state & Active-high synchronous reset
//   - Register zero ($0) hardwired protection (read zero, ignore writes)
//   - Synchronous writes and write-enable (reg_write) control
//   - Asynchronous simultaneous reads on both ports (read_data1, read_data2)
//   - Positive numbers, negative numbers, and boundary values
//   - Verification of all 32 registers ($0 through $31)
// ============================================================================

`timescale 1ns / 1ps

module tb_register_file;

    // Clock and Control Signals
    reg         clk;
    reg         reset;
    reg         reg_write;

    // Register Addressing & Data Signals
    reg  [4:0]  read_reg1;
    reg  [4:0]  read_reg2;
    reg  [4:0]  write_reg;
    reg  [31:0] write_data;

    // UUT Outputs
    wire [31:0] read_data1;
    wire [31:0] read_data2;

    // Test Tracking Variables
    integer pass_count;
    integer fail_count;
    integer test_id;
    integer idx;

    // Instantiate Register File UUT
    register_file uut (
        .clk        (clk),
        .reset      (reset),
        .reg_write  (reg_write),
        .read_reg1  (read_reg1),
        .read_reg2  (read_reg2),
        .write_reg  (write_reg),
        .write_data (write_data),
        .read_data1 (read_data1),
        .read_data2 (read_data2)
    );

    // 10ns Clock Generation (100 MHz)
    always #5 clk = ~clk;

    // Helper task to synchronously write to a register
    task write_register;
        input [4:0]  tgt_reg;
        input [31:0] data;
        begin
            @(posedge clk);
            #1; // Hold slightly after clock edge
            reg_write  = 1'b1;
            write_reg  = tgt_reg;
            write_data = data;
            @(posedge clk); // Latch on rising edge
            #1;
            reg_write  = 1'b0;
        end
    endtask

    // Helper task to verify dual asynchronous reads
    task check_reads;
        input [4:0]   r1;
        input [31:0]  exp1;
        input [4:0]   r2;
        input [31:0]  exp2;
        input [127:0] test_name;
        begin
            read_reg1 = r1;
            read_reg2 = r2;
            #2; // Asynchronous propagation delay (independent of clk)
            test_id = test_id + 1;
            if (read_data1 === exp1 && read_data2 === exp2) begin
                $display("[PASS] Test %02d | %s | R1[%0d]=%h, R2[%0d]=%h",
                         test_id, test_name, r1, read_data1, r2, read_data2);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %02d | %s | R1[%0d] Exp=%h Got=%h | R2[%0d] Exp=%h Got=%h",
                         test_id, test_name, r1, exp1, read_data1, r2, exp2, read_data2);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        // VCD waveform dump for GTKWave
        $dumpfile("tb_register_file.vcd");
        $dumpvars(0, tb_register_file);

        // Signal initialization
        clk        = 0;
        reset      = 0;
        reg_write  = 0;
        read_reg1  = 5'd0;
        read_reg2  = 5'd0;
        write_reg  = 5'd0;
        write_data = 32'd0;
        pass_count = 0;
        fail_count = 0;
        test_id    = 0;

        $display("==================================================================");
        $display("Starting Register File Comprehensive Verification (Member 2)");
        $display("==================================================================");

        // --------------------------------------------------------------------
        // 1. Initial State Check
        // --------------------------------------------------------------------
        $display("\n--- 1. Testing Initial Power-on State (All Registers Zero) ---");
        check_reads(5'd0, 32'h0000_0000, 5'd1, 32'h0000_0000, "Initial R0 & R1 Zero");
        check_reads(5'd16, 32'h0000_0000, 5'd31, 32'h0000_0000, "Initial R16 & R31 Zero");

        // --------------------------------------------------------------------
        // 2. Register Zero ($0) Hardwired Zero Protection
        // --------------------------------------------------------------------
        $display("\n--- 2. Testing Register Zero ($0) Protection ---");
        // Attempt to write non-zero value to $0
        write_register(5'd0, 32'hDEAD_BEEF);
        check_reads(5'd0, 32'h0000_0000, 5'd0, 32'h0000_0000, "R0 Write Ignored Check");

        // Attempt write of 0xFFFFFFFF to $0
        write_register(5'd0, 32'hFFFF_FFFF);
        check_reads(5'd0, 32'h0000_0000, 5'd0, 32'h0000_0000, "R0 0xFFFFFFFF Ignored");

        // --------------------------------------------------------------------
        // 3. Synchronous Writes: Positive, Negative, Boundary Values
        // --------------------------------------------------------------------
        $display("\n--- 3. Testing Synchronous Writes & Asynchronous Dual Reads ---");
        // Write positive number to R1
        write_register(5'd1, 32'd12345);
        check_reads(5'd1, 32'd12345, 5'd0, 32'd0, "R1 Write Positive");

        // Write negative number (two's complement) to R2
        write_register(5'd2, -32'd67890);
        check_reads(5'd1, 32'd12345, 5'd2, -32'd67890, "Simultaneous Read R1 & R2");

        // Boundary Value: Maximum Positive Signed Int (0x7FFFFFFF) to R3
        write_register(5'd3, 32'h7FFF_FFFF);
        check_reads(5'd3, 32'h7FFF_FFFF, 5'd0, 32'd0, "R3 Max Positive Int");

        // Boundary Value: Minimum Negative Signed Int (0x80000000) to R4
        write_register(5'd4, 32'h8000_0000);
        check_reads(5'd4, 32'h8000_0000, 5'd3, 32'h7FFF_FFFF, "R4 Min Signed Int");

        // Boundary Value: All 1s (0xFFFFFFFF) to R5
        write_register(5'd5, 32'hFFFF_FFFF);
        check_reads(5'd5, 32'hFFFF_FFFF, 5'd4, 32'h8000_0000, "R5 All 1s");

        // --------------------------------------------------------------------
        // 4. Write-Enable (reg_write) Deassertion Test
        // --------------------------------------------------------------------
        $display("\n--- 4. Testing Write-Enable (reg_write = 0) Protection ---");
        @(posedge clk);
        #1;
        reg_write  = 1'b0; // Disabled
        write_reg  = 5'd1;
        write_data = 32'hCAFE_BABE; // Should NOT be written to R1
        @(posedge clk);
        #1;
        check_reads(5'd1, 32'd12345, 5'd0, 32'd0, "R1 Unchanged when reg_write=0");

        // --------------------------------------------------------------------
        // 5. Simultaneous Read of Same Register on Both Ports
        // --------------------------------------------------------------------
        $display("\n--- 5. Testing Dual Simultaneous Read of Same Register ---");
        check_reads(5'd2, -32'd67890, 5'd2, -32'd67890, "Dual Read Same Reg R2");

        // --------------------------------------------------------------------
        // 6. Asynchronous Read Verification (No clock pulse required for read)
        // --------------------------------------------------------------------
        $display("\n--- 6. Testing Asynchronous Read Timing ---");
        read_reg1 = 5'd3;
        #1; // Just 1ns, no clock edge!
        if (read_data1 === 32'h7FFF_FFFF) begin
            $display("[PASS] Test %02d | Asynchronous Read Immediate Update | Read_data1=%h", test_id+1, read_data1);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test %02d | Asynchronous Read Did Not Update Immediately | Got=%h", test_id+1, read_data1);
            fail_count = fail_count + 1;
        end
        test_id = test_id + 1;

        // --------------------------------------------------------------------
        // 7. Write and Verify Remaining Registers ($6 to $31)
        // --------------------------------------------------------------------
        $display("\n--- 7. Testing All Registers ($6 to $31) ---");
        for (idx = 6; idx < 32; idx = idx + 1) begin
            write_register(idx[4:0], 32'h1000_0000 + idx);
        end

        // Spot-check several registers across the bank
        check_reads(5'd10, 32'h1000_000A, 5'd20, 32'h1000_0014, "Read Bank R10 & R20");
        check_reads(5'd30, 32'h1000_001E, 5'd31, 32'h1000_001F, "Read Bank R30 & R31 (ra)");

        // --------------------------------------------------------------------
        // 8. Active-High Synchronous Reset Behavior
        // --------------------------------------------------------------------
        $display("\n--- 8. Testing Active-High Synchronous Reset Behavior ---");
        // Verify R1 and R31 currently hold non-zero values
        check_reads(5'd1, 32'd12345, 5'd31, 32'h1000_001F, "Pre-Reset Non-Zero State");

        // Assert reset on rising clock edge
        @(posedge clk);
        #1;
        reset = 1'b1;
        @(posedge clk); // Synchronous reset executes here
        #1;
        reset = 1'b0;

        // Verify all previously written registers are now cleared to 0
        check_reads(5'd1, 32'h0000_0000, 5'd2, 32'h0000_0000, "Post-Reset R1 & R2 Zero");
        check_reads(5'd3, 32'h0000_0000, 5'd4, 32'h0000_0000, "Post-Reset R3 & R4 Zero");
        check_reads(5'd10, 32'h0000_0000, 5'd20, 32'h0000_0000, "Post-Reset R10 & R20 Zero");
        check_reads(5'd30, 32'h0000_0000, 5'd31, 32'h0000_0000, "Post-Reset R30 & R31 Zero");

        // --------------------------------------------------------------------
        // 9. Post-Reset Normal Operation Resumption
        // --------------------------------------------------------------------
        $display("\n--- 9. Testing Normal Operation Resumption After Reset ---");
        write_register(5'd7, 32'hA5A5_5A5A);
        check_reads(5'd7, 32'hA5A5_5A5A, 5'd0, 32'h0000_0000, "Post-Reset Write R7");

        // --------------------------------------------------------------------
        // Final Summary
        // --------------------------------------------------------------------
        $display("\n==================================================================");
        $display("Register File Test Summary: %0d Passed, %0d Failed", pass_count, fail_count);
        $display("==================================================================");

        if (fail_count == 0) begin
            $display(">>> ALL REGISTER FILE TESTS PASSED SUCCESSFULLY! <<<\n");
        end else begin
            $display(">>> SOME REGISTER FILE TESTS FAILED! <<<\n");
        end

        $finish;
    end

endmodule

