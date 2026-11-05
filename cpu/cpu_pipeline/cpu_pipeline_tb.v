`include "../data_memory_module/data_memory.v"
`include "../instruction_memory_module/instruction_memory.v"
`include "cpu_pipeline.v"

module cpu_pipeline_tb;

reg RESET, CLK;
wire INST_MEM_READ, DATA_MEM_BUSYWAIT, DATA_MEM_READ, DATA_MEM_WRITE, INST_MEM_BUSYWAIT;
wire [127:0] INST_MEM_READDATA, DATA_MEM_READDATA, DATA_MEM_WRITEDATA;
wire [27:0] INST_MEM_ADDRESS, DATA_MEM_ADDRESS;
    
cpu_pipeline cpu(RESET, CLK, INST_MEM_READDATA, DATA_MEM_READDATA, DATA_MEM_WRITEDATA, INST_MEM_READ, DATA_MEM_BUSYWAIT, DATA_MEM_READ, DATA_MEM_WRITE, INST_MEM_ADDRESS, DATA_MEM_ADDRESS, INST_MEM_BUSYWAIT);

data_memory d_mem(CLK, RESET, DATA_MEM_READ, DATA_MEM_WRITE, DATA_MEM_ADDRESS, DATA_MEM_WRITEDATA, DATA_MEM_READDATA, DATA_MEM_BUSYWAIT);

instruction_memory inst_mem(CLK, INST_MEM_READ, INST_MEM_ADDRESS, INST_MEM_READDATA, INST_MEM_BUSYWAIT);

integer j;

// -------------------- performance counters --------------------
reg [63:0] cycle_count;
reg [63:0] instr_retired_count;

// Optional: set this to the clock frequency you want to use for throughput calculation
real ASSUMED_CLOCK_HZ = 50_000_000.0; // 50 MHz by default
// ---------------------------------------------------------------

initial begin
    $readmemb("../instruction_memory_module/instr_mem.mem", inst_mem.MEM_ARRAY);
    $dumpfile("cpu_pipeline_wavedata.vcd");
    
    // Dump all top-level signals
    $dumpvars(0, cpu_pipeline_tb);
    
    // Dump instruction memory
    for(j = 0; j < 16; j = j + 1) $dumpvars(0, inst_mem.MEM_ARRAY[j]);
    
    // Dump instruction cache
    for(j = 0; j < 8; j = j + 1) $dumpvars(0, cpu.inst_cache.DATA[j]);
    
    // Dump register file module with depth 2 to get all internal signals
    $dumpvars(2, cpu.register_file);
    
    // Explicitly dump ALL 32 registers (x0 through x31) individually
    // This ensures all registers are visible in gtkwave
    // REGISTER[0] = x0, REGISTER[1] = x1, ..., REGISTER[10] = x10, etc.
    // IMPORTANT: Must recompile and rerun simulation after changing this!
    for(j = 0; j < 32; j = j + 1) begin
        $dumpvars(0, cpu.register_file.REGISTER[j]);
    end
    
    // Dump data cache
    for(j = 0; j < 8; j = j + 1) $dumpvars(0, cpu.d_cache.DATA[j]);
    for(j = 0; j < 8; j = j + 1) $dumpvars(0, cpu.d_cache.VALID[j]);
    for(j = 0; j < 8; j = j + 1) $dumpvars(0, cpu.d_cache.TAG[j]);
    for(j = 0; j < 8; j = j + 1) $dumpvars(0, cpu.d_cache.DIRTY[j]);
    
    // Dump data memory for easier debugging
    for(j = 0; j < 32; j = j + 1) $dumpvars(0, d_mem.MEM_ARRAY[j]);

    // initialize counters & signals
    cycle_count = 0;
    instr_retired_count = 0;

    CLK = 1'b0;
    RESET = 1'b0;
    RESET = 1'b1;
    #1;
    RESET = 1'b0;
    
    // run for a fixed number of time units (you can increase if needed)
    #5000;
    
    // final performance report
    $display("\n==========================================");
    $display("  CPU Pipeline Simulation Results");
    $display("==========================================");
    $display("\nPerformance summary:");
    $display("  Cycles elapsed           : %0d", cycle_count);
    $display("  Instructions retired     : %0d", instr_retired_count);

    if (instr_retired_count == 0) begin
        $display("  CPI / IPC cannot be computed (no instructions retired).");
    end else begin : perf_calc_block
        real r_cycles;
        real r_instrs;
        real CPI;
        real IPC;
        real throughput;

        r_cycles = $itor(cycle_count);
        r_instrs = $itor(instr_retired_count);

        CPI = r_cycles / r_instrs;
        IPC = r_instrs / r_cycles;
        throughput = (ASSUMED_CLOCK_HZ / CPI);  // instructions per second

        $display("  CPI (cycles per instruction)       : %0.6f", CPI);
        $display("  IPC (instructions per cycle)       : %0.6f", IPC);
        $display("  Theoretical throughput @ %0.0f Hz  : %0.3f instr/sec",
                ASSUMED_CLOCK_HZ, throughput);
    end


    $display("\nFinal Register Values (Non-Zero):");
    $display("Register     Name       Value (Dec)    Value (Hex)");
    $display("--------------------------------------------------");
    
    // Check each register and display if non-zero
    for(j = 0; j < 32; j = j + 1) begin
        if(cpu.register_file.REGISTER[j] != 0) begin
            if(j == 0) $display("REGISTER[%2d]   x0 (zero)  %-15d 0x%08X", j, cpu.register_file.REGISTER[j], cpu.register_file.REGISTER[j]);
            else if(j == 1) $display("REGISTER[%2d]   x1 (ra)    %-15d 0x%08X", j, cpu.register_file.REGISTER[j], cpu.register_file.REGISTER[j]);
            else if(j == 2) $display("REGISTER[%2d]   x2 (sp)    %-15d 0x%08X", j, cpu.register_file.REGISTER[j], cpu.register_file.REGISTER[j]);
            else if(j == 3) $display("REGISTER[%2d]   x3 (gp)    %-15d 0x%08X", j, cpu.register_file.REGISTER[j], cpu.register_file.REGISTER[j]);
            else if(j == 4) $display("REGISTER[%2d]   x4 (tp)    %-15d 0x%08X", j, cpu.register_file.REGISTER[j], cpu.register_file.REGISTER[j]);
            else if(j == 5) $display("REGISTER[%2d]   x5 (t0)    %-15d 0x%08X", j, cpu.register_file.REGISTER[j], cpu.register_file.REGISTER[j]);
            else if(j == 6) $display("REGISTER[%2d]   x6 (t1)    %-15d 0x%08X", j, cpu.register_file.REGISTER[j], cpu.register_file.REGISTER[j]);
            else if(j == 7) $display("REGISTER[%2d]   x7 (t2)    %-15d 0x%08X", j, cpu.register_file.REGISTER[j], cpu.register_file.REGISTER[j]);
            else if(j == 8) $display("REGISTER[%2d]   x8 (s0)    %-15d 0x%08X", j, cpu.register_file.REGISTER[j], cpu.register_file.REGISTER[j]);
            else if(j == 9) $display("REGISTER[%2d]   x9 (s1)    %-15d 0x%08X", j, cpu.register_file.REGISTER[j], cpu.register_file.REGISTER[j]);
            else if(j == 10) $display("REGISTER[%2d]   x10 (a0)   %-15d 0x%08X", j, cpu.register_file.REGISTER[j], cpu.register_file.REGISTER[j]);
            else if(j == 11) $display("REGISTER[%2d]   x11 (a1)   %-15d 0x%08X", j, cpu.register_file.REGISTER[j], cpu.register_file.REGISTER[j]);
            else if(j == 12) $display("REGISTER[%2d]   x12 (a2)   %-15d 0x%08X", j, cpu.register_file.REGISTER[j], cpu.register_file.REGISTER[j]);
            else if(j == 13) $display("REGISTER[%2d]   x13 (a3)   %-15d 0x%08X", j, cpu.register_file.REGISTER[j], cpu.register_file.REGISTER[j]);
            else if(j == 14) $display("REGISTER[%2d]   x14 (a4)   %-15d 0x%08X", j, cpu.register_file.REGISTER[j], cpu.register_file.REGISTER[j]);
            else if(j == 15) $display("REGISTER[%2d]   x15 (a5)   %-15d 0x%08X", j, cpu.register_file.REGISTER[j], cpu.register_file.REGISTER[j]);
            else if(j == 16) $display("REGISTER[%2d]   x16 (a6)   %-15d 0x%08X", j, cpu.register_file.REGISTER[j], cpu.register_file.REGISTER[j]);
            else if(j == 17) $display("REGISTER[%2d]   x17 (a7)   %-15d 0x%08X", j, cpu.register_file.REGISTER[j], cpu.register_file.REGISTER[j]);
            else if(j == 18) $display("REGISTER[%2d]   x18 (s2)   %-15d 0x%08X", j, cpu.register_file.REGISTER[j], cpu.register_file.REGISTER[j]);
            else if(j == 19) $display("REGISTER[%2d]   x19 (s3)   %-15d 0x%08X", j, cpu.register_file.REGISTER[j], cpu.register_file.REGISTER[j]);
            else if(j == 20) $display("REGISTER[%2d]   x20 (s4)   %-15d 0x%08X", j, cpu.register_file.REGISTER[j], cpu.register_file.REGISTER[j]);
            else if(j == 21) $display("REGISTER[%2d]   x21 (s5)   %-15d 0x%08X", j, cpu.register_file.REGISTER[j], cpu.register_file.REGISTER[j]);
            else if(j == 22) $display("REGISTER[%2d]   x22 (s6)   %-15d 0x%08X", j, cpu.register_file.REGISTER[j], cpu.register_file.REGISTER[j]);
            else if(j == 23) $display("REGISTER[%2d]   x23 (s7)   %-15d 0x%08X", j, cpu.register_file.REGISTER[j], cpu.register_file.REGISTER[j]);
            else if(j == 24) $display("REGISTER[%2d]   x24 (s8)   %-15d 0x%08X", j, cpu.register_file.REGISTER[j], cpu.register_file.REGISTER[j]);
            else if(j == 25) $display("REGISTER[%2d]   x25 (s9)   %-15d 0x%08X", j, cpu.register_file.REGISTER[j], cpu.register_file.REGISTER[j]);
            else if(j == 26) $display("REGISTER[%2d]   x26 (s10)  %-15d 0x%08X", j, cpu.register_file.REGISTER[j], cpu.register_file.REGISTER[j]);
            else if(j == 27) $display("REGISTER[%2d]   x27 (s11)  %-15d 0x%08X", j, cpu.register_file.REGISTER[j], cpu.register_file.REGISTER[j]);
            else if(j == 28) $display("REGISTER[%2d]   x28 (t3)   %-15d 0x%08X", j, cpu.register_file.REGISTER[j], cpu.register_file.REGISTER[j]);
            else if(j == 29) $display("REGISTER[%2d]   x29 (t4)   %-15d 0x%08X", j, cpu.register_file.REGISTER[j], cpu.register_file.REGISTER[j]);
            else if(j == 30) $display("REGISTER[%2d]   x30 (t5)   %-15d 0x%08X", j, cpu.register_file.REGISTER[j], cpu.register_file.REGISTER[j]);
            else if(j == 31) $display("REGISTER[%2d]   x31 (t6)   %-15d 0x%08X", j, cpu.register_file.REGISTER[j], cpu.register_file.REGISTER[j]);
            else $display("REGISTER[%2d]   x%-2d       %-15d 0x%08X", j, j, cpu.register_file.REGISTER[j], cpu.register_file.REGISTER[j]);
        end
    end
    
    // $display("--------------------------------------------------");
    // $display("Note: x10 (a0) is typically used for return values");
    $display("==========================================\n");
    
    $finish;
    
end

// clock genaration.
always begin
    #2 CLK = ~CLK;
end

// -------------- counters: cycles and retired instructions --------------
always @(posedge CLK) begin
    if (RESET) begin
        cycle_count <= 0;
        instr_retired_count <= 0;
    end else begin
        cycle_count <= cycle_count + 1;
        // count retirement when WB asserts register write enable
        // cpu.REG_WRITE_EN_WB is the wire coming out of the CPU's WB stage
        if (cpu.REG_WRITE_EN_WB) instr_retired_count <= instr_retired_count + 1;
    end
end
// ----------------------------------------------------------------------

endmodule
