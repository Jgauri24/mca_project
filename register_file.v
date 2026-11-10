// ============================================================================
// File: register_file.v
// Module: register_file
// Description: 32x32-bit Dual-Read, Single-Write Register File
// Standard: Verilog-2001
// Lead: Member 2 (Execution Unit)
// Features:
//   - 32 general-purpose registers, each 32 bits wide ($0 - $31)
//   - Two asynchronous/combinational read ports (read_reg1, read_reg2)
//   - One synchronous write port triggered on posedge clk with reg_write enable
//   - Active-high synchronous reset (clears registers $0-$31 to 0)
//   - Hardwired Register $0 protection:
//       * Reads from $0 always return 32'h0000_0000
//       * Writes to $0 are strictly ignored
//   - Power-up initialization for simulation and FPGA synthesis
// ============================================================================

`timescale 1ns / 1ps

module register_file (
    input  wire        clk,        // Clock signal (synchronous writes)
    input  wire        reset,      // Active-high synchronous reset
    input  wire        reg_write,  // Write enable control signal
    input  wire [4:0]  read_reg1,  // 5-bit source register 1 address (rs)
    input  wire [4:0]  read_reg2,  // 5-bit source register 2 address (rt)
    input  wire [4:0]  write_reg,  // 5-bit destination register address (rd or rt)
    input  wire [31:0] write_data, // 32-bit data to write
    output wire [31:0] read_data1, // 32-bit data output from read port 1
    output wire [31:0] read_data2  // 32-bit data output from read port 2
);

    // 32 registers of 32-bit width
    reg [31:0] registers [31:0];

    integer i;

    // Power-up initialization: Ensure known zero state in simulation and FPGA
    initial begin
        for (i = 0; i < 32; i = i + 1) begin
            registers[i] = 32'h0000_0000;
        end
    end

    // Synchronous Write Operation & Active-High Synchronous Reset
    always @(posedge clk) begin
        if (reset) begin
            // Clear all 32 registers to 0 on synchronous reset
            for (i = 0; i < 32; i = i + 1) begin
                registers[i] <= 32'h0000_0000;
            end
        end else if (reg_write && (write_reg != 5'd0)) begin
            // Synchronous write only if write enable is asserted and destination is not $0
            registers[write_reg] <= write_data;
        end
    end

    // Asynchronous (Combinational) Read Ports
    // Register $0 is hardwired to 0; any read from $0 returns 32'h0000_0000
    assign read_data1 = (read_reg1 == 5'd0) ? 32'h0000_0000 : registers[read_reg1];
    assign read_data2 = (read_reg2 == 5'd0) ? 32'h0000_0000 : registers[read_reg2];

endmodule

