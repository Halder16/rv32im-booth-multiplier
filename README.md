# Three-stage Booth multiplier for a pipelined RISC-V CPU

This project was part of my coursework for **Computer Architecture and
Organisation**. In it, I wrote a three-stage Radix-4 Booth multiplier and integrated
it into an existing five-stage RV32IM CPU written in Verilog.

The original CPU already supported multiplication through Verilog's built-in `*`
operator. My work replaces that multiply path with an explicit pipelined Booth
multiplier, including partial-product generation, an adder tree, and the control
needed to hold the CPU pipeline while a multiplication completes.

It handles `MUL`, `MULH`, `MULHSU` and `MULHU`, covering the low product and the
signed, unsigned and mixed-sign high products. The multiplier itself can accept
new inputs every cycle. The current CPU integration runs one multiplication at a
time and stalls the pipeline until its result is available.

## Acknowledgments

Thanks to **Buddhi Perera, Shirly Madushanka, Damsy De Silva and the original
Group 1 contributors** for their
[five-stage RISC-V CPU implementation](https://github.com/cepdnaclk/e16-co502-RV32IM-pipeline-implementation-group1),
which this project builds on. Their CPU and assembler gave me a starting point
for the multiplier work. The original Git history and source credits are retained;
[ATTRIBUTION.md](ATTRIBUTION.md) records the upstream project and contributor names.

## Running it

You need Icarus Verilog 11 or later (`iverilog` and `vvp`) and GCC. Install GTKWave
as well if you want to view the waveforms. From the repository root:

```bash
./test.sh                       # Run all four demos and check the results
./test.sh multiply              # Consecutive multiplies, including a dependency
./test.sh signed                # Signed, unsigned and mixed high products
./test.sh arithmetic            # Arithmetic, logic, shifts and comparisons
./test.sh memory                # Stores and loads through the data cache
./test.sh multiply --wave       # Open the multiplication waveform in GTKWave
./test.sh --regression          # Run the more detailed regression suite
./test.sh --benchmark           # Reproduce the throughput measurements below
```

The demos print their result registers and check them against expected values.
The regression suite also checks randomized products, pipeline timing, reset,
forwarding, consecutive multiplies and completion during cache stalls.

Build files stay in `build/`, which is ignored by Git and can be deleted whenever
you want. With `--wave`, that directory also contains the VCD and a saved GTKWave
view with the clock, pipeline control, operands, result and expected registers.

## Throughput

To reproduce these numbers, run:

```bash
./test.sh --benchmark
```

This uses a **4 ns simulated clock period (250 MHz)**. These are measured RTL
simulation rates, not a measured FPGA clock frequency or a synthesis result.
The simulator's wall-clock execution time is not used. The script saves the raw
counts and rates in `build/benchmark/results.csv`, with a full log alongside it.

The theoretical steady-state multiplier throughput is **one product per cycle**:
`250 MHz × 1 = 250 MMUL/s`. Its three stages add latency, but can overlap different
multiplications. The current blocking CPU controller has a best-case issue
interval of **five cycles**, so its multiply ceiling with cache waits bypassed is
`250 MHz ÷ 5 = 50 MMUL/s`. The benchmark verifies both intervals.

Here are the measured finite-workload results at that simulated clock, using
Icarus Verilog 13.0:

| Workload | Cycles | IPC | CPI | MIPS | MMUL/s |
| --- | ---: | ---: | ---: | ---: | ---: |
| Multiplier alone, 256 streamed products | 258 | — | — | — | 248.062 |
| CPU, 64 multiplies, cache waits bypassed | 328 | 0.204268 | 4.895522 | 51.067 | 48.780 |
| CPU, 64 multiplies, real cold caches | 3,308 | 0.020254 | 49.373134 | 5.063 | 4.837 |
| CPU, 64 additions, real cold caches | 2,988 | 0.022423 | 44.597015 | 5.606 | 0 |

**MIPS** means millions of instructions per simulated second; **MMUL/s** means
millions of completed 32-bit × 32-bit products per simulated second. IPC is
instructions per cycle, and CPI is cycles per instruction. The rates are computed
as `MIPS = IPC × clock_MHz` and `MMUL/s = products × clock_MHz / cycles`.

Each CPU workload has 67 instructions: two operand initializations, 64 operations,
and one completion marker. Its window runs from reset release through marker
writeback, including initial fetch, pipeline fill/drain and any cache waits. The
bench checks all 67 distinct writeback PCs, the final register result, and every
multiply launch and product. It does not count a held write-enable signal as
another completed instruction.

The standalone multiplier's 258-cycle batch includes the pipeline fill/drain;
its measured steady output rate is **250 MMUL/s**. The cache-bypassed CPU's steady
multiply rate is **50 MMUL/s**. Its finite batch is slightly slower because of
startup and drain. Its overall MIPS also counts the three non-multiply
instructions, which is why that figure can exceed 50 while MMUL/s stays below it.

The cold-cache numbers are lower because instruction fetching dominates this
small workload. The current memory model reads a 16-byte cache line in 16
sequential 40 ns byte accesses: 640 ns, or 160 of these clock cycles, before cache
controller overhead. The cache-bypassed run isolates the CPU/multiplier handshake;
it is not a warmed-cache measurement. These results describe the present design,
not a before/after speedup over the original Verilog `*` implementation.

The experiments live in
[`mult_32bit_throughput_tb.v`](cpu/other_modules/multiplier_32_bit/mult_32bit_throughput_tb.v)
and [`cpu_throughput_tb.v`](cpu/cpu_pipeline/cpu_throughput_tb.v).

## Trying another program

The examples are short assembly programs. You can edit one or supply your own:

```bash
./test.sh path-to-program.s --wave
```

Use `x0`–`x30`, decimal immediates and numeric branch offsets. Commas, blank lines,
`//` comments and `#` comments are accepted. The project assembler does not handle
labels or ABI register aliases. Its `lui`/`auipc` operands use the full shifted
value, rather than the usual 20-bit operand; the supplied demos use shifts instead.

Expected register values go in comments, for example:

```asm
// expect x3 42
addi x1 x0 6
addi x2 x0 7
mul x3 x1 x2
```

Expectations can be decimal, negative decimal or hexadecimal. Without them, the
runner prints the nonzero registers without checking expected results.

Let a program fall through when it finishes. The runner appends a completion
marker using **x31**, so keep that register free. An infinite loop will time out.
Instruction memory has room for 256 instructions, including the marker.

## Where things are

- `cpu/` contains the CPU, multiplier, assembler and Verilog testbenches.
- `examples/` contains the four runnable assembly demos.
- `examples/reference/` keeps my earlier C experiments and [future-work notes](examples/reference/TODO.md).
- `test.sh` assembles programs, runs the simulator and optionally opens GTKWave.

There are more details about the multiplier's modes and timing in its
[interface notes](cpu/other_modules/multiplier_32_bit/README.md).

## What I would like to do next

I would like `test.sh` to accept a `.c` or `.cpp` file, compile it for this CPU and
run it directly. That path is not implemented yet: the current runner accepts
assembly through the project assembler. The C files in `examples/reference/` are
kept as starting points, rather than working demos.

Other ideas include checking the CPU against a reference instruction-set model,
adding loop and branch demos, and measuring area and clock frequency after
synthesis. The [TODO list](examples/reference/TODO.md) has a little more detail.

For custom tool locations, the runner accepts `IVERILOG`, `VVP`, `CC` and `GTKWAVE`.
`IVERILOG_BASE` can supply Icarus's `-B` library directory.
