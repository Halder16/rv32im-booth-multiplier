`timescale 1ns/1ps

module mult_32bit_tb;

    reg clk, rst, start;
    reg [31:0] A, B;
    reg [1:0] mode;  // ADDED: mode signal (0 = unsigned, 1 = signed)
    wire busy, ready;
    wire [63:0] result;

    // DUT
    mult_32bit dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .A(A),
        .B(B),
        .mode(mode),  // ADDED: connect mode signal
        .busy(busy),
        .ready(ready),
        .result(result)
    );

    // Clock generator
    always #5 clk = ~clk;

    integer i;
    integer pass_count, fail_count;

    // CPU-style multiply task
    task cpu_mul;
        input [31:0] a;
        input [31:0] b;
        input [63:0] exp;
        input [1:0] m;  // mode parameter
        input [8*40:1] test_name;  // test description
        begin
            @(negedge clk);
            A = a;
            B = b;
            mode = m;
            start = 1;

            @(negedge clk);
            start = 0;

            // wait for busy
            wait(busy == 1);

            // wait for ready
            wait(ready == 1);

            #1;
            if (result === exp) begin
                $display("PASS: %s | %0d * %0d = %0d (mode=%s)",
                         test_name, a, b, result, m == 2 ? "mixed" : m == 1 ? "signed" : "unsigned");
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL: %s | %0d * %0d | Expected %0d, Got %0d (mode=%s)",
                         test_name, a, b, exp, result, m == 2 ? "mixed" : m == 1 ? "signed" : "unsigned");
                fail_count = fail_count + 1;
            end

            @(posedge clk);
        end
    endtask

    // Helper function to compute expected signed result
    function [63:0] signed_mul;
        input [31:0] a;
        input [31:0] b;
        reg signed [31:0] a_s;
        reg signed [31:0] b_s;
        reg signed [63:0] result_s;
        begin
            a_s = a;  // Treat input bits as signed
            b_s = b;  // Treat input bits as signed
            result_s = a_s * b_s;  // Signed multiplication
            signed_mul = result_s;  // Return as 64-bit value
        end
    endfunction

    // Helper function to compute expected unsigned result
    function [63:0] unsigned_mul;
        input [31:0] a;
        input [31:0] b;
        reg [63:0] temp;
        begin
            temp = a;
            unsigned_mul = temp * b;
        end
    endfunction


    initial begin
        clk = 0;
        rst = 1;
        start = 0;
        A = 0;
        B = 0;
        mode = 0;
        pass_count = 0;
        fail_count = 0;

        @(posedge clk);
        @(posedge clk);
        @(negedge clk);
        rst = 0;

        $display("\n========================================");
        $display("  COMPREHENSIVE MULTIPLIER TESTBENCH");
        $display("========================================\n");

        // ===== UNSIGNED MULTIPLICATION TESTS =====
        $display("--- UNSIGNED MULTIPLICATION TESTS ---");

        // Basic small numbers
        cpu_mul(5, 6, unsigned_mul(5, 6), 0, "Basic: 5*6");
        cpu_mul(123, 7, unsigned_mul(123, 7), 0, "Basic: 123*7");
        cpu_mul(15, 15, unsigned_mul(15, 15), 0, "Basic: 15*15");
        cpu_mul(100, 100, unsigned_mul(100, 100), 0, "Basic: 100*100");

        // Edge cases with zero
        cpu_mul(0, 0, unsigned_mul(0, 0), 0, "Zero: 0*0");
        cpu_mul(0, 999, unsigned_mul(0, 999), 0, "Zero: 0*999");
        cpu_mul(999, 0, unsigned_mul(999, 0), 0, "Zero: 999*0");
        cpu_mul(32'hFFFFFFFF, 0, unsigned_mul(32'hFFFFFFFF, 0), 0, "Zero: MAX*0");

        // Edge cases with one
        cpu_mul(1, 1, unsigned_mul(1, 1), 0, "One: 1*1");
        cpu_mul(1, 32'hFFFFFFFF, unsigned_mul(1, 32'hFFFFFFFF), 0, "One: 1*MAX");
        cpu_mul(32'hFFFFFFFF, 1, unsigned_mul(32'hFFFFFFFF, 1), 0, "One: MAX*1");

        // Powers of two
        cpu_mul(2, 2, unsigned_mul(2, 2), 0, "Power2: 2*2");
        cpu_mul(16, 16, unsigned_mul(16, 16), 0, "Power2: 16*16");
        cpu_mul(256, 256, unsigned_mul(256, 256), 0, "Power2: 256*256");
        cpu_mul(32'h80000000, 2, unsigned_mul(32'h80000000, 2), 0, "Power2: 2^31*2");
        cpu_mul(32'h40000000, 4, unsigned_mul(32'h40000000, 4), 0, "Power2: 2^30*4");

        // Maximum values
        cpu_mul(32'hFFFFFFFF, 2, unsigned_mul(32'hFFFFFFFF, 2), 0, "Max: MAX*2");
        cpu_mul(32'hFFFFFFFF, 32'hFFFFFFFF, unsigned_mul(32'hFFFFFFFF, 32'hFFFFFFFF), 0, "Max: MAX*MAX");
        cpu_mul(32'hFFFFFFFF, 32'h00000002, unsigned_mul(32'hFFFFFFFF, 32'h00000002), 0, "Max: MAX*2");

        // Bit patterns
        cpu_mul(32'h00FF00FF, 32'h00010001, unsigned_mul(32'h00FF00FF, 32'h00010001), 0, "Pattern: 0x00FF00FF*0x00010001");
        cpu_mul(32'hAAAAAAAA, 32'h55555555, unsigned_mul(32'hAAAAAAAA, 32'h55555555), 0, "Pattern: 0xAAAAAAAA*0x55555555");
        cpu_mul(32'h12345678, 32'h9ABCDEF0, unsigned_mul(32'h12345678, 32'h9ABCDEF0), 0, "Pattern: 0x12345678*0x9ABCDEF0");
        cpu_mul(32'hF0F0F0F0, 32'h0F0F0F0F, unsigned_mul(32'hF0F0F0F0, 32'h0F0F0F0F), 0, "Pattern: 0xF0F0F0F0*0x0F0F0F0F");

        // Large numbers
        cpu_mul(32'h7FFFFFFF, 32'h7FFFFFFF, unsigned_mul(32'h7FFFFFFF, 32'h7FFFFFFF), 0, "Large: 2^31-1 * 2^31-1");
        cpu_mul(32'hFFFFFFFE, 32'hFFFFFFFE, unsigned_mul(32'hFFFFFFFE, 32'hFFFFFFFE), 0, "Large: (MAX-1)*(MAX-1)");
        cpu_mul(1000000, 1000000, unsigned_mul(1000000, 1000000), 0, "Large: 1M*1M");

        $display("\n--- SIGNED MULTIPLICATION TESTS ---");

        // Basic positive numbers
        cpu_mul(32'd5, 32'd6, signed_mul(32'd5, 32'd6), 1, "Signed+: 5*6");
        cpu_mul(32'd123, 32'd7, signed_mul(32'd123, 32'd7), 1, "Signed+: 123*7");
        cpu_mul(32'd100, 32'd100, signed_mul(32'd100, 32'd100), 1, "Signed+: 100*100");

        // Negative * Positive (use 2's complement representation)
        cpu_mul(32'hFFFFFFFB, 32'd6, signed_mul(32'hFFFFFFFB, 32'd6), 1, "Signed-+: -5*6");
        cpu_mul(32'hFFFFFF85, 32'd7, signed_mul(32'hFFFFFF85, 32'd7), 1, "Signed-+: -123*7");
        cpu_mul(32'hFFFFFFFF, 32'd100, signed_mul(32'hFFFFFFFF, 32'd100), 1, "Signed-+: -1*100");

        // Positive * Negative (use 2's complement representation)
        cpu_mul(32'd5, 32'hFFFFFFFA, signed_mul(32'd5, 32'hFFFFFFFA), 1, "Signed+-: 5*-6");
        cpu_mul(32'd123, 32'hFFFFFFF9, signed_mul(32'd123, 32'hFFFFFFF9), 1, "Signed+-: 123*-7");
        cpu_mul(32'd100, 32'hFFFFFFFF, signed_mul(32'd100, 32'hFFFFFFFF), 1, "Signed+-: 100*-1");

        // Negative * Negative (use 2's complement representation)
        cpu_mul(32'hFFFFFFFB, 32'hFFFFFFFA, signed_mul(32'hFFFFFFFB, 32'hFFFFFFFA), 1, "Signed--: -5*-6");
        cpu_mul(32'hFFFFFF85, 32'hFFFFFFF9, signed_mul(32'hFFFFFF85, 32'hFFFFFFF9), 1, "Signed--: -123*-7");
        cpu_mul(32'hFFFFFF9C, 32'hFFFFFF9C, signed_mul(32'hFFFFFF9C, 32'hFFFFFF9C), 1, "Signed--: -100*-100");

        // Edge cases with -1
        cpu_mul(32'hFFFFFFFF, 32'hFFFFFFFF, signed_mul(32'hFFFFFFFF, 32'hFFFFFFFF), 1, "Signed: -1*-1");
        cpu_mul(32'hFFFFFFFF, 32'd1, signed_mul(32'hFFFFFFFF, 32'd1), 1, "Signed: -1*1");
        cpu_mul(32'h7FFFFFFF, 32'hFFFFFFFF, signed_mul(32'h7FFFFFFF, 32'hFFFFFFFF), 1, "Signed: MAX_POS*-1");
        cpu_mul(32'h80000000, 32'hFFFFFFFF, signed_mul(32'h80000000, 32'hFFFFFFFF), 1, "Signed: MIN_NEG*-1");

        // Maximum positive signed value
        cpu_mul(32'h7FFFFFFF, 32'd2, signed_mul(32'h7FFFFFFF, 32'd2), 1, "Signed: MAX_POS*2");
        cpu_mul(32'h7FFFFFFF, 32'h7FFFFFFF, signed_mul(32'h7FFFFFFF, 32'h7FFFFFFF), 1, "Signed: MAX_POS*MAX_POS");

        // Minimum negative signed value
        cpu_mul(32'h80000000, 32'd2, signed_mul(32'h80000000, 32'd2), 1, "Signed: MIN_NEG*2");
        cpu_mul(32'h80000000, 32'hFFFFFFFE, signed_mul(32'h80000000, 32'hFFFFFFFE), 1, "Signed: MIN_NEG*-2");
        cpu_mul(32'h80000000, 32'h80000000, signed_mul(32'h80000000, 32'h80000000), 1, "Signed: MIN_NEG*MIN_NEG");

        // Mixed sign patterns (-1000 = 0xFFFFFC18, 1000 = 0x3E8)
        cpu_mul(32'hFFFFFC18, 32'd1000, signed_mul(32'hFFFFFC18, 32'd1000), 1, "Signed: -1000*1000");
        cpu_mul(32'd1000, 32'hFFFFFC18, signed_mul(32'd1000, 32'hFFFFFC18), 1, "Signed: 1000*-1000");
        cpu_mul(32'hFFFFFC18, 32'hFFFFFC18, signed_mul(32'hFFFFFC18, 32'hFFFFFC18), 1, "Signed: -1000*-1000");

        // Mixed signed A / unsigned B (MULHSU).
        cpu_mul(32'd1, 32'hFFFFFFFF, 64'h00000000FFFFFFFF, 2, "Mixed: 1*UINT_MAX");
        cpu_mul(32'hFFFFFFFF, 32'hFFFFFFFF, 64'hFFFFFFFF00000001, 2, "Mixed: -1*UINT_MAX");
        cpu_mul(32'h80000000, 32'hFFFFFFFF, 64'h8000000080000000, 2, "Mixed: MIN_NEG*UINT_MAX");

        $display("\n========================================");
        $display("  TEST SUMMARY");
        $display("========================================");
        $display("  PASSED: %0d", pass_count);
        $display("  FAILED: %0d", fail_count);
        $display("  TOTAL:  %0d", pass_count + fail_count);
        $display("========================================\n");

        if (fail_count == 0)
            $display("*** ALL TESTS PASSED! ***\n");
        else
            $display("*** SOME TESTS FAILED ***\n");

        if (fail_count != 0) $fatal(1, "Multiplier tests failed");
        $finish;
    end

endmodule
