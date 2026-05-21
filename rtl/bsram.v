module bsram #(
    parameter DATA_WIDTH = 32,
    parameter DEPTH      = 1024,

    // Optional init file. Example: "program.hex"
    parameter INIT_FILE = ""
)(
    input  wire                  clk,
    input  wire                  rst,

    input  wire [31:0]           addr,
    input  wire [DATA_WIDTH-1:0] data_in,
    output wire [DATA_WIDTH-1:0] data_out,

    input  wire                  we,
    input  wire                  re
);

    function integer clog2;
        input integer value;
        begin
            value = value - 1;
            for (clog2 = 0; value > 0; clog2 = clog2 + 1)
                value = value >> 1;
        end
    endfunction

    localparam ADDR_WIDTH = clog2(DEPTH);

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    reg [ADDR_WIDTH-1:0] read_addr;

    wire [ADDR_WIDTH-1:0] word_addr;
    // Convert byte address to word index (drop addr[1:0] for 32-bit words).
    assign word_addr = addr[ADDR_WIDTH+1:2];

    // Memory initialization happens at FPGA configuration / simulation start,
    // not during reset.
    initial begin
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, mem);
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            read_addr <= {ADDR_WIDTH{1'b0}};
        end else begin
            if (we) begin
                mem[word_addr] <= data_in;
            end else if (re) begin
                read_addr <= word_addr;
            end
        end
    end

    // Gowin BSRAM bypass mode: the read address is registered, but the
    // memory output is not passed through the optional output pipeline register.
    assign data_out = mem[read_addr];

endmodule
