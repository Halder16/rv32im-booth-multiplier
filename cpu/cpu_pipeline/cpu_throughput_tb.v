`timescale 1ns/1ps
// Fixed straight-line workload: two setup instructions, OPERATIONS adds or
// multiplies, then one completion marker. Every instruction writes a register.
// Count unique WB PCs as a check; never count held register-write enables as
// extra instructions. Cold-cache timing includes startup, misses and drain.
`include "cpu_pipeline.v"
`include "../instruction_memory_module/instruction_memory.v"
`include "../data_memory_module/data_memory.v"
module cpu_throughput_tb;
    parameter OPERATIONS = 64;
    parameter MULTIPLY = 1;
    parameter IDEAL_CACHE = 0;
    localparam INSTRUCTIONS = OPERATIONS + 3;
    localparam real CLOCK_PERIOD_NS = 4.0;
    localparam real CLOCK_MHZ = 1000.0 / CLOCK_PERIOD_NS;

    reg clk = 0, rst = 0;
    wire ir, dr, dw, ib, db;
    wire [127:0] idata, ddata, wdata;
    wire [27:0] ia, da;
    cpu_pipeline cpu(rst, clk, idata, ddata, wdata, ir, db, dr, dw, ia, da, ib);
    instruction_memory im(clk, ir, ia, idata, ib);
    data_memory dm(clk, rst, dr, dw, da, wdata, ddata, db);
    always #(CLOCK_PERIOD_NS / 2.0) clk = ~clk;

    reg [31:0] program_words [0:255];
    reg seen [0:255];
    integer i, wb_index, cycles = 0, instructions_seen = 0;
    integer launches = 0, products = 0, first_launch = -1, last_launch = -1;
    real ipc, cpi, mips, mmul_s, issue_interval, started_at, ended_at;
    reg [255:0] label;
    wire [31:0] ideal_instruction = cpu.PC_OUT < 1024 ?
                                  program_words[cpu.PC_OUT[9:2]] : 32'h13;
    generate if (IDEAL_CACHE) begin
        initial begin
            force cpu.INSTRUCTION = ideal_instruction;
            force cpu.INST_BUSYWAIT = 1'b0;
            force cpu.DATA_BUSYWAIT = 1'b0;
        end
    end endgenerate

    always @(posedge clk) begin
        if (rst) begin
            cycles = 0;
            launches = 0;
            first_launch = -1;
            last_launch = -1;
        end else begin
            cycles = cycles + 1;
            if (cpu.start_signal) begin
                if (first_launch < 0) first_launch = cycles;
                last_launch = cycles;
                launches = launches + 1;
            end
        end
    end

    // Sample after all original #1 register/memory delays have settled.
    always @(negedge clk) begin
        if (!rst) begin
            if (cpu.PC_4_WB_OUT_WB >= 4 &&
                cpu.PC_4_WB_OUT_WB <= INSTRUCTIONS * 4) begin
                wb_index = (cpu.PC_4_WB_OUT_WB / 4) - 1;
                if (!seen[wb_index]) begin
                    seen[wb_index] = 1;
                    instructions_seen = instructions_seen + 1;
                end
            end
            if (cpu.alu_unit.MUL0.ready) begin
                if (cpu.alu_unit.MUL0.result !== 64'd42)
                    $fatal(1, "incorrect benchmark product");
                products = products + 1;
            end
        end
    end

    initial begin
        if (OPERATIONS < 2 || INSTRUCTIONS > 256) $fatal(1, "invalid workload size");
        for (i = 0; i < 256; i = i + 1) begin
            program_words[i] = 32'h13;
            seen[i] = 0;
        end
        program_words[0] = 32'h00600093; // addi x1,x0,6
        program_words[1] = 32'h00700113; // addi x2,x0,7
        for (i = 0; i < OPERATIONS; i = i + 1)
            program_words[i + 2] = MULTIPLY ? 32'h022081b3 : 32'h002081b3;
        program_words[INSTRUCTIONS - 1] = 32'h07b00f93; // addi x31,x0,123
        for (i = 0; i < 256; i = i + 1) begin
            im.MEM_ARRAY[4*i] = program_words[i][7:0];
            im.MEM_ARRAY[4*i+1] = program_words[i][15:8];
            im.MEM_ARRAY[4*i+2] = program_words[i][23:16];
            im.MEM_ARRAY[4*i+3] = program_words[i][31:24];
        end
        #1 rst = 1;
        repeat (2) @(negedge clk);
        rst = 0;
        started_at = $realtime;
        wait (cpu.register_file.REGISTER[31] === 32'd123);
        @(negedge clk);
        ended_at = $realtime;
        #0.001;
        if ((ended_at - started_at) != cycles * CLOCK_PERIOD_NS)
            $fatal(1, "CPU cycle/time mismatch");
        if (instructions_seen != INSTRUCTIONS)
            $fatal(1, "expected %0d unique WB instructions, saw %0d",
                   INSTRUCTIONS, instructions_seen);
        if (cpu.register_file.REGISTER[3] !== (MULTIPLY ? 32'd42 : 32'd13))
            $fatal(1, "incorrect final benchmark result");
        if (launches != (MULTIPLY ? OPERATIONS : 0) || products != launches)
            $fatal(1, "multiply launch/completion count mismatch");

        ipc = (1.0 * INSTRUCTIONS) / cycles;
        cpi = (1.0 * cycles) / INSTRUCTIONS;
        mips = ipc * CLOCK_MHZ;
        mmul_s = products * CLOCK_MHZ / cycles;
        if (MULTIPLY) label = IDEAL_CACHE ? "cpu_mul_ideal" : "cpu_mul_cold";
        else label = IDEAL_CACHE ? "cpu_add_ideal" : "cpu_add_cold";
        $display("%0s: %0d instructions, %0d products, %0d cycles", label,
                 instructions_seen, products, cycles);
        $display("  IPC %0.6f; CPI %0.6f; %0.6f MIPS; %0.6f MMUL/s", ipc, cpi, mips, mmul_s);
        $display("  Simulated duration: %0.3f us", (ended_at - started_at) / 1000.0);
        $display("METRIC,%0s,%0.3f,%0d,%0d,%0d,%0.6f,%0.6f,%0.6f,%0.6f",
                 label, CLOCK_MHZ, cycles, instructions_seen, products, ipc, cpi, mips, mmul_s);
        if (MULTIPLY) begin
            issue_interval = (last_launch - first_launch) / (launches - 1.0);
            $display("%0s mean launch interval: %0.6f cycles/product", label, issue_interval);
            if (IDEAL_CACHE) begin
                if (last_launch - first_launch != 5 * (launches - 1))
                    $fatal(1, "blocking-controller issue interval changed");
                $display("  Ideal-cache steady throughput: %0.6f MMUL/s",
                         (launches - 1.0) * CLOCK_MHZ / (last_launch - first_launch));
                $display("METRIC,cpu_mul_ideal_steady,%0.3f,%0d,0,%0d,NA,NA,NA,%0.6f",
                         CLOCK_MHZ, last_launch - first_launch, launches - 1,
                         (launches - 1.0) * CLOCK_MHZ / (last_launch - first_launch));
            end
        end
        $finish;
    end
    initial begin #100000; $fatal(1, "CPU throughput benchmark timeout"); end
endmodule
