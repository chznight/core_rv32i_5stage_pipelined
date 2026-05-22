module bsram #(
    parameter DATA_WIDTH = 32,
    parameter DEPTH      = 2048,

    // Optional init file. Example: "program.hex"
    parameter INIT_FILE = ""
)(
    input  wire                  clk,
    input  wire                  rst,

    input  wire [31:0]           addr_port1,
    input  wire [DATA_WIDTH-1:0] data_in_port1,
    output wire [DATA_WIDTH-1:0] data_out_port1,
    input  wire                  we_port1,
    input  wire                  re_port1,

    input  wire [31:0]           addr_port2,
    input  wire [DATA_WIDTH-1:0] data_in_port2,
    output wire [DATA_WIDTH-1:0] data_out_port2,
    input  wire                  we_port2,
    input  wire                  re_port2
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
    
    reg [ADDR_WIDTH-1:0] read_addr_port1;

    wire [ADDR_WIDTH-1:0] word_addr_port1;
    // Convert byte address to word index (drop addr[1:0] for 32-bit words).
    assign word_addr_port1 = addr_port1[ADDR_WIDTH+1:2];

    reg [ADDR_WIDTH-1:0] read_addr_port2;

    wire [ADDR_WIDTH-1:0] word_addr_port2;
    // Convert byte address to word index (drop addr[1:0] for 32-bit words).
    assign word_addr_port2 = addr_port2[ADDR_WIDTH+1:2];

    // Memory initialization happens at FPGA configuration / simulation start,
    // not during reset.
    initial begin
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, mem);
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            read_addr_port1 <= {ADDR_WIDTH{1'b0}};
        end else begin
            if (we_port1) begin
                mem[word_addr_port1] <= data_in_port1;
            end else if (re_port1) begin
                read_addr_port1 <= word_addr_port1;
            end
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            read_addr_port2 <= {ADDR_WIDTH{1'b0}};
        end else begin
            if (we_port2) begin
                mem[word_addr_port2] <= data_in_port2;
            end else if (re_port2) begin
                read_addr_port2 <= word_addr_port2;
            end
        end
    end

    // Gowin BSRAM bypass mode: the read address is registered, but the
    // memory output is not passed through the optional output pipeline register.
    assign data_out_port1 = mem[read_addr_port1];
    assign data_out_port2 = mem[read_addr_port2];

endmodule
