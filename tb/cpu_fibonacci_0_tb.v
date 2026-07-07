module cpu_fibonacci_tb;
    // Clock and reset
    reg clk;
    reg rst;
    integer i;

    localparam DATA_BASE_WORD = 256;
    
    // Memory interface
    wire [31:0] instr_addr;
    wire [31:0] instruction;
    wire [31:0] data_addr;
    wire [31:0] data_out;
    wire [31:0] data_in;
    wire mem_write;
    wire mem_read;
    wire [3:0] byte_enable;

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
        .INIT_FILE("tb/fibonacci_0.hex")
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

    // Create VCD file for waveform analysis
    initial begin
        $dumpfile("cpu_fibonacci_tb.vcd");
        $dumpvars(0, cpu_fibonacci_tb);
    end

    // Test program for Fibonacci sequence
    initial begin
        // Initialize signals
        clk = 0;
        rst = 1;

        // Apply reset
        #10 rst = 0;
        
        // Run simulation for a fixed time
        // Should be long enough for the program to complete 20 Fibonacci numbers
        #2500;
        
        // Display results
        $display("Fibonacci Sequence:");
        for (i = 0; i < 20; i = i + 1) begin
            $display("Fib[%0d] = %0d", i, block_sram.mem[DATA_BASE_WORD + i]);
        end
        
        // The expected Fibonacci sequence starts with 1, 1, 2, 3, 5, 8, 13, 21, 34, 55...
        if (block_sram.mem[DATA_BASE_WORD + 0] == 1 && block_sram.mem[DATA_BASE_WORD + 1] == 1 && block_sram.mem[DATA_BASE_WORD + 2] == 2 &&
            block_sram.mem[DATA_BASE_WORD + 3] == 3 && block_sram.mem[DATA_BASE_WORD + 4] == 5 && block_sram.mem[DATA_BASE_WORD + 5] == 8 &&
            block_sram.mem[DATA_BASE_WORD + 6] == 13 && block_sram.mem[DATA_BASE_WORD + 7] == 21 && block_sram.mem[DATA_BASE_WORD + 8] == 34 &&
            block_sram.mem[DATA_BASE_WORD + 9] == 55 && block_sram.mem[DATA_BASE_WORD + 10] == 89 && block_sram.mem[DATA_BASE_WORD + 11] == 144 &&
            block_sram.mem[DATA_BASE_WORD + 12] == 233 && block_sram.mem[DATA_BASE_WORD + 13] == 377 && block_sram.mem[DATA_BASE_WORD + 14] == 610 &&
            block_sram.mem[DATA_BASE_WORD + 15] == 987 && block_sram.mem[DATA_BASE_WORD + 16] == 1597 && block_sram.mem[DATA_BASE_WORD + 17] == 2584 &&
            block_sram.mem[DATA_BASE_WORD + 18] == 4181 && block_sram.mem[DATA_BASE_WORD + 19] == 6765) begin
            $display("PASS: First 20 Fibonacci numbers calculated correctly");
        end else begin
            $display("FAIL: Fibonacci sequence incorrect");
            $display("Expected: 1, 1, 2, 3, 5, 8, 13, 21, 34, 55, ..., 6765");
            $display("Got first 10: %0d, %0d, %0d, %0d, %0d, %0d, %0d, %0d, %0d, %0d...",
                     block_sram.mem[DATA_BASE_WORD + 0], block_sram.mem[DATA_BASE_WORD + 1], block_sram.mem[DATA_BASE_WORD + 2], block_sram.mem[DATA_BASE_WORD + 3], block_sram.mem[DATA_BASE_WORD + 4],
                     block_sram.mem[DATA_BASE_WORD + 5], block_sram.mem[DATA_BASE_WORD + 6], block_sram.mem[DATA_BASE_WORD + 7], block_sram.mem[DATA_BASE_WORD + 8], block_sram.mem[DATA_BASE_WORD + 9]);
            $display("Got Fib[19]: %0d", block_sram.mem[DATA_BASE_WORD + 19]);
        end
        
        $finish;
    end
endmodule 
