module cpu_gcd_tb;
    // Clock and reset
    reg clk;
    reg rst;
    integer i;
    // Memory interface
    wire [31:0] instr_addr;
    wire [31:0] instruction;
    wire [31:0] data_addr;
    wire [31:0] data_out;
    wire [31:0] data_in;
    wire mem_write;
    wire mem_read;
    wire [3:0] byte_enable;

    localparam DATA_BASE_WORD = 256;
    
    // Instantiate the CPU
    cpu cpu_inst(
        .clk(clk),
        .rst(rst),
        .instr_addr(instr_addr),
        .instruction(instruction),
        .data_addr(data_addr),
        .data_out(data_out),
        .data_in(data_in),
        .mem_write(mem_write),
        .mem_read(mem_read),
        .byte_enable(byte_enable)
    );

    // One dual-port SRAM presents a unified memory image to the CPU.
    bsram #(
        .DATA_WIDTH(32),
        .DEPTH(2048),
        .INIT_FILE("tb/gcd.hex")
    ) block_sram (
        .clk(clk),
        .rst(rst),
        .addr_port1(instr_addr),
        .data_in_port1(32'b0),
        .data_out_port1(instruction),
        .we_port1(1'b0),
        .byte_enable_port1(4'b1111),
        .re_port1(1'b1),
        .addr_port2(data_addr),
        .data_in_port2(data_out),
        .data_out_port2(data_in),
        .we_port2(mem_write),
        .byte_enable_port2(byte_enable),
        .re_port2(mem_read)
    );

    // Clock generation
    always begin
        #5 clk = ~clk;
    end

    initial begin
        $dumpfile("cpu_gcd_tb.vcd");
        $dumpvars(0, cpu_gcd_tb);
    end

    // Test program for GCD calculation
    initial begin
        // Initialize signals
        clk = 0;
        rst = 1;

        // Initialize instruction memory with GCD program
        // Program will calculate GCD of multiple pairs and store results in memory
        
        // Program logic:
        // - Word DATA_BASE_WORD contains the number of pairs (5)
        // - Starting from word DATA_BASE_WORD+1, consecutive pairs of numbers
        // - Results will be stored after the pairs
        // - x1 will hold number A
        // - x2 will hold number B
        // - x3 will hold the result register
        // - x4 will track memory address for reading pairs and storing results
        // - x5 will hold the number of pairs to process
        // - x6 will be used as a counter
        
        // Apply reset
        #10 rst = 0;
        
        // Run simulation for a fixed time
        #5000;
        
        // Display results
        $display("GCD Test Results:");
        for (i = 0; i < 5; i = i + 1) begin
            $display("GCD(%0d, %0d) = %0d",
                     block_sram.mem[DATA_BASE_WORD + i*2 + 1],
                     block_sram.mem[DATA_BASE_WORD + i*2 + 2],
                     block_sram.mem[DATA_BASE_WORD + i + 11]);
        end
        
        // Verify the expected GCD values
        $display("\nVerification:");
        if (block_sram.mem[DATA_BASE_WORD + 11] == 12 &&
            block_sram.mem[DATA_BASE_WORD + 12] == 1 &&
            block_sram.mem[DATA_BASE_WORD + 13] == 32 &&
            block_sram.mem[DATA_BASE_WORD + 14] == 9 &&
            block_sram.mem[DATA_BASE_WORD + 15] == 14) begin
            $display("PASS: All GCD calculations correct");
        end else begin
            $display("FAIL: GCD calculations incorrect");
            for (i = 0; i < 5; i = i + 1) begin
                if (i == 0 && block_sram.mem[DATA_BASE_WORD + 11] != 12) $display("Pair 1: Expected 12, got %0d", block_sram.mem[DATA_BASE_WORD + 11]);
                if (i == 1 && block_sram.mem[DATA_BASE_WORD + 12] != 1)  $display("Pair 2: Expected 1, got %0d", block_sram.mem[DATA_BASE_WORD + 12]);
                if (i == 2 && block_sram.mem[DATA_BASE_WORD + 13] != 32) $display("Pair 3: Expected 32, got %0d", block_sram.mem[DATA_BASE_WORD + 13]);
                if (i == 3 && block_sram.mem[DATA_BASE_WORD + 14] != 9)  $display("Pair 4: Expected 9, got %0d", block_sram.mem[DATA_BASE_WORD + 14]);
                if (i == 4 && block_sram.mem[DATA_BASE_WORD + 15] != 14) $display("Pair 5: Expected 14, got %0d", block_sram.mem[DATA_BASE_WORD + 15]);
            end
        end
        
        $finish;
    end

endmodule 
