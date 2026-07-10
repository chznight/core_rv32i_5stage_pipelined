// Copyright (c) 2025 chznight
// SPDX-License-Identifier: MIT

module immediate_gen(
    input wire [31:0] instruction,
    output reg [31:0] imm_ext
);

    // Opcode field
    wire [6:0] opcode;
    assign opcode = instruction[6:0];
    
    // Opcode definitions (same as in control_unit.v)
    parameter OP_I_TYPE     = 7'b0010011; // Register-Immediate operations
    parameter OP_LOAD       = 7'b0000011; // Load
    parameter OP_STORE      = 7'b0100011; // Store
    parameter OP_BRANCH     = 7'b1100011; // Branch
    parameter OP_JAL        = 7'b1101111; // Jump and Link
    parameter OP_JALR       = 7'b1100111; // Jump and Link Register
    parameter OP_LUI        = 7'b0110111; // Load Upper Immediate
    parameter OP_AUIPC      = 7'b0010111; // Add Upper Immediate to PC
    
    always @(*) begin
        case(opcode)
            // I-type instructions (including JALR and loads)
            OP_I_TYPE, OP_LOAD, OP_JALR: begin
                // Sign-extend the 12-bit immediate
                imm_ext = {{20{instruction[31]}}, instruction[31:20]};
            end
            
            // S-type instructions (stores)
            OP_STORE: begin
                // Sign-extend the 12-bit immediate (split across two fields)
                imm_ext = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
            end
            
            // B-type instructions (branches)
            OP_BRANCH: begin
                // Sign-extend the 13-bit immediate (split across multiple fields)
                // Note: LSB is always 0 for branches (2-byte alignment)
                imm_ext = {{19{instruction[31]}}, instruction[31], instruction[7], instruction[30:25], instruction[11:8], 1'b0};
            end
            
            // U-type instructions (LUI, AUIPC)
            OP_LUI, OP_AUIPC: begin
                // 20-bit immediate placed in the upper 20 bits
                imm_ext = {instruction[31:12], 12'b0};
            end
            
            // J-type instructions (JAL)
            OP_JAL: begin
                // Sign-extend the 21-bit immediate (split across multiple fields)
                // Note: LSB is always 0 for jumps (2-byte alignment)
                imm_ext = {{11{instruction[31]}}, instruction[31], instruction[19:12], instruction[20], instruction[30:21], 1'b0};
            end
            
            default: begin
                // Default to zero
                imm_ext = 32'b0;
            end
        endcase
    end

endmodule 