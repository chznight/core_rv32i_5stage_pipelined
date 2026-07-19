// Copyright (c) 2026 chznight
// SPDX-License-Identifier: MIT

module register_file(
    input wire clk,
    input wire rst,
    input wire reg_write,
    input wire [4:0] read_reg1,
    input wire [4:0] read_reg2,
    input wire [4:0] write_reg,
    input wire [31:0] write_data,
    output wire [31:0] read_data1,
    output wire [31:0] read_data2
);

    // Register file (32 registers, each 32 bits wide)
    reg [31:0] registers [0:31];
    
    integer i;
    
    // Initialize registers to 0
    always @(negedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1) begin
                registers[i] <= 32'b0;
            end
        end else if (reg_write && write_reg != 5'b0) begin
            // Write data to register if reg_write is asserted and not writing to x0
            registers[write_reg] <= write_data;
        end
    end
    
    // Read operations (asynchronous)
    // Register x0 is hardwired to 0
    assign read_data1 = (read_reg1 == 5'b0) ? 32'b0 : registers[read_reg1];
    assign read_data2 = (read_reg2 == 5'b0) ? 32'b0 : registers[read_reg2];

endmodule 