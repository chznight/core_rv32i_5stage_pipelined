// Copyright (c) 2026 chznight
// SPDX-License-Identifier: MIT

module forwarding_unit(
    input wire EX_MEM_RegWrite,
    input wire MEM_WB_RegWrite,
    input wire [4:0] EX_MEM_Rd,
    input wire [4:0] MEM_WB_Rd,
    input wire [4:0] ID_EX_Rs1,
    input wire [4:0] ID_EX_Rs2,
    output reg [1:0] ForwardA,
    output reg [1:0] ForwardB
);

    always @(*) begin
        // Forward A logic (controls the first ALU input)
        if (EX_MEM_RegWrite && (EX_MEM_Rd != 5'b0) && (EX_MEM_Rd == ID_EX_Rs1)) begin
            // Forward from EX/MEM pipeline register
            ForwardA = 2'b10;
        end else if (MEM_WB_RegWrite && (MEM_WB_Rd != 5'b0) && (MEM_WB_Rd == ID_EX_Rs1)) begin
            // Forward from MEM/WB pipeline register
            ForwardA = 2'b01;
        end
        else begin
            // No forwarding, use register file output
            ForwardA = 2'b00;
        end
        
        // Forward B logic (controls the second ALU input)
        if (EX_MEM_RegWrite && (EX_MEM_Rd != 5'b0) && (EX_MEM_Rd == ID_EX_Rs2)) begin
            // Forward from EX/MEM pipeline register
            ForwardB = 2'b10;
        end
        else if (MEM_WB_RegWrite && (MEM_WB_Rd != 5'b0) && (MEM_WB_Rd == ID_EX_Rs2)) begin
            // Forward from MEM/WB pipeline register
            ForwardB = 2'b01;
        end
        else begin
            // No forwarding, use register file output
            ForwardB = 2'b00;
        end
    end

endmodule 