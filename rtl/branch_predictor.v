module branch_predictor (
    input wire clk,
    input wire reset,
    input wire [31:0] pc,
    output reg predict_taken,
    output wire [31:0] predict_branch_target,
    input wire [31:0] update_predictor_pc,
    input wire [31:0] update_predictor_branch_target,
    input wire update_predictor_en,
    input wire update_predictor_taken,
    input wire predictor_missed,
    input wire predictor_target_missed,
    input wire [1:0] instruction_type
);

    parameter PC_BITS = 8;
    parameter TABLE_LEN = 1 << PC_BITS;
    parameter JMP_TYPE=2'b10, BRANCH_TYPE=2'b01;

    reg [31:0] predictor_miss_counter;
    reg [31:0] predictor_target_miss_counter;
    reg [31:0] total_branches_counter;

    reg [0:1] counter_table [0:TABLE_LEN-1];
    reg [31:0] branch_target_table [0:TABLE_LEN-1];
    reg [30-PC_BITS-1:0] branch_tag_table [0:TABLE_LEN-1];
    reg branch_target_table_valid [0:TABLE_LEN-1];
    reg [1:0] instruction_type_table [0:TABLE_LEN-1];

    integer i;

    wire [PC_BITS-1:0] pc_index;
    wire [PC_BITS-1:0] update_predictor_pc_index;
    assign pc_index = pc[PC_BITS+1:2];
    assign update_predictor_pc_index = update_predictor_pc[PC_BITS+1:2];
    
    wire [1:0] counter_value;
    wire [1:0] current_value_before_update;
    assign counter_value = counter_table[pc_index];
    assign current_value_before_update = counter_table[update_predictor_pc_index];

    reg [1:0] next_counter_value;


    always @(*) begin
        if (update_predictor_taken) begin
            next_counter_value = (current_value_before_update == 2'b11) ? 2'b11 : current_value_before_update + 2'b01;
        end else begin
            next_counter_value = (current_value_before_update == 2'b00) ? 2'b00 : current_value_before_update - 2'b01;
        end
    end


    always @(*) begin
        predict_taken = 0;
        if (instruction_type_table[pc_index] == JMP_TYPE) begin
            if (branch_target_table_valid[pc_index] && branch_tag_table[pc_index] == pc[31:PC_BITS+2]) begin
                predict_taken = 1;
            end
        end else if (instruction_type_table[pc_index] == BRANCH_TYPE) begin
            if (counter_value >= 2'b10 && branch_target_table_valid[pc_index] && branch_tag_table[pc_index] == pc[31:PC_BITS+2]) begin
                predict_taken = 1;
            end
        end
    end
    
    assign predict_branch_target = branch_target_table[pc_index];

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < TABLE_LEN; i = i + 1) begin
                branch_target_table_valid[i] <= 1'b0;
                counter_table[i] <= 2'b01;
                instruction_type_table[i] <= 2'b00;
            end
        end else if (update_predictor_en) begin
            if (update_predictor_taken) begin
                branch_target_table_valid[update_predictor_pc_index] <= 1'b1;
                instruction_type_table[update_predictor_pc_index] <= instruction_type;
            end
            counter_table[update_predictor_pc_index] <= next_counter_value;
        end
    end
	 
	 always @(posedge clk) begin
        if (update_predictor_en & update_predictor_taken) begin
            branch_target_table[update_predictor_pc_index] <= update_predictor_branch_target;
            branch_tag_table[update_predictor_pc_index] <= update_predictor_pc[31:PC_BITS+2];
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            predictor_miss_counter <= 32'b0;
            predictor_target_miss_counter <= 32'b0;
        end else if (update_predictor_en && predictor_missed) begin
            predictor_miss_counter <= predictor_miss_counter + 1;
        end else if (update_predictor_en && predictor_target_missed) begin
            predictor_target_miss_counter <= predictor_target_miss_counter + 1;
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            total_branches_counter <= 32'b0;
        end else if (update_predictor_en) begin
            total_branches_counter <= total_branches_counter + 1;
        end
    end


endmodule
