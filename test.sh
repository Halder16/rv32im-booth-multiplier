#!/usr/bin/env bash
# One entry point for demos, regressions and throughput measurements.
set -euo pipefail

# Locate the sources and select the tools.
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cpu_dir="$root/cpu"
compiler=${IVERILOG:-iverilog}
runtime=${VVP:-vvp}
viewer=${GTKWAVE:-gtkwave}
compiler_args=()

if [[ -n ${IVERILOG_BASE:-} ]]; then
    compiler_args+=(-B "$IVERILOG_BASE")
fi

wave=0
regression=0
benchmark=0
target=

usage() {
    cat <<'HELP'
Usage: ./test.sh [DEMO | FILE.s] [--wave]
       ./test.sh --regression
       ./test.sh --benchmark

Without arguments, run all four checked demos.
Demos: multiply, signed, arithmetic, memory
  --wave        Save a VCD and open GTKWave (defaults to multiply).
  --regression  Run the full multiplier, ALU and CPU regression suite.
  --benchmark   Measure throughput at a simulated 250 MHz; save CSV results.
  --list        List demos.
  --help        Show this help.

Generated files stay in build/. Assembly uses x0..x30 and decimal immediates.
Optional comments such as '// expect x3 42' check final register values.
HELP
}

# Read command-line options.
for arg in "$@"; do
    case "$arg" in
        --wave)
            wave=1
            ;;

        --regression)
            regression=1
            ;;

        --benchmark)
            benchmark=1
            ;;

        --list)
            printf '%s\n' multiply signed arithmetic memory
            exit 0
            ;;

        --help|-h)
            usage
            exit 0
            ;;

        -*)
            printf 'Unknown option: %s\n' "$arg" >&2
            exit 2
            ;;

        *)
            if [[ -n $target ]]; then
                usage >&2
                exit 2
            fi

            target=$arg
            ;;
    esac
done

# Check dependencies before building anything.
for tool in "$compiler" "$runtime"; do
    if ! command -v "$tool" >/dev/null; then
        printf 'Required tool missing: %s\n' "$tool" >&2
        exit 1
    fi
done

if (( wave )); then
    if ! command -v "$viewer" >/dev/null; then
        echo 'GTKWave is required for --wave.' >&2
        exit 1
    fi
fi

build_dir="$root/build"
mkdir -p "$build_dir"

run_bench() {
    local module_dir=$1
    local top=$2
    local output_dir=${bench_output_dir:-"$build_dir/regression"}

    shift 2

    (
        cd "$cpu_dir/$module_dir"
        "$compiler" "${compiler_args[@]}" -g2012 -s "$top" \
            "$@" -o "$output_dir/$top.vvp"

        cd "$output_dir"
        "$runtime" "$top.vvp"
    )
}

# Keep the performance experiment separate from the correctness regressions.
if (( benchmark )); then
    if (( regression || wave )) || [[ -n $target ]]; then
        echo 'Use --benchmark alone.' >&2
        exit 2
    fi

    bench_output_dir="$build_dir/benchmark"
    mkdir -p "$bench_output_dir"

    {
        "$compiler" "${compiler_args[@]}" -V 2>/dev/null | sed -n '1p'
        echo 'Throughput benchmark: 4 ns clock period (simulated 250 MHz)'
        echo 'Theoretical multiplier ceiling: 1 product/cycle = 250 MMUL/s'
        echo 'Blocking CPU ceiling with ideal caches: 1 product/5 cycles = 50 MMUL/s'
        echo 'These are simulated rates, not synthesized hardware clock limits.'

        run_bench other_modules/multiplier_32_bit mult_32bit_throughput_tb \
            mult_32bit.v mult_32bit_throughput_tb.v

        run_bench cpu_pipeline cpu_throughput_tb cpu_throughput_tb.v \
            -Pcpu_throughput_tb.IDEAL_CACHE=1

        run_bench cpu_pipeline cpu_throughput_tb cpu_throughput_tb.v

        run_bench cpu_pipeline cpu_throughput_tb cpu_throughput_tb.v \
            -Pcpu_throughput_tb.MULTIPLY=0
    } | tee "$bench_output_dir/run.log" | awk '!/^METRIC,/'

    printf '%s\n' 'benchmark,clock_mhz,cycles,instructions,products,ipc,cpi,mips,mmul_s' \
        > "$bench_output_dir/results.csv"
    awk '/^METRIC,/ { sub(/^METRIC,/, ""); print }' \
        "$bench_output_dir/run.log" >> "$bench_output_dir/results.csv"

    printf '\nResults: %s\n' "$bench_output_dir/results.csv"
    exit 0
fi

# The longer suite checks the multiplier, ALU and CPU integration.
if (( regression )); then
    if (( wave )) || [[ -n $target ]]; then
        echo 'Use --regression alone; choose a demo for --wave.' >&2
        exit 2
    fi

    mkdir -p "$build_dir/regression"

    for bench in mult_32bit_tb mult_32bit_timing_tb mult_32bit_pipeline_tb; do
        run_bench other_modules/multiplier_32_bit "$bench" mult_32bit.v "$bench.v"
    done

    run_bench alu_module alu_tb alu_tb.v

    # ideal-cache mode, clock half-period, reset-during-multiply
    for config in '0 2 0' '0 10 0' '1 2 0' '1 10 0' '0 2 1'; do
        read -r ideal half reset <<< "$config"

        run_bench cpu_pipeline cpu_mul_tb cpu_mul_tb.v \
            -Pcpu_mul_tb.IDEAL_CACHE="$ideal" \
            -Pcpu_mul_tb.HALF_PERIOD="$half" \
            -Pcpu_mul_tb.RESET_DURING_MUL="$reset"
    done

    exit 0
fi

# Build the existing assembler and the program testbench once for all demos.
if ! command -v "${CC:-gcc}" >/dev/null; then
    echo 'A C compiler (gcc or CC) is required for the assembler.' >&2
    exit 1
fi

"${CC:-gcc}" "$cpu_dir/assembler/RV32IMAssembler.c" -o "$build_dir/assembler"

(
    cd "$cpu_dir/cpu_pipeline"
    "$compiler" "${compiler_args[@]}" -g2012 -s cpu_program_tb \
        -o "$build_dir/program.vvp" cpu_program_tb.v
)

run_program() {
    local source=$1
    local name work reg value index
    local -a expected
    local -a wave_args=()

    name=$(basename -- "$source" .s)
    work="$build_dir/$name"
    mkdir -p "$work/assemble"

    printf '\nRunning %s\n' "$name"

    # Strip comments/commas and append a reserved completion marker. The existing
    # assembler uses decimal immediates, x-register names and numeric offsets.
    awk '
        {
            sub(/\/\/.*/, "")
            sub(/#.*/, "")
            gsub(/,/, " ")

            if ($0 ~ /[^[:space:]]/) {
                print
            }
        }

        END {
            print "addi x31 x0 123"
        }
    ' "$source" > "$work/program.s"

    (
        cd "$work/assemble"
        "$build_dir/assembler" "$work/program.s"
    )

    # Split each instruction into little-endian bytes, then fill unused memory
    # with NOPs so the simulator never reads uninitialized instruction bytes.
    if ! awk '
        length($0) != 32 || $0 ~ /[^01]/ {
            exit 1
        }

        {
            print substr($0, 25, 8), substr($0, 17, 8),
                  substr($0, 9, 8), substr($0, 1, 8)
            n++
        }

        END {
            if (n > 256) {
                exit 1
            }

            for (; n < 256; n++) {
                print "00010011 00000000 00000000 00000000"
            }
        }
    ' "$work/program.machine" > "$work/instructions.mem"; then
        echo 'Invalid assembler output or program exceeds 1 KiB instruction memory.' >&2
        exit 1
    fi

    # Unspecified registers are ignored by the testbench.
    for ((index = 0; index < 32; index++)); do
        expected[index]=xxxxxxxx
    done

    while read -r reg value; do
        if ! [[ $reg =~ ^x([0-9]|[12][0-9]|30)$ &&
                $value =~ ^(-?[0-9]+|0[xX][0-9a-fA-F]+)$ ]]; then
            echo "Invalid expectation: $reg $value" >&2
            exit 1
        fi

        index=${reg#x}
        printf -v 'expected[index]' '%08x' "$((value & 0xffffffff))"
    done < <(
        awk '
            $1 == "//" && $2 == "expect" {
                print $3, $4
            }
        ' "$source"
    )

    printf '%s\n' "${expected[@]}" > "$work/expected.mem"

    if (( wave )); then
        wave_args+=("+wave=$work/wave.vcd")
    fi

    (
        cd "$work"
        "$runtime" "$build_dir/program.vvp" \
            "+memory=$work/instructions.mem" \
            "+expected=$work/expected.mem" \
            "${wave_args[@]}"
    )

    # Include the pipeline signals and checked registers in the GTKWave view.
    if (( wave )); then
        cat > "$work/wave.gtkw" <<WAVE
[dumpfile] "$work/wave.vcd"
[timestart] 0
@28
cpu_program_tb.clk
cpu_program_tb.rst
cpu_program_tb.cpu.BUSYWAIT
cpu_program_tb.cpu.start_signal
cpu_program_tb.cpu.alu_ready
@22
cpu_program_tb.cpu.PC_OUT[31:0]
cpu_program_tb.cpu.ALUOP_EX[4:0]
cpu_program_tb.cpu.OPERAND1[31:0]
cpu_program_tb.cpu.OPERAND2[31:0]
cpu_program_tb.cpu.ALU_OUT[31:0]
WAVE

        for ((index = 1; index < 31; index++)); do
            if [[ ${expected[index]} != xxxxxxxx ]]; then
                printf 'cpu_program_tb.registers[%d].value[31:0]\n' "$index" >> "$work/wave.gtkw"
            fi
        done

        printf 'Waveform: %s\n' "$work/wave.vcd"
        "$viewer" "$work/wave.vcd" "$work/wave.gtkw"
    fi
}

# Choose the demos, or use the caller's assembly file.
if [[ -z $target ]]; then
    if (( wave )); then
        target=multiply
    else
        target=all
    fi
fi

case "$target" in
    all)
        for demo in multiply signed arithmetic memory; do
            run_program "$root/examples/$demo.s"
        done
        ;;

    multiply|signed|arithmetic|memory)
        run_program "$root/examples/$target.s"
        ;;

    *)
        if [[ ! -f $target || $target != *.s ]]; then
            echo "Unknown demo or missing .s file: $target" >&2
            exit 2
        fi

        source_dir=$(cd -- "$(dirname -- "$target")" && pwd)
        run_program "$source_dir/$(basename -- "$target")"
        ;;
esac
