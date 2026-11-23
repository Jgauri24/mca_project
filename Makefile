# Single-cycle MIPS CPU - simulation targets (Icarus Verilog)
# Run from the repository root:  make all
# Waveforms (.vcd) are written to sim/.

IVERILOG = iverilog -g2001 -Wall
SIM      = sim
RTL      = rtl/pc.v rtl/branch_jump.v rtl/instruction_memory.v rtl/control_unit.v \
           rtl/alu_control.v rtl/register_file.v rtl/sign_extend.v rtl/alu.v \
           rtl/data_memory.v rtl/mips_cpu.v

.PHONY: all alu rf se imem dmem cpu perf clean

all: alu rf se imem dmem cpu perf

# $(call run,testbench-name,sources)
define run
	@mkdir -p $(SIM)
	$(IVERILOG) -s $(1) -o $(SIM)/$(1) $(2)
	vvp -n $(SIM)/$(1)
	@mv -f $(1).vcd $(SIM)/ 2>/dev/null || true
endef

alu:  ; $(call run,tb_alu,rtl/alu.v tb/tb_alu.v)
rf:   ; $(call run,tb_register_file,rtl/register_file.v tb/tb_register_file.v)
se:   ; $(call run,tb_sign_extend,rtl/sign_extend.v tb/tb_sign_extend.v)
imem: ; $(call run,tb_instruction_memory,rtl/instruction_memory.v tb/tb_instruction_memory.v)
dmem: ; $(call run,tb_data_memory,rtl/data_memory.v tb/tb_data_memory.v)
cpu:  ; $(call run,tb_mips_cpu,$(RTL) tb/tb_mips_cpu.v)
perf: ; $(call run,tb_performance,$(RTL) tb/tb_performance.v)

clean:
	rm -rf $(SIM) *.vcd
