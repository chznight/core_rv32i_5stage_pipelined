module branch_predictor #(
    parameter PC_BITS = 8,
    parameter TABLE_LEN = 1 << PC_BITS,
    parameter JMP_TYPE = 2'b10,
    parameter BRANCH_TYPE = 2'b01
)(
    input wire clk,
    input wire reset,
    input wire [31:0] pc,
    output reg predict_taken,
    output wire [31:0] predict_branch_target,
    input wire [31:0] update_predictor_pc,
    input wire [31:0] update_predictor_branch_target,
    input wire update_pht_en,
    input wire update_btb_en,
    input wire update_predictor_taken,
    input wire predictor_missed,
    input wire predictor_target_missed,
    input wire [1:0] instruction_type,
    output wire [PC_BITS-1:0] branch_gshare_index,
    input [PC_BITS-1:0] predictor_update_gshare_index
);

    reg [31:0] predictor_miss_counter;
    reg [31:0] predictor_target_miss_counter;
    reg [31:0] total_branches_counter;

    // ============================================================
    // Gshare state
    // ============================================================
    // Global branch history register.
    reg [PC_BITS-1:0] global_history;

    // Pattern History Table, PHT.
    // 2-bit saturating counters:
    reg [1:0] counter_table [0:TABLE_LEN-1];

    // ============================================================
    // BTB state
    // ============================================================
    reg [31:0] branch_target_table [0:TABLE_LEN-1];
    reg [30-PC_BITS-1:0] branch_tag_table [0:TABLE_LEN-1];
    reg branch_target_table_valid [0:TABLE_LEN-1];
    reg [1:0] instruction_type_table [0:TABLE_LEN-1];

    integer i;

    // ============================================================
    // Index calculation
    // ============================================================
    wire [PC_BITS-1:0] pc_index;
    wire [PC_BITS-1:0] update_predictor_pc_index;

    assign pc_index = pc[PC_BITS+1:2];
    assign update_predictor_pc_index = update_predictor_pc[PC_BITS+1:2];

    // Gshare index = PC bits XOR global history
    wire [PC_BITS-1:0] gshare_index;
    wire [PC_BITS-1:0] update_gshare_index;

    assign gshare_index = pc_index ^ global_history;
    assign update_gshare_index = predictor_update_gshare_index;
    assign branch_gshare_index = gshare_index;

    // Direction counter selected by gshare index
    wire [1:0] counter_value;
    wire [1:0] current_value_before_update;

    assign counter_value = counter_table[gshare_index];
    assign current_value_before_update = counter_table[update_gshare_index];

    reg [1:0] next_counter_value;

    // ============================================================
    // 2-bit saturating counter update logic
    // ============================================================

    always @(*) begin
        if (update_predictor_taken) begin
            if (current_value_before_update == 2'b11)
                next_counter_value = 2'b11;
            else
                next_counter_value = current_value_before_update + 2'b01;
        end else begin
            if (current_value_before_update == 2'b00)
                next_counter_value = 2'b00;
            else
                next_counter_value = current_value_before_update - 2'b01;
        end
    end

    // ============================================================
    // Prediction logic
    // ============================================================

    always @(*) begin
        predict_taken = 1'b0;
        if (branch_target_table_valid[pc_index] && (branch_tag_table[pc_index] == pc[31:PC_BITS+2])) begin
            if (instruction_type_table[pc_index] == JMP_TYPE) begin
                predict_taken = 1'b1;
            end else if (instruction_type_table[pc_index] == BRANCH_TYPE) begin
                if (counter_value >= 2'b10) begin
                    predict_taken = 1'b1;
                end
            end
        end
    end
    // Target still comes from PC-indexed BTB
    assign predict_branch_target = branch_target_table[pc_index];

    // ============================================================
    // Predictor table update
    // ============================================================
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            global_history <= {PC_BITS{1'b0}};
            for (i = 0; i < TABLE_LEN; i = i + 1) begin
                branch_target_table_valid[i] <= 1'b0;
                counter_table[i] <= 2'b01;
            end
        end else begin
            if (update_pht_en) begin
                // Update the gshare direction counter
                counter_table[update_gshare_index] <= next_counter_value;
            end
            if (update_pht_en || update_btb_en) begin
                // Update global branch history
                global_history <= {global_history[PC_BITS-2:0], update_predictor_taken};
            end
            // Only taken branches/jumps need a target in the BTB
            if (update_predictor_taken && update_btb_en) begin
                branch_target_table_valid[update_predictor_pc_index] <= 1'b1;
            end
        end
    end

    // ============================================================
    // BTB target/tag update
    // ============================================================
    always @(posedge clk) begin
        if (update_btb_en && update_predictor_taken) begin
            branch_target_table[update_predictor_pc_index] <= update_predictor_branch_target;
            branch_tag_table[update_predictor_pc_index] <= update_predictor_pc[31:PC_BITS+2];
            instruction_type_table[update_predictor_pc_index] <= instruction_type;
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            predictor_miss_counter <= 32'b0;
            predictor_target_miss_counter <= 32'b0;
        end else if (update_pht_en | update_btb_en) begin
            if (predictor_missed) begin
                predictor_miss_counter <= predictor_miss_counter + 1;
            end

            if (predictor_target_missed) begin
                predictor_target_miss_counter <= predictor_target_miss_counter + 1;
            end
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            total_branches_counter <= 32'b0;
        end else if (update_pht_en | update_btb_en) begin
            total_branches_counter <= total_branches_counter + 1;
        end
    end

endmodule