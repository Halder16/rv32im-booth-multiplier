// Consecutive, dependent multiplies followed by an ordinary addition.
// expect x3 42
// expect x4 294
// expect x5 336
addi x1 x0 6
addi x2 x0 7
mul x3 x1 x2
mul x4 x3 x2
add x5 x4 x3
