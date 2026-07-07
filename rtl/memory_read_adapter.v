module memory_read_adapter (
    input wire [31:0] data_in,
    input wire [2:0] funct3,
    input wire [1:0] addr_bits_lsb,
    input wire mem_read,
    output reg [31:0] load_result
);

    reg [7:0] selected_byte;
    wire [15:0] selected_half;
    wire [31:0] selected_word;

    assign selected_half = addr_bits_lsb[1] ? data_in[31:16] : data_in[15:0];
    assign selected_word = data_in;

    always @ (*) begin
        case (addr_bits_lsb)
            2'b00: selected_byte = data_in[7:0];
            2'b01: selected_byte = data_in[15:8];
            2'b10: selected_byte = data_in[23:16];
            2'b11: selected_byte = data_in[31:24];
            default: selected_byte = data_in[7:0];
        endcase
    end

    always @ (*) begin
        load_result = 32'b0;
        if (mem_read) begin
            case (funct3)
                3'b000: load_result = {{24{selected_byte[7]}}, selected_byte}; // LB
                3'b001: load_result = {{16{selected_half[15]}}, selected_half}; // LH
                3'b010: load_result = selected_word;                           // LW
                3'b100: load_result = {24'b0, selected_byte};                  // LBU
                3'b101: load_result = {16'b0, selected_half};                  // LHU
                default: load_result = selected_word;
            endcase
        end
    end

endmodule
