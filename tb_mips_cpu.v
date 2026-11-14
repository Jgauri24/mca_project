// End-to-end self-checking tests for the supplied single-cycle CPU.
// Sample programs are encoded as Verilog constants below, so no assembler or
// external program files are required. RTL is not modified.
`timescale 1ns / 1ps
module tb_mips_cpu;
    reg clk, reset;
    wire [31:0] debug_pc, debug_instruction;
    integer pass_count, fail_count, cycles, i;
    mips_cpu uut(.clk(clk),.reset(reset),.debug_pc(debug_pc),.debug_instruction(debug_instruction));
    always #5 clk=~clk;
    always @(negedge clk) if (!reset) begin
        cycles=cycles+1;
        $display("[TRACE] cycle=%0d PC=%08h instruction=%08h t0=%0d t1=%0d t2=%0d t3=%0d t4=%0d",
          cycles,debug_pc,debug_instruction,uut.u_register_file.registers[8],uut.u_register_file.registers[9],
          uut.u_register_file.registers[10],uut.u_register_file.registers[11],uut.u_register_file.registers[12]);
    end
    task check;
        input [31:0] got, expected;
        input [255:0] label;
        begin
            if(got === expected) begin $display("[PASS] %0s = %0d (0x%08h)",label,got,got); pass_count=pass_count+1; end
            else begin $display("[FAIL] %0s expected %0d (0x%08h), got %0d (0x%08h)",label,expected,expected,got,got); fail_count=fail_count+1; end
        end
    endtask
    task clear_state;
        begin
            reset=1; repeat(2) @(negedge clk); reset=0;
            for(i=0;i<32;i=i+1) uut.u_register_file.registers[i]=0;
            for(i=0;i<256;i=i+1) begin
                uut.u_dmem.memory[i]=0;
                uut.u_imem.memory[i]=0;
            end
            cycles=0;
        end
    endtask
    // program_id: 1=array sum, 2=maximum search, 3=factorial.
    // Words use the exact opcodes/funct fields in the project's RTL.
    task load_program;
        input integer program_id;
        begin
            case(program_id)
                1: begin // [10,20,30,40,50] -> $t2=150, store at byte address 0
                    uut.u_imem.memory[0]=32'h2008000a; // addi $t0,$zero,10
                    uut.u_imem.memory[1]=32'h20090014; // addi $t1,$zero,20
                    uut.u_imem.memory[2]=32'h01095020; // add $t2,$t0,$t1
                    uut.u_imem.memory[3]=32'h2008001e;
                    uut.u_imem.memory[4]=32'h01485020;
                    uut.u_imem.memory[5]=32'h20080028;
                    uut.u_imem.memory[6]=32'h01485020;
                    uut.u_imem.memory[7]=32'h20080032;
                    uut.u_imem.memory[8]=32'h01485020;
                    uut.u_imem.memory[9]=32'hac0a0000; // sw $t2,0($zero)
                    uut.u_imem.memory[10]=32'h0800000b; // j done
                    uut.u_imem.memory[11]=32'h0800000b; // done: j done
                end
                2: begin // [12,45,7,89,23] -> $t2=89, store at byte address 0
                    uut.u_imem.memory[0]=32'h2008000c;
                    uut.u_imem.memory[1]=32'h210a0000;
                    uut.u_imem.memory[2]=32'h2009002d;
                    uut.u_imem.memory[3]=32'h0149582a;
                    uut.u_imem.memory[4]=32'h11600001;
                    uut.u_imem.memory[5]=32'h212a0000;
                    uut.u_imem.memory[6]=32'h20090007;
                    uut.u_imem.memory[7]=32'h0149582a;
                    uut.u_imem.memory[8]=32'h11600001;
                    uut.u_imem.memory[9]=32'h212a0000;
                    uut.u_imem.memory[10]=32'h20090059;
                    uut.u_imem.memory[11]=32'h0149582a;
                    uut.u_imem.memory[12]=32'h11600001;
                    uut.u_imem.memory[13]=32'h212a0000;
                    uut.u_imem.memory[14]=32'h20090017;
                    uut.u_imem.memory[15]=32'h0149582a;
                    uut.u_imem.memory[16]=32'h11600001;
                    uut.u_imem.memory[17]=32'h212a0000;
                    uut.u_imem.memory[18]=32'hac0a0000;
                    uut.u_imem.memory[19]=32'h08000012;
                end
                3: begin // 5! -> $t2=120, store at byte address 0
                    uut.u_imem.memory[0]=32'h20080005;
                    uut.u_imem.memory[1]=32'h20090000;
                    uut.u_imem.memory[2]=32'h200a0001;
                    uut.u_imem.memory[3]=32'h1100000a;
                    uut.u_imem.memory[4]=32'h00005820;
                    uut.u_imem.memory[5]=32'h016a5820;
                    uut.u_imem.memory[6]=32'h21290001;
                    uut.u_imem.memory[7]=32'h0128602a;
                    uut.u_imem.memory[8]=32'h11800001;
                    uut.u_imem.memory[9]=32'h08000005;
                    uut.u_imem.memory[10]=32'h216a0000;
                    uut.u_imem.memory[11]=32'h2108ffff;
                    uut.u_imem.memory[12]=32'h20090000;
                    uut.u_imem.memory[13]=32'h08000003;
                    uut.u_imem.memory[14]=32'hac0a0000;
                    uut.u_imem.memory[15]=32'h0800000e;
                end
                default: begin
                    $display("[FAIL] Invalid program_id=%0d",program_id);
                    fail_count=fail_count+1;
                end
            endcase
        end
    endtask
    task run_program;
        input integer program_id;
        input integer ncycles;
        begin
            clear_state();
            load_program(program_id);
            repeat(ncycles) @(negedge clk);
        end
    endtask
    initial begin
        $dumpfile("tb_mips_cpu.vcd"); $dumpvars(0,tb_mips_cpu);
        clk=0; reset=1; pass_count=0; fail_count=0; cycles=0;
        run_program(1,14);
        check(uut.u_register_file.registers[10],150,"array sum result $t2");
        check(uut.u_dmem.memory[0],150,"array sum stored result");
        run_program(2,23);
        check(uut.u_register_file.registers[10],89,"maximum search result $t2");
        check(uut.u_dmem.memory[0],89,"maximum stored result");
        run_program(3,125);
        check(uut.u_register_file.registers[10],120,"factorial result $t2");
        check(uut.u_dmem.memory[0],120,"factorial stored result");
        $display("============================================================");
        if(fail_count==0) $display("STATUS: ALL CPU PROGRAMS PASSED (%0d checks)",pass_count);
        else $display("STATUS: FAIL (%0d passed, %0d failed)",pass_count,fail_count);
        $finish;
    end
endmodule
