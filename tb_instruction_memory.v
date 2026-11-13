// ============================================================================
// File: tb_instruction_memory.v
// Module: tb_instruction_memory
// Description: Self-Checking Testbench for the Instruction Memory (ROM)
// Standard: Verilog-2001
// Lead: Member 3 (Memory Subsystem)
// Coverage:
//   - Reads at address 0, 4 and 8
//   - Consecutive sequential fetch of the whole sample program (PC += 4)
//   - Correct $readmemh initialisation from instruction_memory.mem
//   - Unused (but valid) locations read as NOP (0x00000000)
//   - Last valid word (address 0x3FC)
//   - Out-of-range addresses (>= 1024) return NOP
//   - Unaligned addresses (address[1:0] != 0) return NOP
// Note: This testbench uses simulation-only constructs ($display, $dumpfile,
//       delays, tasks). It is not intended for synthesis.
// ============================================================================

`timescale 1ns / 1ps

module tb_instruction_memory;

    // Stimulus and observed output
    reg  [31:0] address;
    wire [31:0] instruction;

    // Test tracking
    integer pass_count;
    integer fail_count;
    integer test_id;
    integer k;

    // Expected contents of instruction_memory.mem (golden reference)
    reg [31:0] expected_prog [0:7];

    // Unit Under Test
    instruction_memory #(
        .INIT_FILE ("instruction_memory.mem")
    ) uut (
        .address     (address),
        .instruction (instruction)
    );

    // Apply an address, wait for combinational settle, compare with expected
    task check_fetch;
        input [31:0]  addr;
        input [31:0]  exp_instr;
        input [255:0] test_name;
        begin
            address = addr;
            #5;
            test_id = test_id + 1;
            if (instruction === exp_instr) begin
                $display("[PASS] Test %02d | %0s | Addr=0x%h => Instr=0x%h",
                         test_id, test_name, addr, instruction);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %02d | %0s | Addr=0x%h => Expected=0x%h | Got=0x%h",
                         test_id, test_name, addr, exp_instr, instruction);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        // VCD waveform generation for GTKWave
        $dumpfile("tb_instruction_memory.vcd");
        $dumpvars(0, tb_instruction_memory);

        pass_count = 0;
        fail_count = 0;
        test_id    = 0;
        address    = 32'd0;

        expected_prog[0] = 32'h2008_0005; // addi $t0, $zero, 5
        expected_prog[1] = 32'h2009_000A; // addi $t1, $zero, 10
        expected_prog[2] = 32'h0109_5020; // add  $t2, $t0, $t1
        expected_prog[3] = 32'hAC0A_0000; // sw   $t2, 0($zero)
        expected_prog[4] = 32'h8C0B_0000; // lw   $t3, 0($zero)
        expected_prog[5] = 32'h114B_0001; // beq  $t2, $t3, +1
        expected_prog[6] = 32'h0128_6022; // sub  $t4, $t1, $t0
        expected_prog[7] = 32'h0800_0007; // j    0x1C

        $display("==================================================================");
        $display("Starting Instruction Memory Verification (Member 3)");
        $display("==================================================================");

        // --------------------------------------------------------------------
        // 1. Basic word-addressed reads
        // --------------------------------------------------------------------
        $display("\n--- Basic Reads (address -> memory[address[9:2]]) ---");
        check_fetch(32'd0, expected_prog[0], "Read addr 0 -> mem[0]");
        check_fetch(32'd4, expected_prog[1], "Read addr 4 -> mem[1]");
        check_fetch(32'd8, expected_prog[2], "Read addr 8 -> mem[2]");

        // --------------------------------------------------------------------
        // 2. Consecutive fetch, emulating PC = PC + 4
        // --------------------------------------------------------------------
        $display("\n--- Consecutive Fetch (PC += 4) / $readmemh Initialisation ---");
        for (k = 0; k < 8; k = k + 1) begin
            check_fetch(k * 4, expected_prog[k], "Sequential fetch");
        end

        // --------------------------------------------------------------------
        // 3. Valid but unprogrammed locations default to NOP
        // --------------------------------------------------------------------
        $display("\n--- Unprogrammed Locations ---");
        check_fetch(32'h0000_0020, 32'h0000_0000, "First unused word = NOP");
        check_fetch(32'h0000_03FC, 32'h0000_0000, "Last word (mem[255]) = NOP");

        // --------------------------------------------------------------------
        // 4. Out-of-range addresses
        // --------------------------------------------------------------------
        $display("\n--- Out-of-Range Addresses ---");
        // 0x400 would alias to mem[0] if upper bits were ignored
        check_fetch(32'h0000_0400, 32'h0000_0000, "Addr 0x400 (aliases mem[0])");
        check_fetch(32'h0000_0404, 32'h0000_0000, "Addr 0x404 (aliases mem[1])");
        check_fetch(32'hFFFF_FFFC, 32'h0000_0000, "Addr 0xFFFFFFFC");
        check_fetch(32'h8000_0000, 32'h0000_0000, "Addr 0x80000000");

        // --------------------------------------------------------------------
        // 5. Unaligned addresses
        // --------------------------------------------------------------------
        $display("\n--- Unaligned Addresses ---");
        check_fetch(32'h0000_0001, 32'h0000_0000, "Unaligned addr 1");
        check_fetch(32'h0000_0002, 32'h0000_0000, "Unaligned addr 2");
        check_fetch(32'h0000_0007, 32'h0000_0000, "Unaligned addr 7");

        // Recovery: a valid read still works after invalid ones
        check_fetch(32'd12, expected_prog[3], "Valid read after invalid");

        // --------------------------------------------------------------------
        // Summary
        // --------------------------------------------------------------------
        $display("\n==================================================================");
        $display("Instruction Memory Verification Complete");
        $display("Total Tests: %0d | PASSED: %0d | FAILED: %0d",
                 test_id, pass_count, fail_count);
        if (fail_count == 0)
            $display("STATUS: ALL TESTS PASSED");
        else
            $display("STATUS: SOME TESTS FAILED");
        $display("==================================================================");
        $finish;
    end

endmodule
