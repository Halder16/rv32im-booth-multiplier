`timescale 1ns/1ps
module mult_32bit_timing_tb;
    reg clk = 0, rst = 1, start = 0;
    reg [31:0] A = 0, B = 0;
    wire [63:0] result;
    wire ready, busy;
    mult_32bit dut(clk, rst, start, A, B, 2'b00, result, ready, busy);
    always #10 clk = ~clk;
    initial begin
        @(negedge clk); rst = 0;
        @(negedge clk); A = 6; B = 7; start = 1;
        @(posedge clk); #1;
        if (ready || !busy) $fatal(1, "incorrect accepting-edge handshake");
        @(negedge clk); start = 0;
        @(posedge clk); #1;
        if (ready || !busy) $fatal(1, "product ready too early");
        @(posedge clk); #1;
        if (!ready || result !== 64'd42) $fatal(1, "third-edge result missing");
        @(posedge clk); #1;
        if (ready || busy || result !== 64'd42) $fatal(1, "idle result not retained");
        // Reset must cancel an in-flight product.
        @(negedge clk); start = 1;
        @(posedge clk); #1; rst = 1;
        #1;
        if (ready || busy || result !== 0) $fatal(1, "reset did not clear pipeline");
        @(negedge clk); start = 0; rst = 0;
        repeat (4) begin
            @(posedge clk); #1;
            if (ready || busy) $fatal(1, "cancelled product reappeared");
        end
        $display("PASS multiplier timing, idle hold, and reset cancellation");
        $finish;
    end
    initial begin #1000; $fatal(1, "multiplier timing timeout"); end
endmodule
