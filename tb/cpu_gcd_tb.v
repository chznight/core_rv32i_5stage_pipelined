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

    localparam MEM_DEPTH = 64;
    
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
        .mem_read(mem_read)
    );

    bsram #(
        .DATA_WIDTH(32),
        .DEPTH(MEM_DEPTH),
        .INIT_FILE("tb/gcd.hex")
    ) instr_sram (
        .clk(clk),
        .rst(rst),
        .addr(instr_addr),
        .data_in(32'b0),
        .data_out(instruction),
        .we(1'b0),
        .re(1'b1)
    );

    bsram #(
        .DATA_WIDTH(32),
        .DEPTH(MEM_DEPTH)
    ) data_sram (
        .clk(clk),
        .rst(rst),
        .addr(data_addr),
        .data_in(data_out),
        .data_out(data_in),
        .we(mem_write),
        .re(mem_read)
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

        for (i = 0; i < MEM_DEPTH; i = i + 1)
            data_sram.mem[i] = 32'h0;
        
        // Initialize instruction memory with GCD program
        // Program will calculate GCD of multiple pairs and store results in memory
        
        // Program logic:
        // - Memory address 0 contains the number of pairs (5)
        // - Starting from memory address 1, consecutive pairs of numbers
        // - Results will be stored after the pairs
        // - x1 will hold number A
        // - x2 will hold number B
        // - x3 will hold the result register
        // - x4 will track memory address for reading pairs and storing results
        // - x5 will hold the number of pairs to process
        // - x6 will be used as a counter
        
        // Load test pairs into memory before starting
        data_sram.mem[0] = 32'd5;  // Number of pairs to test
        
        // Test pairs
        data_sram.mem[1] = 32'd48;  data_sram.mem[2] = 32'd36;   // GCD = 12
        data_sram.mem[3] = 32'd101; data_sram.mem[4] = 32'd13;   // GCD = 1
        data_sram.mem[5] = 32'd128; data_sram.mem[6] = 32'd32;   // GCD = 32
        data_sram.mem[7] = 32'd27;  data_sram.mem[8] = 32'd9;    // GCD = 9
        data_sram.mem[9] = 32'd56;  data_sram.mem[10] = 32'd42;  // GCD = 14

        // Apply reset
        #10 rst = 0;
        
        // Run simulation for a fixed time
        #5000;
        
        // Display results
        $display("GCD Test Results:");
        for (i = 0; i < 5; i = i + 1) begin
            $display("GCD(%0d, %0d) = %0d", data_sram.mem[i*2+1], data_sram.mem[i*2+2], data_sram.mem[i+11]);
        end
        
        // Verify the expected GCD values
        $display("\nVerification:");
        if (data_sram.mem[11] == 12 && data_sram.mem[12] == 1 && data_sram.mem[13] == 32 &&
            data_sram.mem[14] == 9 && data_sram.mem[15] == 14) begin
            $display("PASS: All GCD calculations correct");
        end else begin
            $display("FAIL: GCD calculations incorrect");
            for (i = 0; i < 5; i = i + 1) begin
                if (i == 0 && data_sram.mem[11] != 12) $display("Pair 1: Expected 12, got %0d", data_sram.mem[11]);
                if (i == 1 && data_sram.mem[12] != 1)  $display("Pair 2: Expected 1, got %0d", data_sram.mem[12]);
                if (i == 2 && data_sram.mem[13] != 32) $display("Pair 3: Expected 32, got %0d", data_sram.mem[13]);
                if (i == 3 && data_sram.mem[14] != 9)  $display("Pair 4: Expected 9, got %0d", data_sram.mem[14]);
                if (i == 4 && data_sram.mem[15] != 14) $display("Pair 5: Expected 14, got %0d", data_sram.mem[15]);
            end
        end
        
        $finish;
    end

endmodule 
