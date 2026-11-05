module data_cache(CLK, RESET, BUSYWAIT, READ_WRITE, WRITEDATA, READDATA, ADDRESS, MEM_BUSYWAIT, MEM_READ, MEM_WRITE, MEM_READDATA, MEM_WRITEDATA, MEM_ADDRESS);

//port declaration
input CLK, RESET, MEM_BUSYWAIT;
input [3:0] READ_WRITE;
input [31:0] WRITEDATA, ADDRESS;
input [127:0] MEM_READDATA;

output reg [27:0] MEM_ADDRESS;
output reg [127:0] MEM_WRITEDATA;
output reg [31:0] READDATA;
output reg BUSYWAIT, MEM_READ, MEM_WRITE;

//create reg arrays in the cache
// 16 blocks with 16 bytes (128 bits) in each block
reg [127:0] DATA [0:15];    // byte 0 at [7:0], byte 15 at [127:120]
reg [23:0] TAG [0:15];
reg DIRTY [0:15];
reg VALID [0:15];

// integers used in write operations (declared at module scope for Verilog-2001 compatibility)
integer byte_pos;
integer idx0, idx1, byte_pos0, byte_pos1;
integer idx_base, bp0, bp1, bp2, bp3;

//set busywait if READ_WRITE[3] signal is 1
always @ (READ_WRITE)
begin
    if (READ_WRITE[3]) 
        BUSYWAIT = 1;
    else
        BUSYWAIT = 0;
end

//wires to store the extracted values depending on the index part of the address
wire VALID_OUT, DIRTY_OUT;
wire [127:0] DATA_OUT; // flattened 128-bit block
wire [23:0] TAG_OUT;

//Obtaining the stored values from the register array depending on the index
assign #1 DATA_OUT = DATA[ADDRESS[7:4]];
assign #1 VALID_OUT = VALID[ADDRESS[7:4]];
assign #1 DIRTY_OUT = DIRTY[ADDRESS[7:4]];
assign #1 TAG_OUT = TAG[ADDRESS[7:4]];

//tag compare and determining the hit status
wire TAG_STATUS, HIT;
assign #1 TAG_STATUS = (TAG_OUT == ADDRESS[31:8]) ? 1 : 0;
assign HIT = VALID_OUT && TAG_STATUS;

//clear busywait at positive clock edge and when there is a hit
always @ (posedge CLK)
begin
    if (HIT) BUSYWAIT = 0;
end

//select data from offsets
reg [7:0] DATA_BYTE;
reg [15:0] DATA_HALF;
reg [31:0] DATA_WORD;

// helper to fetch a byte from 128-bit block by byte index 0..15
function [7:0] get_byte;
    input [127:0] block;
    input [3:0]   byte_idx;
    begin
        case (byte_idx)
            4'd0 : get_byte = block[ 7: 0];
            4'd1 : get_byte = block[15: 8];
            4'd2 : get_byte = block[23:16];
            4'd3 : get_byte = block[31:24];
            4'd4 : get_byte = block[39:32];
            4'd5 : get_byte = block[47:40];
            4'd6 : get_byte = block[55:48];
            4'd7 : get_byte = block[63:56];
            4'd8 : get_byte = block[71:64];
            4'd9 : get_byte = block[79:72];
            4'd10: get_byte = block[87:80];
            4'd11: get_byte = block[95:88];
            4'd12: get_byte = block[103:96];
            4'd13: get_byte = block[111:104];
            4'd14: get_byte = block[119:112];
            4'd15: get_byte = block[127:120];
            default: get_byte = 8'hxx;
        endcase
    end
endfunction

always @ (*) begin
    case(READ_WRITE)
        4'b1000: DATA_BYTE = get_byte(DATA_OUT, ADDRESS[3:0]);
        4'b1001: DATA_HALF = { get_byte(DATA_OUT, {ADDRESS[3:1],1'b1}), get_byte(DATA_OUT, {ADDRESS[3:1],1'b0}) };
        4'b1010: DATA_WORD = { get_byte(DATA_OUT, {ADDRESS[3:2],2'b11}), get_byte(DATA_OUT, {ADDRESS[3:2],2'b10}), get_byte(DATA_OUT, {ADDRESS[3:2],2'b01}), get_byte(DATA_OUT, {ADDRESS[3:2],2'b00}) };
        default: begin DATA_BYTE = 8'd0; DATA_HALF = 16'd0; DATA_WORD = 32'd0; end
    endcase
end

// sign extend or zero extend the data
wire [31:0] LB, LH, LW, LBU, LHU;

assign LB[7:0] = DATA_BYTE;
assign LB[31:8] = {24{DATA_BYTE[7]}};

assign LH[15:0] = DATA_HALF;
assign LH[31:16] = {16{DATA_HALF[15]}};

assign LW = DATA_WORD;

assign LBU = {24'd0, DATA_BYTE[31:24]};

assign LHU = {16'd0, DATA_HALF[31:16]};

// output the data
always @ (*) begin
    #1;
    case(READ_WRITE[2:0])
        3'b000 :   READDATA = LB;
        3'b001 :   READDATA = LH;
        3'b010 :   READDATA = LW;
        3'b100 :   READDATA = LBU;
        3'b101 :   READDATA = LHU; 
    endcase
end

//write data to cache
always @ (posedge CLK)
begin
        if (HIT && READ_WRITE[3])
    begin
        #1;
        DIRTY[ADDRESS[7:4]] = 1;
        case (READ_WRITE)
            4'b1011 : begin
                // byte write
                byte_pos = ADDRESS[3:0] * 8;
                DATA[ADDRESS[7:4]][byte_pos +: 8] = WRITEDATA[7:0];
            end
            4'b1110 : begin
                // halfword write (two bytes)
                idx0 = {ADDRESS[3:1],1'b0};
                idx1 = {ADDRESS[3:1],1'b1};
                byte_pos0 = idx0 * 8;
                byte_pos1 = idx1 * 8;
                DATA[ADDRESS[7:4]][byte_pos0 +: 8] = WRITEDATA[7:0];
                DATA[ADDRESS[7:4]][byte_pos1 +: 8] = WRITEDATA[15:8];
            end
            4'b1111 : begin
                // word write (four bytes)
                idx_base = {ADDRESS[3:2],2'b00};
                bp0 = idx_base * 8;
                bp1 = (idx_base + 1) * 8;
                bp2 = (idx_base + 2) * 8;
                bp3 = (idx_base + 3) * 8;
                DATA[ADDRESS[7:4]][bp0 +: 8] = WRITEDATA[7:0];
                DATA[ADDRESS[7:4]][bp1 +: 8] = WRITEDATA[15:8];
                DATA[ADDRESS[7:4]][bp2 +: 8] = WRITEDATA[23:16];
                DATA[ADDRESS[7:4]][bp3 +: 8] = WRITEDATA[31:24];
            end
        endcase
    end
end

/* Cache Controller FSM Start */
parameter IDLE = 2'b00, READ_MEM = 2'b10, WRITE_MEM = 2'b01, UPDATE_CACHE = 2'b11;
reg [1:0] STATE, NEXT_STATE;

// combinational next state logic
always @(*)
begin
    case (STATE)
        IDLE:
            if (READ_WRITE[3] && !DIRTY_OUT && !HIT)  
               NEXT_STATE = READ_MEM;
            else if (READ_WRITE[3] && DIRTY_OUT && !HIT)
                NEXT_STATE = WRITE_MEM;
            else
                NEXT_STATE = IDLE;
            
        READ_MEM:
            if (!MEM_BUSYWAIT)
                NEXT_STATE = UPDATE_CACHE;
            else    
                NEXT_STATE = READ_MEM;
        
        WRITE_MEM:
            if (!MEM_BUSYWAIT)
                NEXT_STATE = READ_MEM;
            else
                NEXT_STATE = WRITE_MEM;

        UPDATE_CACHE:
            NEXT_STATE = IDLE;
            
    endcase
end

// combinational output logic
always @(STATE)
begin
    case(STATE)
        IDLE:
        begin
            MEM_READ = 0;
            MEM_WRITE = 0;
            MEM_ADDRESS = 28'dx;
            MEM_WRITEDATA = 128'dx;
        end
         
        READ_MEM: 
        begin
            MEM_READ = 1;
            MEM_WRITE = 0;
            MEM_ADDRESS = {ADDRESS[31:4]};
            MEM_WRITEDATA = 128'dx;
            // BUSYWAIT = 1;
        end

        WRITE_MEM: 
        begin
            MEM_READ = 0;
            MEM_WRITE = 1;
            MEM_ADDRESS = {TAG_OUT, ADDRESS[7:4]};
            MEM_WRITEDATA = DATA_OUT;
        end

        UPDATE_CACHE:
        begin
            #1;
            DATA[ADDRESS[7:4]] = MEM_READDATA;
            DIRTY[ADDRESS[7:4]] = 0;
            VALID[ADDRESS[7:4]] = 1;
            TAG[ADDRESS[7:4]] = ADDRESS[31:8];
        end
            
    endcase
end

// sequential logic for state transitioning 
always @ (posedge CLK or posedge RESET)
begin
    if(RESET)
        STATE <= IDLE;
    else
        STATE <= NEXT_STATE;
end


//reset the cache memory when the reset signal is high
integer i;

always @ (posedge RESET)
begin
    if(RESET)
    begin
        for ( i = 0; i < 16; i = i + 1)
        begin
            VALID[i] = 0;
            DIRTY[i] = 1'b0;
            TAG[i] = 24'bx;
            BUSYWAIT = 0;
            DATA[i] = 128'dx;
        end
    end
end
    
endmodule