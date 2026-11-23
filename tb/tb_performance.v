// ============================================================================
// File: tb_performance.v
// Description: Performance measurement testbench for the single-cycle MIPS CPU.
//   Runs each sample program until it reaches its halt loop (a J instruction
//   that jumps to itself), counts the dynamic instruction mix and reports:
//     - instruction count and clock cycles (single-cycle CPI = 1)
//     - cycles a classic multi-cycle MIPS would need for the same mix
//       (R-type 4, ADDI 4, LW 5, SW 4, BEQ 3, J 3 cycles)
//     - execution time of both designs using the textbook component delays
//       (instruction memory 200 ps, register read 100 ps, ALU 200 ps,
//        data memory 200 ps, register write 100 ps):
//          single-cycle clock = 800 ps (longest path is LW)
//          multi-cycle  clock = 200 ps (slowest single step)
//   The result of every program is also checked, so the numbers are only
//   reported for programs that ran correctly.
// Standard: Verilog-2001
// ============================================================================

`timescale 1ns / 1ps

module tb_performance;
    reg clk, reset;
    wire [31:0] debug_pc, debug_instruction;
    integer i, fail_count;

    // Dynamic instruction counters
    integer n_r, n_addi, n_lw, n_sw, n_beq, n_beq_taken, n_j, n_total;
    integer sc_cycles, mc_cycles;
    integer sum_insts, sum_sc_cycles, sum_mc_cycles;

    localparam SC_CLOCK_PS = 800;   // single-cycle clock period (textbook model)
    localparam MC_CLOCK_PS = 200;   // multi-cycle clock period (textbook model)
    localparam MAX_CYCLES  = 1000;  // safety limit

    mips_cpu uut(.clk(clk), .reset(reset), .debug_pc(debug_pc), .debug_instruction(debug_instruction));

    always #5 clk = ~clk;

    wire [5:0]  opcode  = debug_instruction[31:26];
    wire [31:0] j_target = {debug_pc[31:28], debug_instruction[25:0], 2'b00};
    wire        at_halt = (opcode == 6'b000010) && (j_target == debug_pc);

    task load_program;
        input integer program_id;
        begin
            for (i = 0; i < 256; i = i + 1) uut.u_imem.memory[i] = 0;
            case (program_id)
                1: begin // array sum
                    uut.u_imem.memory[0]=32'h2008000a; uut.u_imem.memory[1]=32'h20090014;
                    uut.u_imem.memory[2]=32'h01095020; uut.u_imem.memory[3]=32'h2008001e;
                    uut.u_imem.memory[4]=32'h01485020; uut.u_imem.memory[5]=32'h20080028;
                    uut.u_imem.memory[6]=32'h01485020; uut.u_imem.memory[7]=32'h20080032;
                    uut.u_imem.memory[8]=32'h01485020; uut.u_imem.memory[9]=32'hac0a0000;
                    uut.u_imem.memory[10]=32'h0800000b; uut.u_imem.memory[11]=32'h0800000b;
                end
                2: begin // maximum search
                    uut.u_imem.memory[0]=32'h2008000c;  uut.u_imem.memory[1]=32'h210a0000;
                    uut.u_imem.memory[2]=32'h2009002d;  uut.u_imem.memory[3]=32'h0149582a;
                    uut.u_imem.memory[4]=32'h11600001;  uut.u_imem.memory[5]=32'h212a0000;
                    uut.u_imem.memory[6]=32'h20090007;  uut.u_imem.memory[7]=32'h0149582a;
                    uut.u_imem.memory[8]=32'h11600001;  uut.u_imem.memory[9]=32'h212a0000;
                    uut.u_imem.memory[10]=32'h20090059; uut.u_imem.memory[11]=32'h0149582a;
                    uut.u_imem.memory[12]=32'h11600001; uut.u_imem.memory[13]=32'h212a0000;
                    uut.u_imem.memory[14]=32'h20090017; uut.u_imem.memory[15]=32'h0149582a;
                    uut.u_imem.memory[16]=32'h11600001; uut.u_imem.memory[17]=32'h212a0000;
                    uut.u_imem.memory[18]=32'hac0a0000; uut.u_imem.memory[19]=32'h08000013;
                end
                3: begin // factorial 5!
                    uut.u_imem.memory[0]=32'h20080005;  uut.u_imem.memory[1]=32'h20090000;
                    uut.u_imem.memory[2]=32'h200a0001;  uut.u_imem.memory[3]=32'h1100000a;
                    uut.u_imem.memory[4]=32'h00005820;  uut.u_imem.memory[5]=32'h016a5820;
                    uut.u_imem.memory[6]=32'h21290001;  uut.u_imem.memory[7]=32'h0128602a;
                    uut.u_imem.memory[8]=32'h11800001;  uut.u_imem.memory[9]=32'h08000005;
                    uut.u_imem.memory[10]=32'h216a0000; uut.u_imem.memory[11]=32'h2108ffff;
                    uut.u_imem.memory[12]=32'h20090000; uut.u_imem.memory[13]=32'h08000003;
                    uut.u_imem.memory[14]=32'hac0a0000; uut.u_imem.memory[15]=32'h0800000f;
                end
                4: begin // jump + logic test
                    uut.u_imem.memory[0]=32'h2008000c; uut.u_imem.memory[1]=32'h2009000a;
                    uut.u_imem.memory[2]=32'h08000004; uut.u_imem.memory[3]=32'h200a0063;
                    uut.u_imem.memory[4]=32'h01095022; uut.u_imem.memory[5]=32'h01095824;
                    uut.u_imem.memory[6]=32'h01096025; uut.u_imem.memory[7]=32'h0128682a;
                    uut.u_imem.memory[8]=32'hac0c0004; uut.u_imem.memory[9]=32'h8c0e0004;
                    uut.u_imem.memory[10]=32'h0800000a;
                end
            endcase
        end
    endtask

    // Runs one program to its halt loop, counting every executed instruction
    // (the final halt jump is not counted).
    task run_and_measure;
        input integer program_id;
        input [127:0] name;
        input [31:0] expected;
        begin
            n_r=0; n_addi=0; n_lw=0; n_sw=0; n_beq=0; n_beq_taken=0; n_j=0; n_total=0;
            reset = 1;
            load_program(program_id);
            repeat (2) @(negedge clk);
            reset = 0;
            while (!at_halt && n_total < MAX_CYCLES) begin
                case (opcode)
                    6'b000000: n_r = n_r + 1;
                    6'b001000: n_addi = n_addi + 1;
                    6'b100011: n_lw = n_lw + 1;
                    6'b101011: n_sw = n_sw + 1;
                    6'b000100: begin
                        n_beq = n_beq + 1;
                        if (uut.alu_zero) n_beq_taken = n_beq_taken + 1;
                    end
                    6'b000010: n_j = n_j + 1;
                endcase
                n_total = n_total + 1;
                @(negedge clk);
            end
            sc_cycles = n_total;  // one instruction per clock
            mc_cycles = 4*n_r + 4*n_addi + 5*n_lw + 4*n_sw + 3*n_beq + 3*n_j;
            sum_insts = sum_insts + n_total;
            sum_sc_cycles = sum_sc_cycles + sc_cycles;
            sum_mc_cycles = sum_mc_cycles + mc_cycles;

            if (uut.u_register_file.registers[10] !== expected || n_total >= MAX_CYCLES) begin
                $display("[FAIL] %0s: $t2=%0d, expected %0d", name, uut.u_register_file.registers[10], expected);
                fail_count = fail_count + 1;
            end else begin
                $display("[PASS] %0s: $t2=%0d", name, uut.u_register_file.registers[10]);
            end
            $display("       mix: R=%0d ADDI=%0d LW=%0d SW=%0d BEQ=%0d (taken %0d) J=%0d",
                     n_r, n_addi, n_lw, n_sw, n_beq, n_beq_taken, n_j);
            $display("       instructions=%0d  single-cycle: %0d cycles, CPI=1.00, time=%0d ps",
                     n_total, sc_cycles, sc_cycles*SC_CLOCK_PS);
            $display("       multi-cycle: %0d cycles, CPI=%0d.%02d, time=%0d ps",
                     mc_cycles, mc_cycles/n_total, (mc_cycles*100/n_total)%100, mc_cycles*MC_CLOCK_PS);
        end
    endtask

    initial begin
        $dumpfile("tb_performance.vcd");
        $dumpvars(0, tb_performance);
        clk = 0; reset = 1; fail_count = 0;
        sum_insts = 0; sum_sc_cycles = 0; sum_mc_cycles = 0;
        $display("=================== PERFORMANCE MEASUREMENT ===================");
        run_and_measure(1, "array sum", 150);
        run_and_measure(2, "maximum search", 89);
        run_and_measure(3, "factorial 5!", 120);
        run_and_measure(4, "jump/logic test", 2);
        $display("===============================================================");
        $display("TOTAL instructions=%0d", sum_insts);
        $display("TOTAL single-cycle: %0d cycles, CPI=1.00, time=%0d ps",
                 sum_sc_cycles, sum_sc_cycles*SC_CLOCK_PS);
        $display("TOTAL multi-cycle : %0d cycles, CPI=%0d.%02d, time=%0d ps",
                 sum_mc_cycles, sum_mc_cycles/sum_insts, (sum_mc_cycles*100/sum_insts)%100,
                 sum_mc_cycles*MC_CLOCK_PS);
        if (fail_count == 0) $display("STATUS: ALL PERFORMANCE RUNS PASSED");
        else $display("STATUS: FAIL (%0d programs wrong)", fail_count);
        $finish;
    end
endmodule
