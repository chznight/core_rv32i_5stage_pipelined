module cpu_tb;
    // Clock and reset
    reg clk;
    reg rst;
    // Memory interface
    wire [31:0] instr_addr;
    wire [31:0] instruction;
    wire [31:0] data_addr;
    wire [31:0] data_out;
    wire [31:0] data_in;
    wire mem_write;
    wire mem_read;

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
        .mem_read(mem_read)
    );
    // One dual-port SRAM presents a unified memory image to the CPU.
    bsram #(
        .DATA_WIDTH(32),
        .DEPTH(2048),
        .INIT_FILE("tb/cpu_tb.hex")
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

    initial begin
        $dumpfile("cpu_tb.vcd");
        $dumpvars(0, cpu_tb);
    end
    // Test program
    initial begin
        // Initialize signals
        clk = 0;
        rst = 1;
        
        // Apply reset
        #10 rst = 0;
        
        // Run simulation for a fixed time
        #300;
        
        // Display results
        $display("Register file contents after execution:");
        $display("x1 = %d (Expected: 10)", cpu_inst.registers.registers[1]);
        $display("x2 = %d (Expected: 20)", cpu_inst.registers.registers[2]);
        $display("x3 = %d (Expected: 30)", cpu_inst.registers.registers[3]);
        $display("x4 = %d (Expected: 10)", cpu_inst.registers.registers[4]);
        $display("x5 = %d (Expected: 30)", cpu_inst.registers.registers[5]);
        $display("x6 = %d (Expected: 0, skipped by branch)", cpu_inst.registers.registers[6]);
        $display("x7 = %d (Expected: 7)", cpu_inst.registers.registers[7]);
        
        $display("Data memory location 0 = %d (Expected: 30)", block_sram.mem[DATA_BASE_WORD]);
        
        $finish;
    end

endmodule 
