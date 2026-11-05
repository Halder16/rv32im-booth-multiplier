`timescale 1ns/1ps
// Run assembly demos with the real CPU, instruction/data caches and memories.
`include "cpu_pipeline.v"
`include "../instruction_memory_module/instruction_memory.v"
`include "../data_memory_module/data_memory.v"
module cpu_program_tb;
    reg clk = 0, rst = 0;
    wire ir, dr, dw, ib, db;
    wire [127:0] idata, ddata, wdata;
    wire [27:0] ia, da;
    cpu_pipeline cpu(rst, clk, idata, ddata, wdata, ir, db, dr, dw, ia, da, ib);
    instruction_memory im(clk, ir, ia, idata, ib);
    data_memory dm(clk, rst, dr, dw, da, wdata, ddata, db);
    always #2 clk = ~clk;

    // Named wire aliases avoid simulator warnings when dumping memory words.
    genvar r;
    generate for (r = 0; r < 32; r = r + 1) begin : registers
        wire [31:0] value = cpu.register_file.REGISTER[r];
    end endgenerate

    reg [31:0] expected [0:31];
    reg [4095:0] memory_file, expected_file, waveform_file;
    integer i, checks = 0, cycles = 0;
    always @(posedge clk) if (!rst) cycles <= cycles + 1;
    initial begin
        if (!$value$plusargs("memory=%s", memory_file) ||
            !$value$plusargs("expected=%s", expected_file))
            $fatal(1, "missing memory/expected files");
        $readmemb(memory_file, im.MEM_ARRAY);
        $readmemh(expected_file, expected);
        if ($value$plusargs("wave=%s", waveform_file)) begin
            $dumpfile(waveform_file);
            $dumpvars(0, cpu_program_tb);
        end
        #1 rst = 1;
        repeat (2) @(negedge clk);
        rst = 0;
        // test.sh appends this completion marker; demos need no infinite loop.
        wait (cpu.register_file.REGISTER[31] === 32'd123);
        repeat (4) @(negedge clk);
        for (i = 0; i < 31; i = i + 1) begin
            if (expected[i] !== 32'hxxxxxxxx) begin
                if (cpu.register_file.REGISTER[i] !== expected[i])
                    $fatal(1, "x%0d: expected 0x%08h, got 0x%08h", i,
                           expected[i], cpu.register_file.REGISTER[i]);
                $display("  x%0d = %0d (0x%08h)", i,
                         $signed(cpu.register_file.REGISTER[i]),
                         cpu.register_file.REGISTER[i]);
                checks = checks + 1;
            end
        end
        if (checks == 0) begin
            for (i = 1; i < 31; i = i + 1)
                if (cpu.register_file.REGISTER[i] !== 0)
                    $display("  x%0d = %0d (0x%08h)", i,
                             $signed(cpu.register_file.REGISTER[i]),
                             cpu.register_file.REGISTER[i]);
            $display("Completed in %0d cycles (no expected values supplied)", cycles);
        end else $display("PASS: %0d register checks, %0d cycles", checks, cycles);
        $finish;
    end
    initial begin #100000; $fatal(1, "program timed out before completion marker"); end
endmodule
