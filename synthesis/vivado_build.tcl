# Vivado non-project build for the single-cycle MIPS CPU on Basys3.
# Run from the repository root:
#   vivado -mode batch -source synthesis/vivado_build.tcl
# Reports are written to synthesis/vivado_reports/.

set part    xc7a35tcpg236-1
set outdir  synthesis/vivado_reports
file mkdir $outdir

read_verilog {
    rtl/alu.v rtl/alu_control.v rtl/branch_jump.v rtl/control_unit.v
    rtl/data_memory.v rtl/instruction_memory.v rtl/mips_cpu.v rtl/pc.v
    rtl/register_file.v rtl/sign_extend.v
    synthesis/fpga_top.v
}
read_xdc synthesis/basys3.xdc

synth_design -top fpga_top -part $part
report_utilization -file $outdir/post_synth_utilization.rpt

opt_design
place_design
route_design

report_utilization    -file $outdir/post_route_utilization.rpt
report_timing_summary -file $outdir/post_route_timing.rpt
write_bitstream -force $outdir/mips_cpu_basys3.bit
