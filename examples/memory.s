// Store results into the data cache, load them and add them.
// expect x3 42
// expect x5 42
// expect x6 9
// expect x7 51
// expect x8 51
addi x1 x0 25
addi x2 x0 17
add x3 x1 x2
sw x3 0(x0)
addi x4 x0 9
sw x4 4(x0)
lw x5 0(x0)
lw x6 4(x0)
nop
nop
nop
nop
add x7 x5 x6
sw x7 8(x0)
lw x8 8(x0)
