// Signed, unsigned and mixed high-half multiplication.
// expect x4 -6
// expect x5 -1
// expect x6 5
// expect x7 0xfffffffe
// expect x8 0x40000000
addi x1 x0 -1
addi x2 x0 1
slli x2 x2 31
addi x3 x0 6
mul x4 x1 x3
mulh x5 x1 x3
mulhsu x6 x3 x1
mulhu x7 x1 x1
mulh x8 x2 x2
