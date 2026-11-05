# Three-stage multiplier

`mult_32bit` accepts `A`, `B`, and `mode` on each rising edge with `start=1`.
It can accept consecutive transactions. Inputs must be stable before that edge.

| mode | A | B | CPU operation |
| --- | --- | --- | --- |
| `00` | unsigned | unsigned | MULHU |
| `01` | signed | signed | MUL, MULH |
| `10` | signed | unsigned | MULHSU |

The low 32 product bits are identical for signed and unsigned multiplication.
The mode port is now two bits; previous scalar 0/1 modes retain their meanings.

The three registered stages capture operands, capture Booth partial products,
and capture their sum. `ready` accompanies the product at the third rising edge,
including the accepting edge. `busy` means any pipeline stage contains a valid
transaction, including the output stage. `result` holds its last valid value
between transactions. Active-high asynchronous `rst` cancels all transactions.

The CPU uses this unit as a blocking EX operation: it holds the pipeline before
launch, launches once per instruction, remembers completion across cache stalls,
and then advances. It does not schedule multiple CPU multiplies concurrently.
Launch is prepared on the falling edge because the original cache model changes
its wait signal on rising edges. The integration also preserves the edge's MUL
stall decision for the original PC/register-file modules that check enables after
`#1`. Those original modules have not been changed.

Run from the repository root with Icarus Verilog 11 or later:

```bash
./test.sh --regression
```

The suite checks directed and randomized signedness cases, pipeline latency,
consecutive launches, idle result retention, reset cancellation, ALU selection,
and CPU forwarding/store/load behavior with real caches, forced cache stalls,
two clock periods, and reset during execution. Simulation failures return a
nonzero status. Build artifacts go into a temporary directory.

`IVERILOG` and `VVP` may select simulator executables; `IVERILOG_BASE` optionally
supplies Icarus's `-B` runtime directory for a locally unpacked installation.
