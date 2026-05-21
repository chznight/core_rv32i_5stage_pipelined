module cpu_hazard_tb;
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
        .INIT_FILE("tb/hazard.hex")
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
        $dumpfile("cpu_hazard_tb.vcd");
        $dumpvars(0, cpu_hazard_tb);
    end

    // Test program for various hazards
    initial begin
        // Initialize signals
        clk = 0;
        rst = 1;
        
        // Initialize data memory
        for (i = 0; i < MEM_DEPTH; i = i + 1) begin
            data_sram.mem[i] = 32'h0;
        end

        // Apply reset
        #10 rst = 0;
        
        // Run simulation for a fixed time
        #500;
        
        // Display results
        $display("Hazard Tests Results:");
        
        // Test 1: RAW Data Hazards
        $display("\nTest 1: RAW Data Hazards");
        $display("x1 = %0d (Expected: 5)", cpu_inst.registers.registers[1]);
        $display("x2 = %0d (Expected: 10)", cpu_inst.registers.registers[2]);
        $display("x3 = %0d (Expected: 15)", cpu_inst.registers.registers[3]);
        $display("x4 = %0d (Expected: 10)", cpu_inst.registers.registers[4]);
        
        // Test 2: Load-Use Hazard
        $display("\nTest 2: Load-Use Hazard");
        $display("memory[0] = %0d (Expected: 10)", data_sram.mem[0]);
        $display("x5 = %0d (Expected: 10)", cpu_inst.registers.registers[5]);
        $display("x6 = %0d (Expected: 15)", cpu_inst.registers.registers[6]);
        
        // Test 3: Load After Store Hazard
        $display("\nTest 3: Load After Store Hazard");
        $display("x7 = %0d (Expected: 20)", cpu_inst.registers.registers[7]);
        $display("memory[1] = %0d (Expected: 20)", data_sram.mem[1]);
        $display("x8 = %0d (Expected: 20)", cpu_inst.registers.registers[8]);
        
        // Test 4: Store After Load Hazard
        $display("\nTest 4: Store After Load Hazard");
        $display("x9 = %0d (Expected: 10)", cpu_inst.registers.registers[9]);
        $display("memory[2] = %0d (Expected: 10)", data_sram.mem[2]);
        
        // Test 5: Branch Control Hazards
        $display("\nTest 5: Branch Control Hazards");
        $display("x10 = %0d (Expected: 5)", cpu_inst.registers.registers[10]);
        $display("x11 = %0d (Expected: 5)", cpu_inst.registers.registers[11]);
        $display("x12 = %0d (Expected: 0, skipped by branch)", cpu_inst.registers.registers[12]);
        $display("x13 = %0d (Expected: 30)", cpu_inst.registers.registers[13]);
        
        // Test 6: Jump and Link Hazards
        $display("\nTest 6: Jump and Link Hazards");
        $display("x14 = %0d (Expected: PC+4 of jal)", cpu_inst.registers.registers[14]);
        $display("x15 = %0d (Expected: 0, skipped by jump)", cpu_inst.registers.registers[15]);
        $display("x16 = %0d (Expected: 3)", cpu_inst.registers.registers[16]);
        $display("x17 = %0d (Expected: same as x14)", cpu_inst.registers.registers[17]);
        
        $finish;
    end

endmodule 
