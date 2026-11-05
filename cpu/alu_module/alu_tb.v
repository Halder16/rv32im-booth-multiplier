`include "alu.v"
module alu_tb;
    reg clk = 0, rst = 1, start = 0;
    reg [1:0] mode = 0;
    reg [31:0] DATA1 = 0, DATA2 = 0;
    reg [4:0] SELECT = 0;
    wire [31:0] RESULT;
    wire ready, busy;
    alu dut(clk, rst, start, mode, DATA1, DATA2, RESULT, SELECT, ready, busy);
    always #5 clk = ~clk;
    integer checks = 0, i;
    reg [31:0] a, b;
    reg [2:0] variant;
    reg signed [63:0] aa, bb;
    reg [63:0] product;

    task check_mul;
        input [4:0] operation;
        input [31:0] a, b, expected;
        begin
            @(negedge clk);
            SELECT = operation; DATA1 = a; DATA2 = b; mode = 1; start = 1;
            @(negedge clk); start = 0;
            wait (ready); #1;
            if (RESULT !== expected)
                $fatal(1, "ALU op=%b %h * %h: expected %h got %h",
                       operation, a, b, expected, RESULT);
            checks = checks + 1;
            @(negedge clk);
        end
    endtask
    task check_single;
        input [4:0] operation;
        input [31:0] a, b, expected;
        begin
            @(negedge clk);
            SELECT = operation; DATA1 = a; DATA2 = b; mode = 0;
            #1;
            if (RESULT !== expected || ready !== 1 || busy !== 0)
                $fatal(1, "single-cycle ALU regression op=%b", operation);
            checks = checks + 1;
        end
    endtask
    initial begin
        @(negedge clk); rst = 0;
        check_single(`ADD, 5, 10, 15);
        check_single(`SUB, 15, 10, 5);
        check_single(`SLL, 25, 2, 100);
        check_single(`XOR, 10, 5, 15);
        check_single(`SRL, 32, 2, 8);
        check_single(`OR, 12, 5, 13);
        check_single(`AND, 12, 5, 4);
        check_single(`DIV, 32, 2, 16);
        check_single(`REM, 31, 2, 1);
        check_mul(`MULHSU, 1, 32'hffffffff, 0);
        check_mul(`MULHSU, 32'hffffffff, 32'hffffffff, 32'hffffffff);
        check_mul(`MULHSU, 32'h80000000, 32'hffffffff, 32'h80000000);
        check_mul(`MULH, 32'h80000000, 32'h80000000, 32'h40000000);
        check_mul(`MULHU, 32'hffffffff, 32'hffffffff, 32'hfffffffe);
        for (i = 0; i < 2000; i = i + 1) begin
            a = $random; b = $random; variant = i % 4;
            aa = variant == 3 ? {32'd0, a} : {{32{a[31]}}, a};
            bb = variant >= 2 ? {32'd0, b} : {{32{b[31]}}, b};
            product = aa * bb;
            check_mul({variant, 2'b01}, a, b,
                      variant == 0 ? product[31:0] : product[63:32]);
        end
        check_single(`ADD, 40, 2, 42);
        $display("PASS ALU: %0d checks", checks);
        $finish;
    end
    initial begin #200000; $fatal(1, "ALU timeout"); end
endmodule
