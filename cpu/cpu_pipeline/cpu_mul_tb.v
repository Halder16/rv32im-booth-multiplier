// Multiply integration regression. Run through ./test.sh --regression.
`include "cpu_pipeline.v"
`include "../instruction_memory_module/instruction_memory.v"
`include "../data_memory_module/data_memory.v"
module cpu_mul_tb;
    parameter IDEAL_CACHE = 0;
    parameter HALF_PERIOD = 2;
    parameter RESET_DURING_MUL = 0;
    reg clk = 0, rst = 0;
    wire ir, dr, dw, ib, db;
    wire [127:0] idata, ddata, wdata;
    wire [27:0] ia, da;
    cpu_pipeline cpu(rst, clk, idata, ddata, wdata, ir, db, dr, dw, ia, da, ib);
    instruction_memory im(clk, ir, ia, idata, ib);
    data_memory dm(clk, rst, dr, dw, da, wdata, ddata, db);
    always #HALF_PERIOD clk = ~clk;

    reg [31:0] program_words [0:255];
    integer i, count = 0, launches = 0;
    reg cache_hold = 0;
    wire [31:0] ideal_instruction = cpu.PC_OUT < 1024 ?
                                  program_words[cpu.PC_OUT[9:2]] : 32'h13;
    generate if (IDEAL_CACHE) begin
        initial begin
            force cpu.INSTRUCTION = ideal_instruction;
            force cpu.INST_BUSYWAIT = cache_hold;
            force cpu.DATA_BUSYWAIT = 1'b0;
        end
        // Keep a completed product waiting after the multiplier's ready pulse
        // disappears. It must neither be lost nor launched again.
        initial begin
            wait (!rst && cpu.mul_inflight);
            wait (cpu.alu_ready);
            @(negedge clk); cache_hold = 1;
            repeat (8) @(negedge clk);
            if (!cpu.mul_done) $fatal(1, "completion lost during cache stall");
            cache_hold = 0;
        end
    end endgenerate

    always @(posedge clk) begin
        if (rst) launches <= 0;
        else if (cpu.start_signal) launches <= launches + 1;
    end

    task emit;
        input [31:0] instruction;
        begin program_words[count] = instruction; count = count + 1; end
    endtask
    function [31:0] mul_op;
        input [2:0] funct3;
        input [4:0] rd, rs1, rs2;
        begin mul_op = {7'b0000001, rs2, rs1, funct3, rd, 7'b0110011}; end
    endfunction
    task check_reg;
        input integer address;
        input [31:0] expected;
        begin
            if (cpu.register_file.REGISTER[address] !== expected)
                $fatal(1, "x%0d expected %h, got %h", address, expected,
                       cpu.register_file.REGISTER[address]);
        end
    endtask

    initial begin
        for (i = 0; i < 256; i = i + 1) program_words[i] = 32'h13;
        emit(32'h00600093); // x1 = 6
        emit(32'h00700113); // x2 = 7
        emit(32'hfff00513); // x10 = -1
        emit(32'h800005b7); // x11 = INT_MIN
        emit(32'h00200693); // x13 = 2
        repeat (6) emit(32'h13);
        emit(mul_op(0, 3, 1, 2));    // 42
        emit(mul_op(0, 4, 3, 2));    // 294, dependent consecutive MUL
        if (!IDEAL_CACHE) emit(32'h00402023); // immediately store MUL result
        emit(mul_op(1, 6, 10, 13));  // signed high(-1 * 2)
        emit(32'h003202b3);           // add x5,x4,x3 = 336
        emit(mul_op(2, 7, 10, 10));  // mixed high(-1 * UINT_MAX)
        emit(mul_op(2, 8, 1, 10));   // mixed high(6 * UINT_MAX) = 5
        emit(mul_op(3, 9, 10, 10));  // unsigned high(UINT_MAX^2)
        emit(mul_op(0, 14, 11, 10)); // low(INT_MIN * -1)
        emit(mul_op(1, 15, 11, 10)); // high(INT_MIN * -1)
        emit(mul_op(1, 16, 11, 11)); // high(INT_MIN^2)
        emit(mul_op(3, 17, 11, 13)); // unsigned high(0x80000000 * 2)
        repeat (4) emit(32'h13);
        if (!IDEAL_CACHE) begin
            emit(32'h00002983); // lw x19,0(x0)
            repeat (4) emit(32'h13);
        end
        emit(32'h07b00f93); // x31 = 123, completion sentinel
        for (i = 0; i < 256; i = i + 1) begin
            im.MEM_ARRAY[4*i] = program_words[i][7:0];
            im.MEM_ARRAY[4*i+1] = program_words[i][15:8];
            im.MEM_ARRAY[4*i+2] = program_words[i][23:16];
            im.MEM_ARRAY[4*i+3] = program_words[i][31:24];
        end
        #1 rst = 1;
        repeat (2) @(negedge clk);
        rst = 0;
        if (RESET_DURING_MUL) begin
            wait (cpu.mul_inflight);
            @(negedge clk); rst = 1;
            repeat (2) @(negedge clk);
            rst = 0;
        end
        wait (cpu.register_file.REGISTER[31] === 32'd123);
        repeat (4) @(negedge clk);
        if (launches != 10) $fatal(1, "expected 10 launches, got %0d", launches);
        check_reg(3, 42); check_reg(4, 294); check_reg(5, 336);
        check_reg(6, 32'hffffffff); check_reg(7, 32'hffffffff);
        check_reg(8, 5); check_reg(9, 32'hfffffffe);
        check_reg(14, 32'h80000000); check_reg(15, 0);
        check_reg(16, 32'h40000000); check_reg(17, 1);
        if (!IDEAL_CACHE) check_reg(19, 294);
        $display("PASS CPU multiply: ideal=%0d half_period=%0d reset=%0d",
                 IDEAL_CACHE, HALF_PERIOD, RESET_DURING_MUL);
        $finish;
    end
    initial begin #100000; $fatal(1, "CPU multiply timeout"); end
endmodule
