# Things I would like to add

## Run C and C++ programs directly

- [ ] Let `test.sh` take a `.c` or `.cpp` file, compile it into RISC-V machine code,
      load that code into the simulated memories, and run it on this CPU.

This is what I originally wanted the C experiments in this directory to lead to.
At present, the script cannot take a normal compiler output and run it directly.
The earlier assembly-cleaning scripts were not a reliable way to bridge that gap.

The issue is not that existing compilers cannot generate RISC-V code. GCC and
Clang can target RISC-V, but the generated program needs to match the CPU's
supported instructions, ABI and memory layout. An ELF executable also needs to
be converted or loaded into the simulation correctly. CMake could coordinate
that build, but it is a build tool, not the compiler itself.

Before adding this option, I would like to:

- [ ] Set up a bare-metal RV32IM toolchain and ILP32 ABI, with no compressed or
      other unsupported instruction extensions.
- [ ] Add startup code and a linker script to set the entry point, stack pointer,
      code/data addresses, initialized data and zero-initialized data.
- [ ] Load the compiled code and data into the simulated memories without going
      through the custom assembly parser.
- [ ] Compare compiler-generated instructions against the CPU's actual behavior
      and fix any instruction, forwarding or memory-access mismatches found.
- [ ] Define how a program reports its result and signals completion. Keep the
      existing x31 marker specific to the assembly demos; compiled programs may
      legitimately use that register.
- [ ] Start with small freestanding C functions, then add a limited C++ path.
      Standard-library calls, allocation, exceptions and other runtime features
      will need an explicit support plan.
- [ ] Turn the multiply and matrix experiments here into checked, runnable demos.

Useful references: [GCC's RISC-V target options](https://gcc.gnu.org/onlinedocs/gcc/RISC-V-Options.html),
[RISC-V toolchain conventions](https://github.com/riscv-non-isa/riscv-toolchain-conventions),
and [CMake's role in a build](https://cmake.org/about/).

## Other future work

- [ ] Add branch/loop demos, such as a running sum, factorial and matrix multiply.
- [ ] Compare CPU register and memory results with a reference instruction-set
      model, especially around signed arithmetic and load/store corner cases.
- [ ] Add a synthesis flow and measure multiplier area, critical path and clock
      frequency alongside its cycle latency.
- [ ] Explore letting independent CPU instructions continue while a multiply is
      in flight. This will need dependency tracking and result/writeback control.
- [ ] Run the demos and regressions automatically on GitHub for new commits.
