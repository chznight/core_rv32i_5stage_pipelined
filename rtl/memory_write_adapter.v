module memory_write_adapter (
    input wire mem_write,
    input wire [31:0] mem_data_out,
    input wire [31:0] wr_addr,
    input wire [2:0] funct3,
    output reg [31:0] data_out,
    output reg [3:0] byte_enable
);
    always @(*) begin
        byte_enable = 4'b0000;
        data_out = mem_data_out;
        if (mem_write) begin
            case (funct3)
                3'b000: begin // SB
                    byte_enable = 4'b0001 << wr_addr[1:0];
                    data_out    = {24'b0, mem_data_out[7:0]} << {wr_addr[1:0], 3'b000};
                end

                3'b001: begin // SH
                    byte_enable = 4'b0011 << {wr_addr[1], 1'b0};
                    data_out    = {16'b0, mem_data_out[15:0]} << {wr_addr[1], 4'b0000};
                end

                3'b010: begin // SW
                    byte_enable = 4'b1111;
                    data_out    = mem_data_out;
                end

                default: begin
                    byte_enable = 4'b0000;
                    data_out = mem_data_out;
                end
            endcase
        end
    end
endmodule
