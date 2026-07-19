// Copyright (c) 2025 chznight
// SPDX-License-Identifier: MIT

// Two-wide gshare direction predictor with a PC-indexed BTB.
//
// The two lookup slots correspond to the instructions at the aligned
// eight-byte fetch address and at aligned address + 4. Both PHT lookups use
// the same committed global history so that they can execute in parallel.
//
// A prediction-time gshare index must travel with each fetched instruction.
// When that instruction resolves, its saved index is returned on
// predictor_update_gshare_index. Recomputing the index at resolution would
// be incorrect because global_history may have changed in the meantime.
module branch_predictor_g_share #(
    parameter PHT_BITS = 9,
    parameter BTB_BITS = 8,
    parameter PHT_LEN = 1 << PHT_BITS,
    parameter BTB_LEN = 1 << BTB_BITS,
    parameter JMP_TYPE = 2'b10,
    parameter BRANCH_TYPE = 2'b01
)(
    input wire clk,
    input wire reset,
    input wire [31:0] pc,

    output reg predict_taken_aligned,
    output reg predict_taken_aligned_plus_four,
    output wire [31:0] predict_branch_target,
    output wire [PHT_BITS-1:0] branch_gshare_index_aligned,
    output wire [PHT_BITS-1:0] branch_gshare_index_aligned_plus_four,

    input wire [31:0] update_predictor_pc,
    input wire [31:0] update_predictor_branch_target,
    input wire update_pht_en,
    input wire update_btb_en,
    input wire update_predictor_taken,
    input wire predictor_missed,
    input wire predictor_target_missed,
    input wire [1:0] instruction_type,
    input wire [PHT_BITS-1:0] predictor_update_gshare_index
);

    localparam BTB_TAG_BITS = 30 - BTB_BITS;

    reg [31:0] predictor_miss_counter;
    reg [31:0] predictor_target_miss_counter;
    reg [31:0] total_branches_counter;

    // Gshare state.
    reg [PHT_BITS-1:0] global_history;
    reg [1:0] counter_table [0:PHT_LEN-1];

    // BTB state.
    reg [31:0] branch_target_table [0:BTB_LEN-1];
    reg [BTB_TAG_BITS-1:0] branch_tag_table [0:BTB_LEN-1];
    reg branch_target_table_valid [0:BTB_LEN-1];
    reg [1:0] instruction_type_table [0:BTB_LEN-1];

    integer i;

    // Parallel lookup indices for the two words in an eight-byte fetch.
    wire [PHT_BITS-1:0] pc_pht_index_aligned;
    wire [PHT_BITS-1:0] pc_pht_index_aligned_plus_four;
    wire [PHT_BITS-1:0] gshare_index_aligned;
    wire [PHT_BITS-1:0] gshare_index_aligned_plus_four;

    wire [BTB_BITS-1:0] pc_btb_index_aligned;
    wire [BTB_BITS-1:0] pc_btb_index_aligned_plus_four;
    wire [BTB_BITS-1:0] update_btb_index;

    wire [BTB_TAG_BITS-1:0] pc_btb_tag;
    wire [BTB_TAG_BITS-1:0] update_btb_tag;

    assign pc_pht_index_aligned = {pc[PHT_BITS+1:3], 1'b0};
    assign pc_pht_index_aligned_plus_four = {pc[PHT_BITS+1:3], 1'b1};
    assign gshare_index_aligned = pc_pht_index_aligned ^ global_history;
    assign gshare_index_aligned_plus_four =
        pc_pht_index_aligned_plus_four ^ global_history;

    assign branch_gshare_index_aligned = gshare_index_aligned;
    assign branch_gshare_index_aligned_plus_four =
        gshare_index_aligned_plus_four;

    assign pc_btb_index_aligned = {pc[BTB_BITS+1:3], 1'b0};
    assign pc_btb_index_aligned_plus_four =
        {pc[BTB_BITS+1:3], 1'b1};
    assign update_btb_index = update_predictor_pc[BTB_BITS+1:2];

    assign pc_btb_tag = pc[31:BTB_BITS+2];
    assign update_btb_tag = update_predictor_pc[31:BTB_BITS+2];

    wire [1:0] counter_value_aligned;
    wire [1:0] counter_value_aligned_plus_four;
    wire [1:0] current_value_before_update;

    assign counter_value_aligned = counter_table[gshare_index_aligned];
    assign counter_value_aligned_plus_four =
        counter_table[gshare_index_aligned_plus_four];
    assign current_value_before_update =
        counter_table[predictor_update_gshare_index];

    reg [1:0] next_counter_value;

    always @(*) begin
        if (update_predictor_taken) begin
            next_counter_value = (current_value_before_update == 2'b11)
                ? 2'b11
                : current_value_before_update + 2'b01;
        end else begin
            next_counter_value = (current_value_before_update == 2'b00)
                ? 2'b00
                : current_value_before_update - 2'b01;
        end
    end

    wire btb_hit_aligned;
    wire btb_hit_aligned_plus_four;

    assign btb_hit_aligned =
        branch_target_table_valid[pc_btb_index_aligned] &&
        (branch_tag_table[pc_btb_index_aligned] == pc_btb_tag);
    assign btb_hit_aligned_plus_four =
        branch_target_table_valid[pc_btb_index_aligned_plus_four] &&
        (branch_tag_table[pc_btb_index_aligned_plus_four] == pc_btb_tag);

    always @(*) begin
        predict_taken_aligned = 1'b0;
        predict_taken_aligned_plus_four = 1'b0;

        // The lower word is not part of the fetch when pc points at +4.
        if ((pc[2:0] == 3'b000) && btb_hit_aligned) begin
            if (instruction_type_table[pc_btb_index_aligned] == JMP_TYPE) begin
                predict_taken_aligned = 1'b1;
            end else if (
                (instruction_type_table[pc_btb_index_aligned] == BRANCH_TYPE) &&
                (counter_value_aligned >= 2'b10)
            ) begin
                predict_taken_aligned = 1'b1;
            end
        end

        if (btb_hit_aligned_plus_four) begin
            if (
                instruction_type_table[pc_btb_index_aligned_plus_four] ==
                JMP_TYPE
            ) begin
                predict_taken_aligned_plus_four = 1'b1;
            end else if (
                (instruction_type_table[pc_btb_index_aligned_plus_four] ==
                    BRANCH_TYPE) &&
                (counter_value_aligned_plus_four >= 2'b10)
            ) begin
                predict_taken_aligned_plus_four = 1'b1;
            end
        end
    end

    // The first taken instruction in program order supplies the redirect.
    assign predict_branch_target = predict_taken_aligned
        ? branch_target_table[pc_btb_index_aligned]
        : branch_target_table[pc_btb_index_aligned_plus_four];

    // PHT and committed global-history update. update_pht_en is asserted only
    // for conditional branches; jumps update the BTB but not direction history.
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            global_history <= {PHT_BITS{1'b0}};
            for (i = 0; i < PHT_LEN; i = i + 1) begin
                counter_table[i] <= 2'b10;
            end
            for (i = 0; i < BTB_LEN; i = i + 1) begin
                branch_target_table_valid[i] <= 1'b0;
            end
        end else begin
            if (update_pht_en) begin
                counter_table[predictor_update_gshare_index] <=
                    next_counter_value;
                global_history <= {
                    global_history[PHT_BITS-2:0],
                    update_predictor_taken
                };
            end

            if (update_btb_en && update_predictor_taken) begin
                branch_target_table_valid[update_btb_index] <= 1'b1;
            end
        end
    end

    // The target, tag, and type do not require reset because the valid table
    // qualifies every lookup.
    always @(posedge clk) begin
        if (update_btb_en && update_predictor_taken) begin
            branch_target_table[update_btb_index] <=
                update_predictor_branch_target;
            branch_tag_table[update_btb_index] <= update_btb_tag;
            instruction_type_table[update_btb_index] <= instruction_type;
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            predictor_miss_counter <= 32'b0;
            predictor_target_miss_counter <= 32'b0;
        end else if (update_pht_en || update_btb_en) begin
            if (predictor_missed) begin
                predictor_miss_counter <= predictor_miss_counter + 1'b1;
            end
            if (predictor_target_missed) begin
                predictor_target_miss_counter <=
                    predictor_target_miss_counter + 1'b1;
            end
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            total_branches_counter <= 32'b0;
        end else if (update_pht_en || update_btb_en) begin
            total_branches_counter <= total_branches_counter + 1'b1;
        end
    end

endmodule
