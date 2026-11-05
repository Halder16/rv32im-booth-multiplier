// 32x32 Radix-4 Booth multiplier, 3-stage pipeline
// 18 partial products; operands are independently sign/zero extended.
// start may be asserted every cycle. A product and ready emerge at the third
// rising edge including the accepting edge. result holds between valid products.

////////////////////////////////////////////////////////////////////////////////
module sign_extend_32(
    input  [31:0] A,
    input  [31:0] B,
    input  [1:0]  mode,       // 00 = unsigned, 01 = signed, 10 = signed A / unsigned B
    output [34:0] A_s,
    output [34:0] B_s
);
    // Signedness is selected per operand for the RV32M high-half variants.
    wire sign_bit_a = (mode == 2'b01 || mode == 2'b10) && A[31];
    wire sign_bit_b = (mode == 2'b01) && B[31];

    // Extend to 35 bits (3 extra bits of extension)
    assign A_s = { {3{sign_bit_a}}, A };
    assign B_s = { {3{sign_bit_b}}, B };
endmodule

////////////////////////////////////////////////////////////////////////////////
module booth_rad4_35x35_to_pp64(
    input  signed [34:0] A,
    input  signed [34:0] B,
    output signed [63:0] PP0, output signed [63:0] PP1,
    output signed [63:0] PP2, output signed [63:0] PP3,
    output signed [63:0] PP4, output signed [63:0] PP5,
    output signed [63:0] PP6, output signed [63:0] PP7,
    output signed [63:0] PP8, output signed [63:0] PP9,
    output signed [63:0] PP10,output signed [63:0] PP11,
    output signed [63:0] PP12,output signed [63:0] PP13,
    output signed [63:0] PP14,output signed [63:0] PP15,
    output signed [63:0] PP16,output signed [63:0] PP17
);
    // Array to hold outputs (now 18 partial products)
    wire signed [63:0] PPs [0:17];

    // Pre-calculate candidate values
    wire [35:0] pp_plus_a  = {A[34], A};           // +1 * A (36 bits)
    wire [35:0] pp_plus_2a = {A, 1'b0};            // +2 * A (36 bits)

    wire [35:0] pp_min_a   = ~pp_plus_a + 36'd1;   // -1 * A
    wire [35:0] pp_min_2a  = ~pp_plus_2a + 36'd1;  // -2 * A

    genvar i;
    generate
        for (i = 0; i < 18; i = i + 1) begin : booth_slice

            // Determine Window
            wire [2:0] window;
            if (i == 0)
                assign window = {B[1], B[0], 1'b0};
            else if (i == 17)
                assign window = {B[34], B[34], B[33]};
            else
                assign window = {B[2*i+1], B[2*i], B[2*i-1]};

            // Select the correct Partial Product
            reg [35:0] raw_pp;

            always @(*) begin
                case (window)
                    3'b001, 3'b010: raw_pp = pp_plus_a;
                    3'b011:         raw_pp = pp_plus_2a;
                    3'b100:         raw_pp = pp_min_2a;
                    3'b101, 3'b110: raw_pp = pp_min_a;
                    default:        raw_pp = 36'd0;
                endcase
            end

            // Sign Extension & Shifting
            wire pp_sign_bit = raw_pp[35];

            // Extend to 128 bits, then shift
            wire [127:0] extended_pp_matrix;
            assign extended_pp_matrix = { {92{pp_sign_bit}}, raw_pp };

            wire [127:0] shifted_matrix;
            assign shifted_matrix = extended_pp_matrix << (2*i);

            // Final slice to 64 bits
            assign PPs[i] = shifted_matrix[63:0];
        end
    endgenerate

    // Map wires to outputs
    assign PP0  = PPs[0];  assign PP1  = PPs[1];  assign PP2  = PPs[2];  assign PP3  = PPs[3];
    assign PP4  = PPs[4];  assign PP5  = PPs[5];  assign PP6  = PPs[6];  assign PP7  = PPs[7];
    assign PP8  = PPs[8];  assign PP9  = PPs[9];  assign PP10 = PPs[10]; assign PP11 = PPs[11];
    assign PP12 = PPs[12]; assign PP13 = PPs[13]; assign PP14 = PPs[14]; assign PP15 = PPs[15];
    assign PP16 = PPs[16]; assign PP17 = PPs[17];

endmodule

////////////////////////////////////////////////////////////////////////////////
module adder_tree_18to1(
    input  signed [63:0] PP0,  input signed [63:0] PP1,  input signed [63:0] PP2,  input signed [63:0] PP3,
    input  signed [63:0] PP4,  input signed [63:0] PP5,  input signed [63:0] PP6,  input signed [63:0] PP7,
    input  signed [63:0] PP8,  input signed [63:0] PP9,  input signed [63:0] PP10, input signed [63:0] PP11,
    input  signed [63:0] PP12, input signed [63:0] PP13, input signed [63:0] PP14, input signed [63:0] PP15,
    input  signed [63:0] PP16, input signed [63:0] PP17, // Now 18 inputs
    output signed [63:0] SUM
);
    // Balanced pairwise reduction
    // Level 1: 18 -> 9
    wire signed [63:0] L1a = PP0  + PP1;
    wire signed [63:0] L1b = PP2  + PP3;
    wire signed [63:0] L1c = PP4  + PP5;
    wire signed [63:0] L1d = PP6  + PP7;
    wire signed [63:0] L1e = PP8  + PP9;
    wire signed [63:0] L1f = PP10 + PP11;
    wire signed [63:0] L1g = PP12 + PP13;
    wire signed [63:0] L1h = PP14 + PP15;
    wire signed [63:0] L1i = PP16 + PP17;

    // Level 2: 9 -> 5 (pair up 8, carry 1)
    wire signed [63:0] L2a = L1a + L1b;
    wire signed [63:0] L2b = L1c + L1d;
    wire signed [63:0] L2c = L1e + L1f;
    wire signed [63:0] L2d = L1g + L1h;
    wire signed [63:0] L2e = L1i; // Pass through

    // Level 3: 5 -> 3 (pair up 4, carry 1)
    wire signed [63:0] L3a = L2a + L2b;
    wire signed [63:0] L3b = L2c + L2d;
    wire signed [63:0] L3c = L2e; // Pass through

    // Level 4: 3 -> 2
    wire signed [63:0] L4a = L3a + L3b;
    wire signed [63:0] L4b = L3c; // Pass through

    // Level 5: Final sum
    assign SUM = L4a + L4b;
endmodule

////////////////////////////////////////////////////////////////////////////////
module mult_32bit(
    input         clk,
    input         rst,        // active-high reset
    input         start,      // pulse to start capture of A,B
    input  [31:0] A,
    input  [31:0] B,
    input  [1:0]  mode,       // 00 = unsigned, 01 = signed, 10 = signed A / unsigned B
    output signed [63:0] result,
    output        ready,      // 1 when result valid this cycle
    output        busy        // 1 when any stage has data
);
    // pipeline valid shift register
    reg [2:0] valid;
    always @(posedge clk or posedge rst) begin
        if (rst) valid <= 3'b000;
        else    valid <= { valid[1:0], start };
    end
    assign ready = valid[2];
    assign busy  = |valid;

    // Stage0: sign/zero extend (combinational)
    wire [34:0] A_s_in, B_s_in;  // FIXED: Changed to 35 bits
    sign_extend_32 SE0(.A(A), .B(B), .mode(mode), .A_s(A_s_in), .B_s(B_s_in));

    // latch inputs into stage1 only when start pulses
    reg signed [34:0] A_s_r, B_s_r;  // FIXED: Changed to 35 bits
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            A_s_r <= 35'sd0;
            B_s_r <= 35'sd0;
        end else if (start) begin
            A_s_r <= A_s_in;
            B_s_r <= B_s_in;
        end
    end

    // Stage1: Booth (combinational) using registered A_s_r,B_s_r
    wire signed [63:0] PP0, PP1, PP2, PP3, PP4, PP5, PP6, PP7, PP8;
    wire signed [63:0] PP9, PP10, PP11, PP12, PP13, PP14, PP15, PP16, PP17;

    booth_rad4_35x35_to_pp64 BR0(
        .A(A_s_r), .B(B_s_r),
        .PP0(PP0), .PP1(PP1), .PP2(PP2), .PP3(PP3),
        .PP4(PP4), .PP5(PP5), .PP6(PP6), .PP7(PP7),
        .PP8(PP8), .PP9(PP9), .PP10(PP10), .PP11(PP11),
        .PP12(PP12), .PP13(PP13), .PP14(PP14), .PP15(PP15),
        .PP16(PP16), .PP17(PP17)  // FIXED: Added PP17
    );

    // Stage1 -> Stage2 registers
    // FIXED: Increased storage to 18
    reg signed [63:0] RPP[0:17];
    integer j;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (j = 0; j < 18; j = j + 1) RPP[j] <= 64'sd0;
        end else begin
            // capture regardless of start; the valid shift register indicates what's valid
            RPP[0]  <= PP0;  RPP[1]  <= PP1;  RPP[2]  <= PP2;  RPP[3]  <= PP3;
            RPP[4]  <= PP4;  RPP[5]  <= PP5;  RPP[6]  <= PP6;  RPP[7]  <= PP7;
            RPP[8]  <= PP8;  RPP[9]  <= PP9;  RPP[10] <= PP10; RPP[11] <= PP11;
            RPP[12] <= PP12; RPP[13] <= PP13; RPP[14] <= PP14; RPP[15] <= PP15;
            RPP[16] <= PP16; RPP[17] <= PP17; // FIXED: Added PP17
        end
    end

    // Stage2: adder tree (combinational), reduce RPP -> sum
    wire signed [63:0] sum_stage2;
    adder_tree_18to1 AT0(  // FIXED: Changed to 18-input adder tree
        .PP0(RPP[0]),  .PP1(RPP[1]),  .PP2(RPP[2]),  .PP3(RPP[3]),
        .PP4(RPP[4]),  .PP5(RPP[5]),  .PP6(RPP[6]),  .PP7(RPP[7]),
        .PP8(RPP[8]),  .PP9(RPP[9]),  .PP10(RPP[10]),.PP11(RPP[11]),
        .PP12(RPP[12]),.PP13(RPP[13]),.PP14(RPP[14]),.PP15(RPP[15]),
        .PP16(RPP[16]),.PP17(RPP[17]), // FIXED: Added PP17
        .SUM(sum_stage2)
    );

    // Stage2 -> Stage3 register; retain completed products through idle cycles.
    reg signed [63:0] sum_r;
    always @(posedge clk or posedge rst) begin
        if (rst) sum_r <= 64'sd0;
        else if (valid[1]) sum_r <= sum_stage2;
    end

    // Stage3: output (available when valid[2]==1)
    assign result = sum_r;

endmodule
