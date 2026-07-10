// Copyright (c) 2025 chznight
// SPDX-License-Identifier: MIT

module control_unit(
    input wire [31:0] instruction,
    output reg reg_write,
    output reg mem_to_reg,
    output reg mem_read,
    output reg mem_write,
    output reg [3:0] alu_op,
    output reg alu_src,
    output reg branch,
    output reg jal,
    output reg jalr,
    output reg auipc
);

    // RISC Instruction format
    wire [6:0] opcode;
    wire [2:0] funct3;
    wire [6:0] funct7;
    
    assign opcode = instruction[6:0];
    assign funct3 = instruction[14:12];
    assign funct7 = instruction[31:25];
    
    // Opcode definitions (RISC-V like)
    parameter OP_R_TYPE     = 7'b0110011; // Register-Register operations
    parameter OP_I_TYPE     = 7'b0010011; // Register-Immediate operations
    parameter OP_LOAD       = 7'b0000011; // Load
    parameter OP_STORE      = 7'b0100011; // Store
    parameter OP_BRANCH     = 7'b1100011; // Branch
    parameter OP_JAL        = 7'b1101111; // Jump and Link
    parameter OP_JALR       = 7'b1100111; // Jump and Link Register
    parameter OP_LUI        = 7'b0110111; // Load Upper Immediate
    parameter OP_AUIPC      = 7'b0010111; // Add Upper Immediate to PC
    
    // ALU operation codes (same as in alu.v)
    parameter ALU_ADD  = 4'b0000;
    parameter ALU_SUB  = 4'b0001;
    parameter ALU_AND  = 4'b0010;
    parameter ALU_OR   = 4'b0011;
    parameter ALU_XOR  = 4'b0100;
    parameter ALU_SLL  = 4'b0101;
    parameter ALU_SRL  = 4'b0110;
    parameter ALU_SRA  = 4'b0111;
    parameter ALU_SLT  = 4'b1000;
    parameter ALU_SLTU = 4'b1001;
    parameter ALU_LUI  = 4'b1010;
    
    always @(*) begin
        // Default control values
        reg_write = 1'b0;
        mem_to_reg = 1'b0;
        mem_read = 1'b0;
        mem_write = 1'b0;
        alu_op = ALU_ADD;
        alu_src = 1'b0;
        branch = 1'b0;
        jal = 1'b0;
        jalr = 1'b0;
        auipc = 1'b0;

        case(opcode)
            OP_R_TYPE: begin
                // Register-Register instructions
                reg_write = 1'b1;
                alu_src = 1'b0; // Use register for ALU input
                mem_to_reg = 1'b0; // ALU result to register
                
                // Determine ALU operation based on funct3 and funct7
                case(funct3)
                    3'b000: begin // ADD/SUB
                        if (funct7 == 7'b0000000)
                            alu_op = ALU_ADD;
                        else if (funct7 == 7'b0100000)
                            alu_op = ALU_SUB;
                    end
                    3'b001: alu_op = ALU_SLL; // Shift left logical
                    3'b010: alu_op = ALU_SLT; // Set less than
                    3'b011: alu_op = ALU_SLTU; // Set less than unsigned
                    3'b100: alu_op = ALU_XOR; // XOR
                    3'b101: begin // SRL/SRA
                        if (funct7 == 7'b0000000)
                            alu_op = ALU_SRL;
                        else if (funct7 == 7'b0100000)
                            alu_op = ALU_SRA;
                    end
                    3'b110: alu_op = ALU_OR; // OR
                    3'b111: alu_op = ALU_AND; // AND
                endcase
            end
            
            OP_I_TYPE: begin
                // Register-Immediate instructions
                reg_write = 1'b1;
                alu_src = 1'b1; // Use immediate for ALU input
                mem_to_reg = 1'b0; // ALU result to register
                
                // Determine ALU operation based on funct3
                case(funct3)
                    3'b000: alu_op = ALU_ADD; // ADDI
                    3'b001: alu_op = ALU_SLL; // SLLI
                    3'b010: alu_op = ALU_SLT; // SLTI
                    3'b011: alu_op = ALU_SLTU; // SLTIU
                    3'b100: alu_op = ALU_XOR; // XORI
                    3'b101: begin
                        if (funct7 == 7'b0000000)
                            alu_op = ALU_SRL; // SRLI
                        else if (funct7 == 7'b0100000)
                            alu_op = ALU_SRA; // SRAI
                    end
                    3'b110: alu_op = ALU_OR; // ORI
                    3'b111: alu_op = ALU_AND; // ANDI
                endcase
            end
            
            OP_LOAD: begin
                // Load instruction
                reg_write = 1'b1;
                alu_src = 1'b1; // Use immediate for address calculation
                mem_to_reg = 1'b1; // Memory data to register
                mem_read = 1'b1; // Read from memory
                alu_op = ALU_ADD; // Address calculation
            end
            
            OP_STORE: begin
                // Store instruction
                reg_write = 1'b0; // No register write
                alu_src = 1'b1; // Use immediate for address calculation
                mem_write = 1'b1; // Write to memory
                alu_op = ALU_ADD; // Address calculation
            end
            
            OP_BRANCH: begin
                // Branch instructions
                reg_write = 1'b0; // No register write
                alu_src = 1'b0; // Use register for comparison
                branch = 1'b1; // Branch instruction
                
                // Determine ALU operation for comparison
                case(funct3)
                    3'b000: alu_op = ALU_SUB; // BEQ
                    3'b001: alu_op = ALU_SUB; // BNE
                    3'b100: alu_op = ALU_SLT; // BLT
                    3'b101: alu_op = ALU_SLT; // BGE
                    3'b110: alu_op = ALU_SLTU; // BLTU
                    3'b111: alu_op = ALU_SLTU; // BGEU
                    default: alu_op = ALU_SUB;
                endcase
            end
            
            OP_LUI: begin
                // Load Upper Immediate
                reg_write = 1'b1;
                alu_src = 1'b1; // Use immediate
                alu_op = ALU_LUI; // Pass immediate through ALU
            end
            
            OP_AUIPC: begin
                // Add Upper Immediate to PC
                reg_write = 1'b1;
                alu_src = 1'b1; // Use immediate
                alu_op = ALU_ADD; // PC + Immediate
                auipc = 1;
            end
            
            // JAL and JALR are simplified here
            OP_JAL: begin
                reg_write = 1'b1; // Write return address to rd
                alu_op = ALU_ADD; // For JALR: rs1 + imm
                jal = 1'b1;
            end

            OP_JALR: begin
                reg_write = 1'b1; // Write return address to rd
                alu_src = 1'b1; // Use immediate
                alu_op = ALU_ADD; // For JALR: rs1 + imm
                jalr = 1'b1;
            end
            
            default: begin
                // Default control values (NOP instruction)
                reg_write = 1'b0;
                mem_to_reg = 1'b0;
                mem_read = 1'b0;
                mem_write = 1'b0;
                alu_op = ALU_ADD;
                alu_src = 1'b0;
                branch = 1'b0;
                jal = 1'b0;
                jalr = 1'b0;
            end
        endcase
    end

endmodule 