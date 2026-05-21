module cpu_ooo_benchmark_tb;
    // Clock and reset
    reg clk;
    reg rst;
    integer i;
    integer cycle_count;
    integer finish_cycle;
    reg benchmark_done_reported;

    // Memory interface
    wire [31:0] instr_addr;
    wire [31:0] instruction;
    wire [31:0] data_addr;
    wire [31:0] data_out;
    wire [31:0] data_in;
    wire mem_write;
    wire mem_read;

    localparam INSTR_MEM_DEPTH = 26;
    localparam DATA_MEM_DEPTH = 64;

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
        .DEPTH(INSTR_MEM_DEPTH),
        .INIT_FILE("tb/ooo_benchmark.hex")
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
        .DEPTH(DATA_MEM_DEPTH)
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

    // Count cycles after reset deassertion and report when x20 marks completion.
    initial begin
        cycle_count = 0;
        finish_cycle = -1;
        benchmark_done_reported = 0;
    end

    always @(posedge clk) begin
        if (rst) begin
            cycle_count = 0;
            finish_cycle = -1;
            benchmark_done_reported = 0;
        end else begin
            cycle_count = cycle_count + 1;
            if (cpu_inst.registers.registers[20] == 32'd1 && !benchmark_done_reported) begin
                benchmark_done_reported = 1;
                finish_cycle = cycle_count;
                $display("OoO benchmark finished after %0d clock cycles", cycle_count);
            end
        end
    end

    initial begin
        $dumpfile("cpu_ooo_benchmark_tb.vcd");
        $dumpvars(0, cpu_ooo_benchmark_tb);
    end

    initial begin
        clk = 0;
        rst = 1;

        for (i = 0; i < DATA_MEM_DEPTH; i = i + 1)
            data_sram.mem[i] = 32'h0;

        #10 rst = 0;

        // 2000 loop iterations plus branch penalties can take substantially more than 20k cycles here.
        while (!benchmark_done_reported && cycle_count < 50000)
            @(posedge clk);

        #20;

        if (!benchmark_done_reported)
            $display("OoO benchmark completion not observed before timeout (x20 = %0d)",
                     cpu_inst.registers.registers[20]);

        if (finish_cycle >= 0)
            $display("Total clock cycles after reset deassert: %0d", finish_cycle);
        else
            $display("Total clock cycles after reset deassert: %0d", cycle_count);
        $display("Final checksum at data_mem[0] = %0d (Expected: 60025)", data_sram.mem[0]);
        $display("x20 = %0d (Expected: 1)", cpu_inst.registers.registers[20]);

        if (benchmark_done_reported && data_sram.mem[0] == 32'd60025 && cpu_inst.registers.registers[20] == 32'd1)
            $display("PASS: OoO benchmark completed successfully");
        else
            $display("FAIL: OoO benchmark did not complete as expected");

        $finish;
    end
endmodule
