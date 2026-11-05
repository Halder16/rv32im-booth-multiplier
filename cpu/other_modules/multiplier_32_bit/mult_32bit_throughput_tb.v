`timescale 1ns/1ps
// Measure the multiplier alone with one checked transaction per clock.
module mult_32bit_throughput_tb;
    parameter PRODUCTS = 256;
    localparam real CLOCK_PERIOD_NS = 4.0;
    localparam real CLOCK_MHZ = 1000.0 / CLOCK_PERIOD_NS;
    reg clk = 0, rst = 1, start = 0;
    reg [31:0] A = 0, B = 7;
    wire [63:0] result;
    wire ready, busy;
    mult_32bit dut(clk, rst, start, A, B, 2'b00, result, ready, busy);
    always #(CLOCK_PERIOD_NS / 2.0) clk = ~clk;

    integer i, completed = 0, first_result = -1, last_result = -1;
    reg [63:0] expected;
    real batch_rate, steady_rate, started_at;
    initial begin
        if (PRODUCTS < 2) $fatal(1, "at least two products are required");
        @(negedge clk); rst = 0;
        for (i = 0; i < PRODUCTS + 2; i = i + 1) begin
            @(negedge clk);
            if (i == 0) started_at = $realtime;
            start = i < PRODUCTS;
            A = i + 1;
            @(posedge clk); #0.001;
            if (ready !== (i >= 2)) $fatal(1, "unexpected ready at cycle %0d", i);
            if (ready) begin
                expected = i - 1;
                expected = expected * 7;
                if (result !== expected) $fatal(1, "incorrect streaming product");
                if (first_result < 0) first_result = i;
                last_result = i;
                completed = completed + 1;
            end
        end
        // Close the last full clock slot before computing the batch rate.
        @(negedge clk);
        start = 0;
        if (($realtime - started_at) != (PRODUCTS + 2) * CLOCK_PERIOD_NS)
            $fatal(1, "batch cycle/time mismatch");
        if (completed != PRODUCTS || last_result - first_result != PRODUCTS - 1)
            $fatal(1, "stream did not sustain one result per cycle");

        // Inclusive batch: accepting edge #1 through the final ready edge.
        // Steady interval: results after the first, divided by elapsed cycles.
        batch_rate = completed * CLOCK_MHZ / (PRODUCTS + 2);
        steady_rate = (completed - 1.0) * CLOCK_MHZ / (last_result - first_result);
        $display("Multiplier: %0d checked products in %0d cycles; steady II = 1 cycle",
                 completed, PRODUCTS + 2);
        $display("  Batch: %0.6f MMUL/s; steady: %0.6f MMUL/s", batch_rate, steady_rate);
        $display("METRIC,multiplier_batch,%0.3f,%0d,0,%0d,NA,NA,NA,%0.6f",
                 CLOCK_MHZ, PRODUCTS + 2, completed, batch_rate);
        $display("METRIC,multiplier_steady,%0.3f,%0d,0,%0d,NA,NA,NA,%0.6f",
                 CLOCK_MHZ, last_result - first_result, completed - 1, steady_rate);
        $finish;
    end
    initial begin #100000; $fatal(1, "multiplier benchmark timeout"); end
endmodule
