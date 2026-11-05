`timescale 1ns/1ps
// Scoreboard every accepted transaction, including bubbles and mode changes.
module mult_32bit_pipeline_tb;
    reg clk = 0, rst = 1, start = 0;
    reg [1:0] mode = 0;
    reg [31:0] A = 0, B = 0;
    wire [63:0] result;
    wire ready, busy;
    mult_32bit dut(clk, rst, start, A, B, mode, result, ready, busy);
    always #5 clk = ~clk;
    reg [63:0] expected [0:10002];
    reg valid [0:10002];
    reg signed [63:0] aa, bb;
    integer i, checks = 0;
    initial begin
        @(negedge clk); rst = 0;
        for (i = 0; i < 10003; i = i + 1) begin
            @(negedge clk);
            A = $random; B = $random; mode = i % 3;
            start = (i < 10000) && (($random & 3) != 0);
            aa = mode != 0 ? {{32{A[31]}}, A} : {32'd0, A};
            bb = mode == 1 ? {{32{B[31]}}, B} : {32'd0, B};
            expected[i] = aa * bb;
            valid[i] = start;
            @(posedge clk); #1;
            if (i >= 2) begin
                if (ready !== valid[i-2]) $fatal(1, "valid mismatch at cycle %0d", i);
                if (ready) begin
                    checks = checks + 1;
                    if (result !== expected[i-2])
                        $fatal(1, "cycle %0d: result %h != %h", i, result, expected[i-2]);
                end
            end
        end
        $display("PASS streaming: %0d signed/unsigned/mixed products", checks);
        $finish;
    end
    initial begin #110000; $fatal(1, "streaming multiplier timeout"); end
endmodule
