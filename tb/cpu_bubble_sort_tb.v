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
    localparam DISPLAY_EDGE_COUNT = (ARRAY_SIZE < 25) ? ARRAY_SIZE : 25;
    localparam TIMEOUT_CYCLES = (ARRAY_SIZE * ARRAY_SIZE * 100) + 10000;
    localparam DATA_BASE_WORD = 256;
    // Memory interface
    wire [31:0] instr_addr;
    wire [31:0] instruction;
    wire [31:0] data_addr;
    wire [31:0] data_out;
    wire [31:0] data_in;
    wire mem_write;
    wire mem_read;

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

    // One dual-port SRAM presents a unified memory image to the CPU.
    bsram #(
        .DATA_WIDTH(32),
        .DEPTH(2048),
        .INIT_FILE("tb/bubble_sort.hex")
    ) block_sram (
        .clk(clk),
        .rst(rst),
        .addr_port1(instr_addr),
        .data_in_port1(32'b0),
        .data_out_port1(instruction),
        .we_port1(1'b0),
        .re_port1(1'b1),
        .addr_port2(data_addr),
        .data_in_port2(data_out),
        .data_out_port2(data_in),
        .we_port2(mem_write),
        .re_port2(mem_read)
    );

    
    // Clock generation
    always begin
        #5 clk = ~clk;
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
        // - Word DATA_BASE_WORD contains the length of the array
        // - Words DATA_BASE_WORD+1 through DATA_BASE_WORD+ARRAY_SIZE contain the unsorted array
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
        
        if (block_sram.mem[DATA_BASE_WORD] != ARRAY_SIZE)
            $display("WARN: array length word is %0d, expected %0d",
                     block_sram.mem[DATA_BASE_WORD], ARRAY_SIZE);
        
        $display("Unsorted array (%0d elements):", ARRAY_SIZE);
        for (i = 0; i < ARRAY_SIZE; i = i + 1) begin
            $display("data[%0d] = %0d", i, block_sram.mem[DATA_BASE_WORD + i + 1]);
        end

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
        for (i = 0; i < DISPLAY_EDGE_COUNT; i = i + 1) begin
            $display("data[%0d] = %0d", i, block_sram.mem[DATA_BASE_WORD + i + 1]);
        end
        
        $display("...");
        
        // Display last 25 elements
        for (i = ARRAY_SIZE - DISPLAY_EDGE_COUNT; i < ARRAY_SIZE; i = i + 1) begin
            $display("data[%0d] = %0d", i, block_sram.mem[DATA_BASE_WORD + i + 1]);
        end
        
        // Verify the sorting worked by checking if the array is in ascending order
        $display("\nVerification:");
        begin
            sorted = 1;
            for (i = 1; i < ARRAY_SIZE; i = i + 1) begin
                if (block_sram.mem[DATA_BASE_WORD + i] > block_sram.mem[DATA_BASE_WORD + i + 1]) begin
                    sorted = 0;
                    $display("FAIL: Array not sorted correctly at index %0d (%0d > %0d)", 
                             i-1,
                             block_sram.mem[DATA_BASE_WORD + i],
                             block_sram.mem[DATA_BASE_WORD + i + 1]);
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
