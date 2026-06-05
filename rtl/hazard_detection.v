module hazard_detection(
    input wire ID_EX_MemRead,
    input wire EX_MEM_MemRead,
    input wire [4:0] ID_EX_Rd,
    input wire [4:0] EX_MEM_Rd,
    input wire [4:0] IF_ID_Rs1,
    input wire [4:0] IF_ID_Rs2,
    output reg stall
);

    always @(*) begin
        // Detect load-use hazard
        // If the instruction in EX stage is a load (MemRead = 1),
        // and its destination register (Rd) is the same as one of the source registers
        // of the instruction in ID stage (Rs1 or Rs2), then stall the pipeline
        if (ID_EX_MemRead && 
            ((ID_EX_Rd == IF_ID_Rs1) || (ID_EX_Rd == IF_ID_Rs2)) && 
            (ID_EX_Rd != 0)) begin
            stall = 1'b1; // Stall the pipeline
        end else begin
            stall = 1'b0; // No stall
        end
    end

endmodule 