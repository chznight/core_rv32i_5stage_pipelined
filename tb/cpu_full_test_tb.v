module cpu_full_test_tb;
    reg clk;
    reg rst;
    integer i;
    integer pass_count;
    integer fail_count;

    wire [31:0] instr_addr;
    wire [31:0] instruction;
    wire [31:0] data_addr;
    wire [31:0] data_out;
    wire [31:0] data_in;
    wire mem_write;
    wire mem_read;
    wire [3:0] byte_enable;

    localparam DATA_BASE_WORD = 256;

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
        .INIT_FILE("tb/full_instruction_test.hex")
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

    always begin
        #5 clk = ~clk;
    end

    initial begin
        $dumpfile("cpu_full_test_tb.vcd");
        $dumpvars(0, cpu_full_test_tb);
    end

    task check_reg;
        input [255:0] name;
        input [4:0] reg_num;
        input [31:0] expected;
        begin
            if (cpu_inst.registers.registers[reg_num] === expected) begin
                $display("PASS: %0s (x%0d) = %0d", name, reg_num, expected);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL: %0s (x%0d) = %0d, got %0d", name, reg_num, expected, cpu_inst.registers.registers[reg_num]);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task check_mem;
        input [255:0] name;
        input [31:0] addr;
        input [31:0] expected;
        begin
            if (block_sram.mem[DATA_BASE_WORD + addr[31:2]] === expected) begin
                $display("PASS: %0s Mem[%0d] = %0d", name, addr, expected);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL: %0s Mem[%0d] = %0d, got %0d", name, addr, expected, block_sram.mem[DATA_BASE_WORD + addr[31:2]]);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        clk = 0;
        rst = 1;
        pass_count = 0;
        fail_count = 0;

        // Apply reset
        #10 rst = 0;
        #4000;

        $display("\n========================================");
        $display("  Full Instruction Set Test Results");
        $display("========================================\n");

        $display("--- R-type Instructions (10) ---");
        check_reg("ADD  x4",  4,  32'd265);
        check_reg("SUB  x5",  5,  32'd245);
        check_reg("AND  x6",  6,  32'd10);
        check_reg("OR   x7",  7,  32'd255);
        check_reg("XOR  x8",  8,  32'd245);
        check_reg("SLL  x9",  9,  32'd2040);
        check_reg("SRL  x11", 11, 32'd63);
        check_reg("SRA  x12", 12, 32'hFFFFFFFF);
        check_reg("SLT  x13", 13, 32'd1);
        check_reg("SLTU x14", 14, 32'd1);

        $display("\n--- I-type ALU Instructions (9) ---");
        check_reg("ADDI  x16", 16, 32'd17);
        check_reg("ANDI  x17", 17, 32'd15);
        check_reg("ORI   x18", 18, 32'd42);
        check_reg("XORI  x19", 19, 32'd0);
        check_reg("SLTI  x20", 20, 32'd1);
        check_reg("SLTIU x21", 21, 32'd0);
        check_reg("SLLI  x22", 22, 32'd4080);
        check_reg("SRLI  x23", 23, 32'd15);
        check_reg("SRAI  x24", 24, 32'hFFFFFFFF);

        $display("\n--- Memory Instructions (SW, LW) ---");
        check_reg("LW x26", 26, 32'd265);
        check_reg("LW x27", 27, 32'd245);
        check_mem("SW Mem[0]", 32'h0, 32'd265);
        check_mem("SW Mem[4]", 32'h4, 32'd245);

        $display("\n--- Upper Immediate Instructions (LUI, AUIPC) ---");
        check_reg("LUI   x28", 28, 32'd4096);
        // auipc x29, 4096 at addr=128: x29 = 128 + 4096 = 4224
        check_reg("AUIPC x29", 29, 32'd4224);

        $display("\n--- Branch Instructions (6) ---");
        // 1+2+4+8+16+32+64+128+0+256+512+1024 = 2047
        check_reg("BRANCH x30", 30, 32'd2047);

        $display("\n--- Jump Instructions (JAL, JALR) ---");
        // JAL at idx=69 (addr=276): x31 = 276+4 = 280
        // Then JALR at idx=73 (addr=292) overwrites x31 = 292+4 = 296
        check_reg("JALR x31", 31, 32'd296);
        // Verify JALR jumped correctly (skipped instr should not execute)
        check_reg("JALR skip (x30)", 30, 32'd2047);

        $display("\n========================================");
        $display("  Summary: %0d PASSED, %0d FAILED", pass_count, fail_count);
        $display("========================================\n");

        if (fail_count == 0)
            $display("ALL TESTS PASSED!");
        else
            $display("SOME TESTS FAILED - review output above");

        $finish;
    end

endmodule
