`include "../other_modules/multiplier_32_bit/mult_32bit.v"
`include "../utils/encodings.v"

module alu(clk, rst, start, mode, DATA1, DATA2, RESULT, SELECT, ready, busy);

    // port declaration

    input clk, rst;
    input start; //start signal for multi-cycle ops
    input [1:0] mode; //mode select (00: normal ALU, 01: mul)

    input [31:0] DATA1, DATA2;
    input [4:0] SELECT;     // func3: 3bits + func7[0] + func7[5]

    output reg [31:0] RESULT;
    output ready;     // goes high when RESULT is valid
    output busy;     // high during MUL / multi-cycle operations

    // alu intermediate results
    wire [31:0] ADD_RESULT,
                SLT_RESULT,
                SLTU_RESULT,
                AND_RESULT,
                OR_RESULT,
                XOR_RESULT,
                SLL_RESULT,
                SRL_RESULT,
                SUB_RESULT,
                SRA_RESULT,
                MUL_RESULT,
                MULHU_RESULT,
                MULHSU_RESULT,
                DIV_RESULT,
                DIVU_RESULT,
                REM_RESULT,
                REMU_RESULT;

    wire [31:0] MULH_RESULT;

    // ---------------- MULTIPLIER INSTANCE --------------------
    wire [63:0] mul_res64; //64 bit multiply result
    wire mul_ready, mul_busy; //ready, busy signals for multiplier

    mult_32bit MUL0 (
        .clk(clk),
        .rst(rst),
        .start(start & (mode == 2'b01)),  // only start when MUL requested
        .A(DATA1),
        .B(DATA2),
        .mode(SELECT == `MULHSU ? 2'b10 :
              SELECT == `MULHU  ? 2'b00 : 2'b01),
        .result(mul_res64),
        .ready(mul_ready),
        .busy(mul_busy)
    );

    //these signals only apply for multiply, for now
    //(maybe more when more pipelined operators are added?)
    assign busy  = mul_busy;
    assign ready = (mode == 2'b01) ? mul_ready : 1'b1;

    //  --> should add proper delays
    assign  ADD_RESULT = DATA1 + DATA2;       // addition
    assign  SUB_RESULT = DATA1 - DATA2;       // Subtraction

    assign  SLT_RESULT = ($signed(DATA1) < $signed(DATA2)) ? 1'b1 : 1'b0;         // set less than
    assign  SLTU_RESULT = ($unsigned(DATA1) < $unsigned(DATA2)) ? 1'b1 : 1'b0;    // set less than unsigned

    assign  AND_RESULT = DATA1 & DATA2;       // bitwise logical AND
    assign  OR_RESULT = DATA1 | DATA2;        // bitwise logical OR
    assign  XOR_RESULT = DATA1 ^ DATA2;       // bitwise logical XOR
    assign  SLL_RESULT = DATA1 << DATA2;      // Logical Left Shift
    assign  SRL_RESULT = DATA1 >> DATA2;      // Logical Right Shift
    assign  SRA_RESULT = DATA1 >>> DATA2;     // Arithmetic Right shift

    // --> upper 32 bit

    // The CPU holds SELECT and operands until this product is acknowledged.
    assign  MUL_RESULT = mul_res64[31:0]; //DATA1 * DATA2;       // Multiplication
    assign  MULH_RESULT = mul_res64[63:32]; //DATA1 * DATA2;      // Multiplication High Signed x Signed
    assign  MULHU_RESULT = mul_res64[63:32]; //$unsigned(DATA1) * $unsigned(DATA2);     // Multiplication High Unsigned x Unsigned
    assign  MULHSU_RESULT = mul_res64[63:32]; //$signed(DATA1) * $unsigned(DATA2);     // Multiplication High Signed x UnSigned

    // DIV --> should round towards zero
    assign  DIV_RESULT = DATA1 / DATA2;                           // Division
    assign  DIVU_RESULT = $unsigned(DATA1) / $unsigned(DATA2);    // Division Unsigned
    assign  REM_RESULT = DATA1 % DATA2;       // Remainder
    assign  REMU_RESULT = DATA1 % DATA2;      // Remainder Unsigned

    always @(*)
    begin
        case(SELECT)
            `ADD: RESULT = ADD_RESULT;
            `SUB: RESULT = SUB_RESULT;
            `SLL: RESULT = SLL_RESULT;
            `SLT: RESULT = SLT_RESULT;
            `SLTU: RESULT = SLTU_RESULT;
            `XOR: RESULT = XOR_RESULT;
            `SRL: RESULT = SRL_RESULT;
            `SRA: RESULT = SRA_RESULT;
            `OR: RESULT = OR_RESULT;
            `AND: RESULT = AND_RESULT;
            `MUL: RESULT = MUL_RESULT;
            `MULH: RESULT = MULH_RESULT;
            `MULHSU: RESULT = MULHSU_RESULT;
            `MULHU: RESULT = MULHU_RESULT;
            `DIV: RESULT = DIV_RESULT;
            `DIVU: RESULT = DIVU_RESULT;
            `REM : RESULT = REM_RESULT;
            `REMU: RESULT = REMU_RESULT;

            default:  RESULT = 0 ;

        endcase
    end

endmodule

//removed the delays like #2 to make it "synthesizable"
