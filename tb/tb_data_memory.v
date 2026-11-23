// ============================================================================
// File: tb_data_memory.v
// Module: tb_data_memory
// Description: Self-Checking Testbench for the Data Memory (RAM)
// Standard: Verilog-2001
// Lead: Member 3 (Memory Subsystem)
// Coverage:
//   - Write a value and read it back (100 @ 0, 200 @ 4)
//   - Writes to different locations, reads of consecutive locations
//   - Last valid word (address 0x3FC)
//   - Overwrite of an existing location
//   - Read disabled (mem_read = 0 -> read_data = 0)
//   - Write disabled (mem_write = 0 -> memory unchanged)
//   - Out-of-range address: write ignored, read returns 0, no aliasing
//   - Unaligned address: write ignored, read returns 0
//   - Simultaneous read & write (read-before-write)
//   - Synchronous reset clears memory and has priority over a write
// Note: This testbench uses simulation-only constructs ($display, $dumpfile,
//       delays, tasks). It is not intended for synthesis.
// ============================================================================

`timescale 1ns / 1ps

module tb_data_memory;

    // Stimulus
    reg         clk;
    reg         reset;
    reg  [31:0] address;
    reg  [31:0] write_data;
    reg         mem_read;
    reg         mem_write;

    // Observed output
    wire [31:0] read_data;

    // Test tracking
    integer pass_count;
    integer fail_count;
    integer test_id;
    integer k;

    // Unit Under Test
    data_memory uut (
        .clk        (clk),
        .reset      (reset),
        .address    (address),
        .write_data (write_data),
        .mem_read   (mem_read),
        .mem_write  (mem_write),
        .read_data  (read_data)
    );

    // 10 ns clock period (100 MHz)
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // ------------------------------------------------------------------------
    // Task: perform one clocked write (signals change away from the edge)
    // ------------------------------------------------------------------------
    task mem_write_word;
        input [31:0] addr;
        input [31:0] data;
        begin
            @(negedge clk);
            address    = addr;
            write_data = data;
            mem_write  = 1'b1;
            mem_read   = 1'b0;
            @(negedge clk);          // rising edge in between performs write
            mem_write  = 1'b0;
        end
    endtask

    // ------------------------------------------------------------------------
    // Task: combinational read with a given mem_read value and compare
    // ------------------------------------------------------------------------
    task check_read;
        input [31:0]  addr;
        input         rd_en;
        input [31:0]  exp_data;
        input [255:0] test_name;
        begin
            address  = addr;
            mem_read = rd_en;
            #1;                       // combinational settle
            test_id = test_id + 1;
            if (read_data === exp_data) begin
                $display("[PASS] Test %02d | %0s | Addr=0x%h MemRead=%b => Data=0x%h (%0d)",
                         test_id, test_name, addr, rd_en, read_data, read_data);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] Test %02d | %0s | Addr=0x%h MemRead=%b => Expected=0x%h | Got=0x%h",
                         test_id, test_name, addr, rd_en, exp_data, read_data);
                fail_count = fail_count + 1;
            end
            mem_read = 1'b0;
        end
    endtask

    initial begin
        // VCD waveform generation for GTKWave
        $dumpfile("tb_data_memory.vcd");
        $dumpvars(0, tb_data_memory);

        pass_count = 0;
        fail_count = 0;
        test_id    = 0;

        address    = 32'd0;
        write_data = 32'd0;
        mem_read   = 1'b0;
        mem_write  = 1'b0;

        $display("==================================================================");
        $display("Starting Data Memory Verification (Member 3)");
        $display("==================================================================");

        // --------------------------------------------------------------------
        // 0. Initial synchronous reset (clears all 256 words)
        // --------------------------------------------------------------------
        reset = 1'b1;
        @(posedge clk); @(posedge clk);
        @(negedge clk);
        reset = 1'b0;

        $display("\n--- After Initial Reset ---");
        check_read(32'd0,  1'b1, 32'd0, "Word 0 cleared by reset");
        check_read(32'h3FC, 1'b1, 32'd0, "Word 255 cleared by reset");

        // --------------------------------------------------------------------
        // 1. Basic write then read
        // --------------------------------------------------------------------
        $display("\n--- Basic Write / Read ---");
        mem_write_word(32'd0, 32'd100);
        check_read(32'd0, 1'b1, 32'd100, "Write 100 @0, read @0");

        mem_write_word(32'd4, 32'd200);
        check_read(32'd4, 1'b1, 32'd200, "Write 200 @4, read @4");

        // --------------------------------------------------------------------
        // 2. Different locations and consecutive reads
        // --------------------------------------------------------------------
        $display("\n--- Different Locations / Consecutive Reads ---");
        mem_write_word(32'd8,     32'hDEAD_BEEF);
        mem_write_word(32'd12,    32'hCAFE_F00D);
        mem_write_word(32'h3FC,   32'h1234_5678); // last word, mem[255]
        check_read(32'd0,   1'b1, 32'd100,        "Consecutive read @0");
        check_read(32'd4,   1'b1, 32'd200,        "Consecutive read @4");
        check_read(32'd8,   1'b1, 32'hDEAD_BEEF,  "Consecutive read @8");
        check_read(32'd12,  1'b1, 32'hCAFE_F00D,  "Consecutive read @12");
        check_read(32'h3FC, 1'b1, 32'h1234_5678,  "Read last word @0x3FC");

        // Overwrite an existing location
        mem_write_word(32'd4, 32'd250);
        check_read(32'd4, 1'b1, 32'd250, "Overwrite @4 with 250");

        // --------------------------------------------------------------------
        // 3. Read disabled
        // --------------------------------------------------------------------
        $display("\n--- Read Disabled (mem_read = 0) ---");
        check_read(32'd0, 1'b0, 32'd0, "mem_read=0 @0 -> 0");
        check_read(32'd8, 1'b0, 32'd0, "mem_read=0 @8 -> 0");

        // --------------------------------------------------------------------
        // 4. Write disabled: data and address driven, mem_write = 0
        // --------------------------------------------------------------------
        $display("\n--- Write Disabled (mem_write = 0) ---");
        @(negedge clk);
        address    = 32'd0;
        write_data = 32'hFFFF_FFFF;
        mem_write  = 1'b0;
        @(negedge clk);
        check_read(32'd0, 1'b1, 32'd100, "mem_write=0 keeps old value");

        // --------------------------------------------------------------------
        // 5. Out-of-range addresses
        // --------------------------------------------------------------------
        $display("\n--- Out-of-Range Addresses ---");
        // 0x400 aliases word 0 if upper address bits were ignored
        mem_write_word(32'h0000_0400, 32'hBAD0_0001);
        check_read(32'd0,          1'b1, 32'd100, "Write @0x400 does not alias @0");
        check_read(32'h0000_0400,  1'b1, 32'd0,   "Read @0x400 returns 0");
        mem_write_word(32'hFFFF_FFFC, 32'hBAD0_0002);
        check_read(32'h3FC,        1'b1, 32'h1234_5678, "Write @0xFFFFFFFC ignored");
        check_read(32'hFFFF_FFFC,  1'b1, 32'd0,   "Read @0xFFFFFFFC returns 0");

        // --------------------------------------------------------------------
        // 6. Unaligned addresses
        // --------------------------------------------------------------------
        $display("\n--- Unaligned Addresses ---");
        mem_write_word(32'd9, 32'hBAD0_0003);   // would hit word 2
        check_read(32'd8, 1'b1, 32'hDEAD_BEEF, "Unaligned write @9 ignored");
        mem_write_word(32'd6, 32'hBAD0_0004);   // would hit word 1
        check_read(32'd4, 1'b1, 32'd250,       "Unaligned write @6 ignored");
        check_read(32'd1, 1'b1, 32'd0,         "Unaligned read @1 returns 0");
        check_read(32'd14, 1'b1, 32'd0,        "Unaligned read @14 returns 0");

        // --------------------------------------------------------------------
        // 7. Simultaneous read & write (read-before-write)
        // --------------------------------------------------------------------
        $display("\n--- Simultaneous Read & Write ---");
        @(negedge clk);
        address    = 32'd12;
        write_data = 32'd777;
        mem_read   = 1'b1;
        mem_write  = 1'b1;
        #1;
        test_id = test_id + 1;
        if (read_data === 32'hCAFE_F00D) begin
            $display("[PASS] Test %02d | R&W before edge shows OLD data | Data=0x%h",
                     test_id, read_data);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test %02d | R&W before edge | Expected=0x%h | Got=0x%h",
                     test_id, 32'hCAFE_F00D, read_data);
            fail_count = fail_count + 1;
        end
        @(posedge clk); #1;
        test_id = test_id + 1;
        if (read_data === 32'd777) begin
            $display("[PASS] Test %02d | R&W after edge shows NEW data  | Data=0x%h (%0d)",
                     test_id, read_data, read_data);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] Test %02d | R&W after edge | Expected=%0d | Got=0x%h",
                     test_id, 777, read_data);
            fail_count = fail_count + 1;
        end
        @(negedge clk);
        mem_read  = 1'b0;
        mem_write = 1'b0;

        // --------------------------------------------------------------------
        // 8. Reset clears memory and has priority over a write
        // --------------------------------------------------------------------
        $display("\n--- Synchronous Reset ---");
        @(negedge clk);
        reset      = 1'b1;
        address    = 32'd16;
        write_data = 32'd555;
        mem_write  = 1'b1;           // must be ignored while reset = 1
        @(negedge clk);
        reset      = 1'b0;
        mem_write  = 1'b0;
        for (k = 0; k < 5; k = k + 1) begin
            check_read(k * 4, 1'b1, 32'd0, "Word cleared by reset");
        end
        check_read(32'h3FC, 1'b1, 32'd0, "Last word cleared by reset");

        // Memory is usable again after reset
        mem_write_word(32'd20, 32'd42);
        check_read(32'd20, 1'b1, 32'd42, "Write/read after reset");

        // --------------------------------------------------------------------
        // Summary
        // --------------------------------------------------------------------
        $display("\n==================================================================");
        $display("Data Memory Verification Complete");
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
