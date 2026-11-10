// ============================================================================
// File: pc.v
// Module: pc
// Description: Program Counter (PC) register for 32-bit single-cycle MIPS CPU.
// Standard: Verilog-2001
// Reset: Active-high synchronous reset
// ============================================================================

module pc (
    input  wire        clk,
    input  wire        reset,
    input  wire [31:0] next_pc,
    output reg  [31:0] current_pc
);

    // Active-high synchronous reset on the rising clock edge
    always @(posedge clk) begin
        if (reset) begin
            current_pc <= 32'h0000_0000;
        end else begin
            current_pc <= next_pc;
        end
    end

endmodule

