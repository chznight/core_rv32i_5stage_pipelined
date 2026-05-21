module cpu_bubble_sort_tb;
    localparam ARRAY_SIZE = 200;
    localparam DATA_MEM_WORDS = ARRAY_SIZE + 1;

    // Clock and reset
    reg clk;
    reg rst;
    integer i;
    integer sorted = 1;
    integer cycle_count;
    reg sort_done_reported;
    // Memory interface
    wire [31:0] instr_addr;
    reg [31:0] instruction;
    wire [31:0] data_addr;
    wire [31:0] data_out;
    reg [31:0] data_in;
    wire mem_write;
    wire mem_read;
    
    // Instruction memory (ROM)
    reg [31:0] instr_mem [0:127];
    
    // Data memory (RAM) - word 0 is length, words 1..ARRAY_SIZE are data
    reg [31:0] data_mem [0:DATA_MEM_WORDS-1];
    
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
    
    // Clock generation
    always begin
        #5 clk = ~clk;
    end
    
    // Memory read/write
    always @(*) begin
        // Provide instruction from instruction memory
        instruction = instr_mem[instr_addr[20:2]]; // Word-aligned addresses
        
        // Provide data from data memory
        if (mem_read)
            data_in = data_mem[data_addr[20:2]];
    end
    
    // Handle memory writes
    always @(posedge clk) begin
        if (mem_write)
            data_mem[data_addr[20:2]] <= data_out;
    end

    // Count clock cycles after reset; print once when sort marks done (x20 = 1)
    initial begin
        cycle_count = 0;
        sort_done_reported = 0;
    end

    always @(posedge clk) begin
        if (rst) begin
            cycle_count = 0;
            sort_done_reported = 0;
        end else begin
            cycle_count = cycle_count + 1;
            if (cpu_inst.registers.registers[20] == 32'd1 && !sort_done_reported) begin
                sort_done_reported = 1;
                $display("Sort finished after %0d clock cycles", cycle_count);
            end
        end
    end

    initial begin
        $dumpfile("cpu_bubble_sort_tb.vcd");
        $dumpvars(0, cpu_bubble_sort_tb);
    end

    function [31:0] pseudo_random_word;
        input [31:0] index;
        reg [31:0] value;
        begin
            value = index + 32'h9e3779b9;
            value = value ^ (value << 13);
            value = value ^ (value >> 17);
            value = value ^ (value << 5);
            pseudo_random_word = {16'd0, value[15:0]} + 32'd1;
        end
    endfunction

    // Test program for bubble sort
    initial begin
        // Initialize signals
        clk = 0;
        rst = 1;
        
        // Initialize instruction memory with bubble sort program
        // Program will sort an array of integers in memory
        
        // Program logic:
        // - Memory address 0 contains the length of the array
        // - Memory addresses 1..ARRAY_SIZE contain the unsorted array
        // - The sorted array will be in the same locations after execution
        // - Register usage:
        //   x1: array base address (4, after the length word)
        //   x2: outer loop counter (i)
        //   x3: inner loop counter (j)
        //   x4: array length
        //   x5: temporary for address calculations
        //   x6, x7: values being compared
        //   x8: array length - 1
        //   x9: array base address (constant)
        
        // Load test array into memory
        data_mem[0] = ARRAY_SIZE;
        
        // Generate the same deterministic pseudo-random elements as the FPGA top
        for (i = 1; i <= ARRAY_SIZE; i = i + 1) begin
            data_mem[i] = pseudo_random_word(i);
        end
        
        $display("Unsorted array (%0d elements):", ARRAY_SIZE);
        for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
            $display("data[%0d] = %0d", i, data_mem[i+1]);
        end

        // Memory initialization format
        // addi x1, x0, 4       # Initialize base address (skip length word)
        instr_mem[0] = 32'h00400093;
        
        // lw   x4, -4(x1)      # Load array length from memory address 0
        instr_mem[1] = 32'hffc0a203;
        
        // addi x9, x1, 0       # Save base address in x9
        instr_mem[2] = 32'h00008493;
        
        // addi x8, x4, -1      # n-1 for loop bound
        instr_mem[3] = 32'hfff20413;
        
        // addi x2, x0, 0       # Initialize outer loop counter i=0
        instr_mem[4] = 32'h00000113;
        
        // OUTER_LOOP:
        // bge  x2, x8, SORT_DONE # If i >= n-1, sorting is done
        instr_mem[5] = 32'h02815e63;
        
        // addi x3, x0, 0       # Initialize inner loop counter j=0
        instr_mem[6] = 32'h00000193;
        
        // INNER_LOOP:
        // sub  x5, x8, x2      # Calculate n-1-i
        instr_mem[7] = 32'h402402b3;
        
        // bge  x3, x5, OUTER_INCREMENT # If j >= n-1-i, inner loop done
        instr_mem[8] = 32'h0251d463;
        
        // slli x5, x3, 2       # j*4 (word offset)
        instr_mem[9] = 32'h00219293;
        
        // add  x5, x1, x5      # base_addr + j*4
        instr_mem[10] = 32'h005082b3;
        
        // lw   x6, 0(x5)       # Load data[j]
        instr_mem[11] = 32'h0002a303;
        
        // lw   x7, 4(x5)       # Load data[j+1]
        instr_mem[12] = 32'h0042a383;
        
        // blt  x6, x7, SKIP_SWAP # If data[j] <= data[j+1], skip swap
        instr_mem[13] = 32'h00734663;
        
        // sw   x7, 0(x5)       # Store data[j+1] to data[j]
        instr_mem[14] = 32'h0072a023;
        
        // sw   x6, 4(x5)       # Store data[j] to data[j+1]
        instr_mem[15] = 32'h0062a223;
        
        // SKIP_SWAP:
        // addi x3, x3, 1       # j++
        instr_mem[16] = 32'h00118193;
        
        // jal  x0, INNER_LOOP  # Jump back to inner loop
        instr_mem[17] = 32'hfd9ff06f;
        
        // OUTER_INCREMENT:
        // addi x2, x2, 1       # i++
        instr_mem[18] = 32'h00110113;
        
        // jal  x0, OUTER_LOOP  # Jump back to outer loop
        instr_mem[19] = 32'hfc9ff06f;
        
        // SORT_DONE:
        // addi x20, x0, 1      # Mark completion with flag in x20
        instr_mem[20] = 32'h00100a13;

        // Apply reset
        #10 rst = 0;
        
        // Run simulation for bubble sort with ARRAY_SIZE elements
        #6400000;

        if (!sort_done_reported)
            $display("Sort completion not observed before timeout (x20 = %0d)",
                     cpu_inst.registers.registers[20]);
        $display("Total clock cycles after reset deassert: %0d", cycle_count);
        $display("x20 = %0d (Expected: 1)", cpu_inst.registers.registers[20]);
        // Display the results
        $display("Bubble Sort Test Results:");
        $display("Sorted array (first 25 and last 25 elements):");
        
        // Display first 25 elements
        for (i = 0; i < 25; i = i + 1) begin
            $display("data[%0d] = %0d", i, data_mem[i+1]);
        end
        
        $display("...");
        
        // Display last 25 elements
        for (i = ARRAY_SIZE - 25; i < ARRAY_SIZE; i = i + 1) begin
            $display("data[%0d] = %0d", i, data_mem[i+1]);
        end
        
        // Verify the sorting worked by checking if the array is in ascending order
        $display("\nVerification:");
        begin
            sorted = 1;
            for (i = 1; i < ARRAY_SIZE; i = i + 1) begin
                if (data_mem[i] > data_mem[i+1]) begin
                    sorted = 0;
                    $display("FAIL: Array not sorted correctly at index %0d (%0d > %0d)", 
                             i-1, data_mem[i], data_mem[i+1]);
                    i = ARRAY_SIZE; // Break the loop
                end
            end
            
            if (sorted) begin
                $display("PASS: Array sorted correctly");
            end else begin
                $display("FAIL: Array not sorted correctly");
            end
        end
        $display("PC %0d", cpu_inst.PC);
        $display("x2 %0d", cpu_inst.registers.registers[2]);
        $display("x3 %0d", cpu_inst.registers.registers[3]);
        $display("x4 %0d", cpu_inst.registers.registers[4]);
        $display("x5 %0d", cpu_inst.registers.registers[5]);
        $display("x6 %0d", cpu_inst.registers.registers[6]);
        $finish;
    end
endmodule 
