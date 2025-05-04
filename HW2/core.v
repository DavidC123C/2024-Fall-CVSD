module core #( // DO NOT MODIFY INTERFACE!!!
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32
) ( 
    input i_clk,
    input i_rst_n,

    // Testbench IOs
    output [2:0] o_status, 
    output       o_status_valid,

    // Memory IOs
    output [ADDR_WIDTH-1:0] o_addr,
    output [DATA_WIDTH-1:0] o_wdata,
    output                  o_we,
    input  [DATA_WIDTH-1:0] i_rdata
);
reg o_we_out;

localparam IDLE = 4'd0;
localparam FETCH = 4'd1;
localparam DECODE = 4'd2;
localparam TEMP = 4'd3;
localparam COMPUTE = 4'd4;
localparam LOAD = 4'd5;
localparam STORE = 4'd6;
localparam PC_state = 4'd7;
localparam CHECK_PC = 4'd8;
localparam FINISH = 4'd9;

// ---------------------------------------------------------------------------
// Wires and Registers
reg [2:0] o_status_w; 
wire R_type, I_type, S_type, B_type;
wire    [ 6:0] opcode;
wire    [ 4:0] rd;
wire    [ 2:0] funct3;
wire    [ 4:0] rs1;
wire    [ 4:0] rs2;
wire    [ 6:0] funct7;
wire signed [31:0] immediate;
wire ALUSrc, RegWrite, MemtoReg;
wire [5:0] alu_op;
reg [3:0] state, nxt_state;
wire signed [32:0] alu_result_add,alu_result_sub ;
wire [32:0] float_test;
wire ADD, SUB, ADDI, LW, SW, BEQ, BLT, SLT, SLL_1 ,SRL_1, FADD, FSUB, FLW, FSW, FLT, EOF;
reg [ADDR_WIDTH-1:0] PC, nxt_PC;
reg [31:0] inst, nxt_inst;
wire [31:0] rdata1_in, rdata2_in, alu_in2, alu_out;
reg [2:0] status_type;
reg [31:0] wdata_in, nxt_wdata_in;
wire [2:0] ctrl_fp_w ;
/////////////////
assign funct7 = inst[31:25];
assign rs2    = inst[24:20];
assign rs1    = inst[19:15];
assign funct3 = inst[14:12];
assign rd     = inst[11: 7];
assign opcode = inst[ 6: 0];

assign R_type = (opcode == 7'b0110011) || (opcode == 7'b1010011);
assign I_type = (opcode == 7'b0010011) || (opcode == 7'b0000011) ||(opcode == 7'b0000111);
assign S_type = (opcode == 7'b0100011) || (opcode == 7'b0100111);
assign B_type = (opcode == 7'b1100011);

Reg_file reg0 (.i_clk(i_clk),
               .i_rst_n(i_rst_n),
               .wen(RegWrite),
               .rs1(rs1),
               .rs2(rs2),
               .rd(rd),
               .wdata(wdata_in),
               .rdata1(rdata1_in),
               .rdata2(rdata2_in),
               .ctrl_fp(ctrl_fp_w));
ALU alu1(
                 .in1(rdata1_in),
                 .in2(alu_in2),
                 .ctrl(alu_op),
                 .out_alu(alu_out));

assign ADD = (opcode == `OP_ADD) && (funct3 == `FUNCT3_ADD) && (funct7 == `FUNCT7_ADD) ;
assign SUB = (opcode == `OP_SUB) && (funct3 == `FUNCT3_SUB) && (funct7 == `FUNCT7_SUB) ;
assign ADDI = (opcode == `OP_ADDI) && (funct3 == `FUNCT3_ADDI) ;
assign LW = (opcode == `OP_LW) && (funct3 == `FUNCT3_LW) ;
assign SW = (opcode == `OP_SW) && (funct3 == `FUNCT3_SW) ;
assign BEQ = (opcode == `OP_BEQ) && (funct3 == `FUNCT3_BEQ) ;
assign BLT = (opcode == `OP_BLT) && (funct3 == `FUNCT3_BLT) ;
assign SLT = (opcode == `OP_SLT) && (funct3 == `FUNCT3_SLT) && (funct7 == `FUNCT7_SLT) ;
assign SLL_1 = (opcode == `OP_SLL) && (funct3 == `FUNCT3_SLL) && (funct7 == `FUNCT7_SLL) ;
assign SRL_1 = (opcode == `OP_SRL) && (funct3 == `FUNCT3_SRL) && (funct7 == `FUNCT7_SRL) ;
assign FADD = (opcode == `OP_FADD) && (funct3 == `FUNCT3_FADD) && (funct7 == `FUNCT7_FADD) ;
assign FSUB = (opcode == `OP_FSUB) && (funct3 == `FUNCT3_FSUB) && (funct7 == `FUNCT7_FSUB) ;
assign FLW = (opcode == `OP_FLW) && (funct3 == `FUNCT3_FLW) ;
assign FSW = (opcode == `OP_FSW) && (funct3 == `FUNCT3_FSW) ;
assign FCLASS = (opcode == `OP_FCLASS) && (funct3 == `FUNCT3_FCLASS) && (funct7 == `FUNCT7_FCLASS) ;
assign FLT = (opcode == `OP_FLT) && (funct3 == `FUNCT3_FLT) && (funct7 == `FUNCT7_FLT) ;
assign EOF = (opcode == `OP_EOF) ;


assign immediate = (I_type) ? {{21{inst[31]}}, inst[30:20]}:
                   (S_type) ? {{21{inst[31]}}, inst[30:25], inst[11:7]}:
                   (B_type) ? {{20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0}:
                    32'b0;  
assign ALUSrc   = (I_type || S_type) ? 1 : 0 ;
assign RegWrite = ((R_type || I_type) && (state == DECODE)) ? 1 : 0 ;
assign MemtoReg = (I_type) ? 1 : 0;
assign alu_op = (LW || SW || ADDI || FLW || FSW) ? 6'b0 : {opcode[6],funct7[5],funct7[2],funct3};
assign alu_in2 = (ALUSrc) ? immediate : rdata2_in;

assign o_we = o_we_out;
assign alu_result_add = $signed(rdata1_in) + $signed(alu_in2);
assign alu_result_sub = $signed(rdata1_in) - $signed(alu_in2);
assign float_test = $signed(rdata1_in) + $signed(rdata2_in);
assign ctrl_fp_w = (FADD || FSUB )? 1 : (FLW) ? 2 : (FSW) ? 3 : (FLT) ? 4 :(FCLASS) ? 5 : 0;
// ---------------------------------------------------------------------------
// ----         FSM             ---- //

always @(*) begin
    case (state)
        IDLE: nxt_state = FETCH;//0
        FETCH: nxt_state = DECODE;//1
        DECODE: nxt_state = TEMP;//2
        TEMP:begin               //3
            if(ADD || ADDI)begin
                if ((!alu_result_add[32] && alu_result_add[31]) || (alu_result_add[32] && !alu_result_add[31])) begin
                    nxt_state = FINISH;
                end
                else nxt_state = COMPUTE;
            end
            else if(SUB) begin
                if((!alu_result_sub[32] && alu_result_sub[31]) || (alu_result_sub[32] && !alu_result_sub[31]))begin
                    nxt_state = FINISH;
                end
                else nxt_state = COMPUTE;
            end
            else if (LW || SW || FLW || FSW)begin
                if (($signed(rdata1_in)+immediate)<32'd4096 || ($signed(rdata1_in)+immediate)>32'd8191) begin 
                    nxt_state = FINISH;
                end
                else nxt_state = LOAD;
            end
            else if (FADD || FSUB || FLT)begin
                if ((alu_out[31] == 1'b0) && (alu_out[30:23] == 8'b1111_1111) && (alu_out ==23'b0)) begin  //positive INF
                    nxt_state = FINISH;
                end
                else if ((alu_out[31] == 1'b1) && (alu_out[30:23] == 8'b1111_1111) && (alu_out ==23'b0)) begin//Negative INF
                    nxt_state = FINISH;
                end
                else if ((alu_out[30:23] == 8'b1111_1111) && (|alu_out[22:0]))begin
                    nxt_state = FINISH;//NaN
                end
                else if (((rdata1_in[31] == 1'b0) || (rdata1_in[31] == 1'b1)) && (rdata1_in[30:23] == 8'b1111_1111) && (rdata1_in ==23'b0)) begin
                    nxt_state = FINISH;
                end
                else if ((rdata1_in[30:23] == 8'b1111_1111) && (|rdata1_in[22:0]))begin
                    nxt_state = FINISH;//NaN
                end
                else if (((alu_in2[31] == 1'b0) || (alu_in2[31] == 1'b1)) && (alu_in2[30:23] == 8'b1111_1111) && (alu_in2 ==23'b0)) begin
                    nxt_state = FINISH;
                end
                else if ((alu_in2[30:23] == 8'b1111_1111) && (|alu_in2[22:0])) begin
                    nxt_state = FINISH;//NaN
                end
                else nxt_state = COMPUTE;
            end
            else if (BEQ || BLT) nxt_state = PC_state;

            else if (EOF) nxt_state = FINISH;
            else nxt_state = COMPUTE;
        end
        COMPUTE: nxt_state = PC_state;//4
        LOAD: nxt_state = STORE;      //5
        STORE: nxt_state = PC_state;  //6
        PC_state: nxt_state = CHECK_PC;//7
        CHECK_PC: begin               //8
            if (BEQ || BLT) begin
                nxt_state = (($signed(PC)>32'd4095) || ($signed(PC)<32'd0)) ? FINISH : FETCH; 
            end
            else nxt_state = FETCH;
        end
        FINISH: nxt_state = FINISH;  //9

        default: nxt_state = state;
    endcase
end

// ---------------------------------------------------------------------------
// Continuous Assignment
// ---------------------------------------------------------------------------
assign o_status_valid = ((state == FINISH)|| ((state == CHECK_PC) && ($signed(PC)<=32'd4095) && ($signed(PC)>=32'd0))) ? 1'b1 : 1'b0;
assign o_addr = (state == FETCH || state == DECODE || state == COMPUTE || state == PC_state || state ==TEMP || state == CHECK_PC)  ? PC :
                (state == LOAD || state == STORE) ? alu_out : 32'b0; 
                
// ---------------------------------------------------------------------------
// Combinational Blocks
// ---------------------------------------------------------------------------
always @(*) begin
    if (ADD || SUB || SLT || SLL_1 || SRL_1 || FADD || FSUB || FCLASS ||FLT) begin
        status_type = `R_TYPE;
    end
    else if (ADDI || LW ||FLW)begin
        status_type = `I_TYPE;
    end
    else if (SW || FSW)begin
        status_type = `S_TYPE;
    end
    else if (BEQ ||BLT)begin
        status_type = `B_TYPE;
    end
    else if (EOF)begin
        status_type = `EOF_TYPE;
    end
    else status_type = `R_TYPE;
end

///////////output status
assign o_status = o_status_w;
always @(*) begin
    if (EOF) begin
        o_status_w = `EOF_TYPE;
    end
    else if (state == FINISH) o_status_w = `INVALID_TYPE;
    else o_status_w = status_type;
end
//instruction fetch
always @(*) begin
    case (state)
        DECODE:begin 
            if (o_we_out == 1'b0 && (!SW)) begin
                nxt_inst = i_rdata;
            end
            else if (o_we_out == 1'b0 && (!LW))begin
                nxt_inst = i_rdata;
            end
            else nxt_inst = inst;
        end 
        default: nxt_inst = inst;
    endcase
end
//load data
always @(*) begin
    case (state)
        LOAD:begin   
            nxt_wdata_in = i_rdata;
        end 
        TEMP,COMPUTE: begin 
            nxt_wdata_in = alu_out;
        end
        PC_state:begin
            if (FLW || FSW || LW ||SW) begin 
                nxt_wdata_in = i_rdata;
            end
            else nxt_wdata_in = wdata_in;
        end
        default: nxt_wdata_in = wdata_in;
    endcase
end
//store data
assign o_wdata = (state == STORE) ? rdata2_in : 32'b0; 

//Branch PC
always @(*) begin
    case (state)
        PC_state:begin  
            if ((BEQ && (($signed(rdata1_in)) == ($signed(rdata2_in)))) || (BLT && (($signed(rdata1_in)) < ($signed(rdata2_in))))) begin
                nxt_PC = PC + immediate;
            end
            else nxt_PC = PC+4;
        end 
        default: nxt_PC = PC;
    endcase
end


always @(*) begin
    case (state)
        FETCH: begin
            o_we_out = 1'b0; 
        end 
        LOAD: begin
            o_we_out = 1'b0;
        end
        STORE: begin
            if (SW || FSW) begin
                o_we_out = 1'b1;
            end
            else o_we_out = 1'b0;
        end
        default: o_we_out = 1'b0;
    endcase
end

// ---------------------------------------------------------------------------
// Sequential Block
// ---------------------------------------------------------------------------
always @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
        PC <= 0;
        inst <= 0;
        state <= 0;
        wdata_in <= 0;
    end
    else begin
        PC <= nxt_PC;
        inst <= nxt_inst;
        state <= nxt_state;
        wdata_in <= nxt_wdata_in;
    end
end




endmodule

module ALU (in1, in2, out_alu, ctrl);
    input  [31:0] in1,in2;
    input  [5:0] ctrl;
    output [31:0] out_alu;  

localparam INT_W = 9;
localparam FRAC_W = 23;
localparam EXP_SHIFT = 8;
localparam DATA_W = INT_W+FRAC_W;
localparam EXTEND_BIT = 5;
/////////////

reg [31:0] o_out;
reg [31:0] round_out,temp_out;
wire signed_a, signed_b;
wire  signed [INT_W-2:0] a_exp, b_exp;
wire [INT_W-2:0]a_exp_before127, b_exp_before127;  
wire [FRAC_W-1:0] a_frac, b_frac;
wire exp_compare;
reg  [EXP_SHIFT-1:0] shift_mantissa;
reg  [INT_W-2:0] large_exp_temp, large_exp;
reg [INT_W-2:0] exp_normalize, exp_normalize_aft_round;
wire [FRAC_W:0] a_int, b_int;
wire [FRAC_W+EXTEND_BIT:0] a_extend,b_extend; 
reg  [FRAC_W+EXTEND_BIT:0] a_extend_shift, b_extend_shift;
reg  [FRAC_W+EXTEND_BIT+1:0] a_operation, b_operation; 
reg  [FRAC_W+EXTEND_BIT+2:0] result_temp;
reg   [FRAC_W+EXTEND_BIT+2:0] result, result_normalize;
reg [5:0] clz, clz_shift;
reg [24:0] result_round, result_round_normal,result_round_normal_w; 
wire [7:0] exp_to_out;
wire a_zero,b_zero,a_subnormal,b_subnormal,a_normal,b_normal;
wire zero_and_subnormal, sub_and_sub;
wire a_neg_zero,b_neg_zero;
wire two_positive_sub;
wire neg_sub_a_2_pos_sub_b, pos_sub_a_2_neg_sub_b; 
wire neg_sub_a_add_neg_sub_b;
wire normal_sub_subnormal;

//////continuous assignment///////
assign signed_a = in1[DATA_W-1];
assign signed_b = in2[DATA_W-1];
assign a_exp_before127 = in1[DATA_W-2:FRAC_W];
assign b_exp_before127 = in2[DATA_W-2:FRAC_W];
assign a_frac = in1[FRAC_W-1:0];
assign b_frac = in2[FRAC_W-1:0];
assign a_int = (|a_exp_before127 && (a_exp_before127 != 8'b1111_1111)) ? {1'b1,a_frac} : ((a_exp_before127 ==8'b0) && (|a_frac)) ? {1'b0 ,a_frac} : 23'b0 ;
assign b_int = (|b_exp_before127 && (b_exp_before127 != 8'b1111_1111)) ? {1'b1,b_frac} : ((b_exp_before127 ==8'b0) && (|b_frac)) ? {1'b0 ,b_frac} : 23'b0 ;
assign a_exp = ((a_exp_before127 ==8'b0) && (|a_frac)) ?  (-8'd126) : (|a_exp_before127 && (a_exp_before127 != 8'b1111_1111)) ? (a_exp_before127 - (8'd127)) : 8'b0;
assign b_exp = ((b_exp_before127 ==8'b0) && (|b_frac)) ?  (-8'd126) : (|b_exp_before127 && (b_exp_before127 != 8'b1111_1111)) ? (b_exp_before127 - (8'd127)) : 8'b0;
assign exp_compare = (a_exp_before127 >= b_exp_before127) ? 1'b1 : 1'b0;
assign a_extend = {a_int,{EXTEND_BIT{1'b0}}};
assign b_extend = {b_int,{EXTEND_BIT{1'b0}}};

assign a_zero = (in1[30:0] == 31'b0) ? 1'b1 : 1'b0;
assign b_zero = (in2[30:0] == 31'b0) ? 1'b1 : 1'b0;
assign a_normal = (|a_exp_before127 && (a_exp_before127 != 8'b1111_1111)) ? 1'b1 : 1'b0;
assign b_normal = (|b_exp_before127 && (b_exp_before127 != 8'b1111_1111)) ? 1'b1 : 1'b0;
assign a_subnormal = ((a_exp_before127 ==8'b0) && (|a_frac)) ? 1'b1 : 1'b0;
assign b_subnormal = ((b_exp_before127 ==8'b0) && (|b_frac)) ? 1'b1 : 1'b0;
assign zero_and_subnormal = ((a_zero && b_subnormal) || (b_zero && a_subnormal)) ? 1'b1 : 1'b0;
assign sub_and_sub = (a_subnormal && b_subnormal) ? 1'b1 : 1'b0;
assign a_neg_zero = (in1[31] && (in1[30:0] == 31'b0)) ? 1'b1 : 1'b0;
assign b_neg_zero = (in2[31] && (in2[30:0] == 31'b0)) ? 1'b1 : 1'b0;
assign two_positive_sub = (a_subnormal && (!in1[31]) && b_subnormal && (!in2[31]));
assign neg_sub_a_2_pos_sub_b = ((a_subnormal && signed_a) && (b_subnormal && !signed_b) && (ctrl == 6'b101000));
assign pos_sub_a_2_neg_sub_b = ((a_subnormal && !signed_a) && (b_subnormal && signed_b) && (ctrl == 6'b101000));
assign neg_sub_a_add_neg_sub_b = ((a_subnormal && signed_a) && (b_subnormal && signed_b) && (ctrl == 6'b100000));
assign normal_sub_subnormal = (((a_exp_before127 == 8'b0000_0001) && b_subnormal) || (a_subnormal || (b_exp_before127 == 8'b0000_0001))) && ((ctrl == 6'b101000) || (ctrl == 6'b100000)) && (clz_shift == 1'b1);


always @(*) begin
    if (exp_compare) begin 
        large_exp_temp = a_exp_before127;
    end
    else begin           
        large_exp_temp = b_exp_before127;
    end
end
always @(*) begin //shift mantissa
    if (exp_compare && ((a_subnormal && b_zero) || (b_subnormal && a_zero))) begin 
        shift_mantissa = 8'b0;
    end
    else if (exp_compare) begin
        shift_mantissa = a_exp - b_exp;
    end
    else begin
        shift_mantissa = b_exp - a_exp;
    end
end


always @(*) begin
    large_exp = large_exp_temp;
end

always @(*) begin
    if (!exp_compare) begin  
        a_extend_shift = a_extend >> shift_mantissa;
        b_extend_shift = b_extend;
    end
    else begin             
        a_extend_shift = a_extend;
        b_extend_shift = b_extend >> shift_mantissa;
    end
end

always @(*) begin
    if (signed_a && (!a_neg_zero)) begin
        a_operation = ~({1'b0,a_extend_shift}) + 1'b1;
    end
    else a_operation = {1'b0,a_extend_shift};
end

always @(*) begin
    if (signed_b && (!b_neg_zero)) begin
        b_operation = ~({1'b0,b_extend_shift}) + 1'b1;
    end
    else b_operation = {1'b0,b_extend_shift};
end

always @(*) begin
    if (result_temp[FRAC_W+EXTEND_BIT+2]) begin
        result = ~result_temp + 1'b1;        
    end
    else begin
        result = result_temp;
    end
end
always @(*) begin
        if(result[30]) clz = 0;
        else if (result[29]) clz = 1;
        else if (result[28]) clz = 2;
        else if (result[27]) clz = 3;
        else if (result[26]) clz = 4;
        else if (result[25]) clz = 5;
        else if (result[24]) clz = 6;
        else if (result[23]) clz = 7;
        else if (result[22]) clz = 8;
        else if (result[21]) clz = 9;
        else if (result[20]) clz = 10;
        else if (result[19]) clz = 11;
        else if (result[18]) clz = 12;
        else if (result[17]) clz = 13;
        else if (result[16]) clz = 14;
        else if (result[15]) clz = 15;
        else if (result[14]) clz = 16;
        else if (result[13]) clz = 17;
        else if (result[12]) clz = 18;
        else if (result[11]) clz = 19;
        else if (result[10]) clz = 20;
        else if (result[9])  clz = 21;
        else if (result[8])  clz = 22;
        else if (result[7])  clz = 23;
        else if (result[6])  clz = 24;
        else if (result[5])  clz = 25;
        else if (result[4])  clz = 26;
        else if (result[3])  clz = 27;
        else if (result[2])  clz = 28;
        else if (result[1])  clz = 29;
        else if (result[0])  clz = 30;
        else clz = 31;    
end
always @(*) begin
    if (sub_and_sub && result[28]) begin
        clz_shift = 2'd2;
    end
    else if (clz > 3'd2 && (!zero_and_subnormal) && (!sub_and_sub)) begin
        clz_shift = clz - 3'd2;
    end
    else if (clz < 3'd2 && (!zero_and_subnormal) && (!sub_and_sub)) begin
        clz_shift = 3'd2 - clz;
    end
    else begin
        clz_shift = 0;
    end
end
always @(*) begin
    if (sub_and_sub && result[28]) begin
        result_normalize = result;/////
    end
    else if (clz > 3'd2) begin
        result_normalize = result << clz_shift;
    end
    else if (clz < 3'd2)begin
        result_normalize = result >> clz_shift;
    end
    else result_normalize = result;    
end
always @(*) begin  
    if (sub_and_sub && result[28] ) begin      
        exp_normalize = large_exp + 1'b1;
    end
    else if (clz > 3'd2) begin                                     
        exp_normalize = large_exp - clz_shift;
    end
    else if (clz < 3'd2)begin
        exp_normalize = large_exp + clz_shift;
    end
    else exp_normalize = large_exp;
end
always @(*) begin
    if (!result_normalize[4]) begin 
        result_round = result_normalize[28:5]; 
    end
    else if (result_normalize[4] && (result_normalize[3:0] != 4'b0000)) begin
        result_round = result_normalize[28:5] +1'b1;
    end
    else if (result_normalize[4] && (result_normalize[3:0]==4'b0) && (!result_normalize[5])) begin
        result_round = result_normalize[28:5];
    end
    else if (result_normalize[4] && (result_normalize[3:0]==4'b0) && (result_normalize[5])) begin
        result_round = result_normalize[28:5] +1'b1;
    end
    else result_round = 24'b0;
end
always @(*) begin
    if (result_round[24]) begin
        result_round_normal = result_round >> 1'b1;
        exp_normalize_aft_round = exp_normalize + 1'b1;
    end
    else begin
        result_round_normal = result_round;
        exp_normalize_aft_round = exp_normalize;
    end
end

always @(*) begin
    result_round_normal_w = result_round_normal;
end

assign exp_to_out = ((result_temp == 31'b0) && (a_exp_before127 == b_exp_before127)) ? 8'b0 :
                    (sub_and_sub && result[28]) ? exp_normalize_aft_round :
                    ((a_exp_before127 != 8'b0) || (b_exp_before127 != 8'b0)) ? (exp_normalize_aft_round ) :exp_normalize_aft_round ;
assign out_alu = o_out;

    always @(*) begin 
        case (ctrl)
            6'b000000: o_out = $signed(in1)+$signed(in2); //add addi
            6'b010000: o_out = $signed(in1)-$signed(in2); //sub
            6'b000010: o_out = ($signed(in1) < $signed(in2)) ? 1 : 0; //SLT
            6'b000001: o_out = in1 << in2; 
            6'b000101: o_out = in1 >> in2; 
            6'b100000: begin                    //FADD
                        result_temp = $signed(a_operation) + $signed(b_operation);
                        o_out = {result_temp[FRAC_W+EXTEND_BIT+2],exp_to_out,result_round_normal_w[22:0]};
                    end
            6'b101000: begin//FSUB
                        result_temp = $signed(a_operation) - $signed(b_operation);
                        o_out = {result_temp[FRAC_W+EXTEND_BIT+2],exp_to_out,result_round_normal_w[22:0]};
                        end 
            6'b100001: begin//FLT
                        if ( signed_a && signed_b && (a_exp_before127 > b_exp_before127)) begin 
                            o_out = 1;
                        end
                        else if (signed_a && signed_b && (a_exp_before127 == b_exp_before127) && (a_frac > b_frac))begin
                            o_out = 1;
                        end
                        else if ((!signed_a) && (!signed_b) && (a_exp_before127 < b_exp_before127)) begin
                            o_out = 1;
                        end
                        else if ((!signed_a) && (!signed_b) && (a_exp_before127 == b_exp_before127) && (a_frac < b_frac))begin
                            o_out = 1;
                        end
                        else if (signed_a && (!signed_b)) begin
                            o_out = 1;
                        end
                        else o_out = 0;
            end
            6'b110000:begin //FCLASS
                if (in1[31] && (in1[30:23] == 8'd255) && (in1[22:0] == 23'b0)) begin //Negative infinite
                    o_out = 32'b0;
                end
                else if (in1[31] && (in1[30:23] != 8'b0) && (in1[30:23] != 8'd255))begin// Negative normal number
                    o_out = 32'd1;
                end
                else if (in1[31] && (in1[30:23] == 8'b0) && (in1[22:0] != 23'b0))begin//Negative subnormal number
                    o_out = 32'd2;
                end
                else if (in1[31] && (in1[30:0] == 31'b0))begin                        //Negative zero
                    o_out = 32'd3;
                end
                else if (in1 == 32'b0) o_out = 32'd4;                                //Positive zero
                else if (!in1[31] && (in1[30:23] == 8'b0) && (in1[22:0] != 23'b0)) o_out = 32'd5; // Positive subnormal number
                else if (!in1[31] && (in1[30:23] != 8'b0) && (in1[30:23] != 8'd255)) o_out = 32'd6;// Positive normal number
                else if (!in1[31] && (in1[30:23] == 8'd255) && (in1[22:0] == 23'b0)) o_out = 32'd7;//Positive infinite
                else if ((in1[30:23] == 8'd255) && (in1[22:0] != 23'b0)) o_out = 32'd8;               //NAN
                else o_out = 32'b0;
            end
            default: o_out = 32'b0;
        endcase
    end


endmodule

module Reg_file(i_clk, i_rst_n, wen, rs1, rs2, rd, wdata, rdata1, rdata2, ctrl_fp);
   
    parameter BITS = 32;
    parameter word_depth = 64;
    parameter addr_width = 5; // 2^addr_width >= word_depth
    
    input i_clk, i_rst_n, wen; // wen: 0:read | 1:write
    input [BITS-1:0] wdata;
    input [addr_width-1:0] rs1, rs2, rd;
    input [2:0] ctrl_fp;

    output [BITS-1:0] rdata1, rdata2;

    reg [BITS-1:0] mem [0:word_depth-1];
    reg [BITS-1:0] mem_nxt [0:word_depth-1];

    integer i;
    assign rdata1 = ((ctrl_fp == 1) || (ctrl_fp == 4) || (ctrl_fp == 5)) ? mem[rs1+32] : mem[rs1];
    assign rdata2 = ((ctrl_fp == 1) || (ctrl_fp == 3) || (ctrl_fp == 4)) ? mem[rs2+32] : mem[rs2];



    always @(*) begin   
        for (i=0; i<word_depth; i=i+1)
            mem_nxt[i] = (wen && ((ctrl_fp == 0) || (ctrl_fp == 3) || (ctrl_fp ==5) || (ctrl_fp == 4)) && (rd == i)) ? wdata : mem[i];
    end

    always @(*) begin 
        for (i=32; i<64; i=i+1)
            mem_nxt[i] = (wen && ((ctrl_fp == 1) || (ctrl_fp == 2)) && ((rd+32) == i)) ? wdata : mem[i];
    end



    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            for (i=0; i<word_depth; i=i+1) begin
                mem[i] <= 32'b0;
            end
        end
        else begin
            for (i=0; i<word_depth; i=i+1)
                mem[i] <= mem_nxt[i];
        end       
    end
endmodule

