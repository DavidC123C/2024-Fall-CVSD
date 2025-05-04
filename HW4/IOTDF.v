`timescale 1ns/10ps
module IOTDF( clk, rst, in_en, iot_in, fn_sel, busy, valid, iot_out);
input          clk;
input          rst;
input          in_en;
input  [7:0]   iot_in;
input  [2:0]   fn_sel;
output         busy;
output         valid;
output [127:0] iot_out;


parameter IDLE = 3'd0;
parameter READ = 3'd1;


reg  state, nxt_state;
reg [4:0] read_cnt, nxt_read_cnt;
reg [127:0] buffer, nxt_buffer;
reg busy_out, nxt_busy_out;
reg valid_w, valid_r;
reg [31:0] round_R, nxt_round_R, round_L, nxt_round_L;
reg [31:0] temp_R;
wire [31:0] f_out;
wire [63:0] final_cipher_temp;
reg  [63:0] final_ciphertext;
reg [63:0] init_permut;
wire encry_or_decry;
wire [47:0] sub_key;
reg cipher_flag, nxt_cipher_flag;
reg read_flag, nxt_read_flag;
reg [63:0] temp_main_key;
reg  [3:0] cmp_read_cnt, nxt_cmp_read_cnt;
reg out_cnt, nxt_out_cnt;
reg crc_flag, nxt_crc_flag;
reg  [127:0] TOP_LAST_1, nxt_TOP_LAST_1, TOP_LAST_2, nxt_TOP_LAST_2;
wire [2:0] CRC3_result ;
wire enable_12, enable_3, enable_45;
wire fn4_enable_top_last_1, enable_top_last_2;
wire enable_out_cnt;
wire enable_busy;
wire enable_cmp_cnt;

assign encry_or_decry = (fn_sel == 3'b001) ? 1 : 0;

F_FUNCTION f0 (.R(round_R) ,.L(round_L) ,.K_in(sub_key) ,.f_out(f_out) );
SUB_KEY    s0 (.clk(clk) ,.rst(rst) ,.main_key(temp_main_key) ,.sub_key(sub_key) ,.rounds(read_cnt) ,.encry_or_decry(encry_or_decry) ,.fn_sel(fn_sel));

assign fn4_enable_top_last_1 = (((fn_sel == 4 || fn_sel == 5) && ((read_cnt == 1) || ((read_cnt == 4) && (out_cnt)) || (read_cnt == 6 && cmp_read_cnt == 0))) || ((fn_sel == 1 || fn_sel == 2) && ((read_cnt == 1) && read_flag))) ? 1 : 0;

assign enable_top_last_2 = ((fn_sel == 4 || fn_sel == 5) && ((read_cnt == 1) || ((read_cnt == 4) && (out_cnt))) || (read_cnt == 6 && cmp_read_cnt == 0)) ? 1 : 0;

always @(*) begin
    if (fn_sel ==4) begin
        if (read_cnt == 1) begin
            if (buffer > TOP_LAST_1) begin
                nxt_TOP_LAST_1 = buffer;
            end
            else nxt_TOP_LAST_1 = TOP_LAST_1;
        end
        else if ((read_cnt == 4) && (out_cnt)) begin
            nxt_TOP_LAST_1 = 0;
        end
        else nxt_TOP_LAST_1 = TOP_LAST_1;
    end
    else if (fn_sel ==5) begin
        if (read_cnt == 6 && cmp_read_cnt == 0) begin
            nxt_TOP_LAST_1 = 128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
        end
        else if (read_cnt == 1) begin
            if (buffer < TOP_LAST_1) begin
                nxt_TOP_LAST_1 = buffer;
            end
            else nxt_TOP_LAST_1 = TOP_LAST_1;
        end
        else if ((read_cnt == 4) && (out_cnt)) begin
            nxt_TOP_LAST_1 = 128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
        end
        else nxt_TOP_LAST_1 = TOP_LAST_1;        
    end
    else if (fn_sel == 1 || fn_sel == 2) begin
        if ((read_cnt == 1) && read_flag) begin         
            nxt_TOP_LAST_1 = {buffer[127:64],64'b0};
        end
        else nxt_TOP_LAST_1 = TOP_LAST_1;
    end    
    else nxt_TOP_LAST_1 = TOP_LAST_1;   
end
always @(*) begin
    if (fn_sel == 4) begin
        if (read_cnt == 1) begin
            if (buffer > TOP_LAST_1) begin
                nxt_TOP_LAST_2 = TOP_LAST_1;
            end
            else if (buffer > TOP_LAST_2) begin
                nxt_TOP_LAST_2 = buffer;
            end
            else nxt_TOP_LAST_2 = TOP_LAST_2;
        end
        else if ((read_cnt == 4) && (out_cnt)) begin
            nxt_TOP_LAST_2 = 0;
        end
        else nxt_TOP_LAST_2 = TOP_LAST_2;
    end
    else if (fn_sel == 5) begin
        if (read_cnt == 6 && cmp_read_cnt == 0) begin
            nxt_TOP_LAST_2 = 128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
        end        
        else if (read_cnt == 1) begin
            if (buffer < TOP_LAST_1) begin
                nxt_TOP_LAST_2 = TOP_LAST_1;
            end
            else if (buffer < TOP_LAST_2) begin
                nxt_TOP_LAST_2 = buffer;
            end
            else nxt_TOP_LAST_2 = TOP_LAST_2;
        end
        else if ((read_cnt == 4) && (out_cnt)) begin
            nxt_TOP_LAST_2 = 128'hFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
        end
        else nxt_TOP_LAST_2 = TOP_LAST_2;        
    end
    else nxt_TOP_LAST_2 = TOP_LAST_2;  
end

always @(*) begin
    if ((cmp_read_cnt == 8) && (read_cnt == 0)) begin
        nxt_out_cnt = 1'b1;
    end
    else if ((cmp_read_cnt == 0) && (read_cnt == 5)) begin
        nxt_out_cnt = 1'b0;
    end
    else nxt_out_cnt = out_cnt;
end

assign enable_out_cnt = ( (cmp_read_cnt == 8) && (read_cnt == 0) || (cmp_read_cnt == 0) && (read_cnt == 5)) ? 1 : 0;

always @(*) begin
    if (in_en) begin
        nxt_buffer[127:120] = iot_in;
        nxt_buffer[119:0]   = buffer[127:8];
    end
    else nxt_buffer = buffer;
end



assign enable_busy = (!IDLE) ? 1 : 0;

always @(*) begin
    if ((fn_sel == 4) || (fn_sel == 5) || (fn_sel == 3) || (fn_sel == 1) || (fn_sel == 2)) begin  //if fn_sel != 0
        nxt_busy_out = 1'b0;
    end
    else nxt_busy_out = 1'b1;
end

assign busy = busy_out;

always @(*) begin
    if (read_cnt == 15) begin
        nxt_read_cnt = 0;
    end
    else if (state == READ) begin
        nxt_read_cnt = read_cnt + 1;
    end
    else if (state != READ) begin
        nxt_read_cnt = 0;
    end
    else nxt_read_cnt = read_cnt;
end

assign enable_cmp_cnt = ( (read_cnt == 15) || ((cmp_read_cnt == 8))) ? 1: 0;

always @(*) begin
    if (read_cnt == 15) begin
        nxt_cmp_read_cnt = cmp_read_cnt + 1;
    end
    else if ((cmp_read_cnt == 8)) begin
        nxt_cmp_read_cnt = 0;
    end
    else nxt_cmp_read_cnt = cmp_read_cnt;
end
always @(*) begin
    if (read_cnt == 0 && cmp_read_cnt == 2) begin 
        nxt_cipher_flag = 1'b1;
    end
    else nxt_cipher_flag = cipher_flag;
end

always @(*) begin
    if ((cmp_read_cnt == 1) && (read_cnt == 0)) begin
        nxt_read_flag = 1'b1;
    end
    else nxt_read_flag = read_flag;
end

always @(*) begin   
    if (read_flag && (read_cnt == 1)) begin
        nxt_round_R = init_permut[31:0];
    end
    else begin
        nxt_round_R = f_out;
    end
end

always @(*) begin 
    if (read_flag && (read_cnt == 1)) begin
        nxt_round_L = init_permut[63:32];
    end
    else nxt_round_L = round_R;
end

always @(*) begin
    if (read_cnt == 1) begin
        temp_main_key = buffer[127:64];
    end
    else temp_main_key = TOP_LAST_1[127:64];
end

assign final_cipher_temp = {f_out,round_R};
assign iot_out = (((fn_sel == 4) || (fn_sel == 5)) && (out_cnt == 1'b1) && (read_cnt == 2)) ? TOP_LAST_1: 
                 (((fn_sel == 4) || (fn_sel == 5)) && (out_cnt == 1'b1) && (read_cnt == 3)) ? TOP_LAST_2 : 
                 ( fn_sel == 3) ? {125'b0,CRC3_result} :
                   {TOP_LAST_1[127:64],final_ciphertext};
always @(*) begin
    if (((fn_sel == 1) || (fn_sel == 2)) && cipher_flag && (read_cnt == 1)) begin
        valid_w = 1'b1;
    end
    else if ((fn_sel == 3) && (crc_flag) && (read_cnt == 1)) begin  /////
        valid_w = 1'b1;
    end
    else if (((fn_sel == 4) || (fn_sel == 5)) && (out_cnt == 1'b1) && (read_cnt == 2)) begin //和下面合併
        valid_w = 1'b1;
    end
    else if (((fn_sel == 4) || (fn_sel == 5)) && (out_cnt == 1'b1) && (read_cnt == 3)) begin
        valid_w = 1'b1;
    end
    else valid_w = 1'b0;
end
assign valid = valid_w;


assign CRC3_result = CRC3_CCITT(buffer);
function  [2:0] CRC3_CCITT;
    input [127:0] data; 
    reg [2:0] crc;
    integer i;
    reg data_in, data_out;
    parameter polynomial = 3'h6; 

    begin
        crc = 3'd0;
        for (i = 0; i < 128; i = i + 1) begin
            data_in = data[127-i];
            data_out = crc[2];
            crc = crc << 1; 
            if (data_in ^ data_out) begin
                crc = crc ^ polynomial;
            end
        end
        CRC3_CCITT = crc;
    end
endfunction
always @(*) begin
    if (cmp_read_cnt == 1 && read_cnt ==0) begin
        nxt_crc_flag = 1'b1;
    end
    else nxt_crc_flag = crc_flag;
end

/////////   initial permutation    /////////////
always @(*) begin
    init_permut[63] = buffer[6];
    init_permut[62] = buffer[14];
    init_permut[61] = buffer[22];
    init_permut[60] = buffer[30];
    init_permut[59] = buffer[38];
    init_permut[58] = buffer[46];
    init_permut[57] = buffer[54];
    init_permut[56] = buffer[62];
    init_permut[55] = buffer[4];
    init_permut[54] = buffer[12];
    init_permut[53] = buffer[20];
    init_permut[52] = buffer[28];
    init_permut[51] = buffer[36];
    init_permut[50] = buffer[44];
    init_permut[49] = buffer[52];
    init_permut[48] = buffer[60];
    init_permut[47] = buffer[2];
    init_permut[46] = buffer[10];
    init_permut[45] = buffer[18];
    init_permut[44] = buffer[26];
    init_permut[43] = buffer[34];
    init_permut[42] = buffer[42];
    init_permut[41] = buffer[50];
    init_permut[40] = buffer[58];
    init_permut[39] = buffer[0];
    init_permut[38] = buffer[8];
    init_permut[37] = buffer[16];
    init_permut[36] = buffer[24];
    init_permut[35] = buffer[32];
    init_permut[34] = buffer[40];
    init_permut[33] = buffer[48];
    init_permut[32] = buffer[56];
    init_permut[31] = buffer[7];
    init_permut[30] = buffer[15];
    init_permut[29] = buffer[23];
    init_permut[28] = buffer[31];
    init_permut[27] = buffer[39];
    init_permut[26] = buffer[47];
    init_permut[25] = buffer[55];
    init_permut[24] = buffer[63];
    init_permut[23] = buffer[5];
    init_permut[22] = buffer[13];
    init_permut[21] = buffer[21];
    init_permut[20] = buffer[29];
    init_permut[19] = buffer[37];
    init_permut[18] = buffer[45];
    init_permut[17] = buffer[53];
    init_permut[16] = buffer[61];
    init_permut[15] = buffer[3];
    init_permut[14] = buffer[11];
    init_permut[13] = buffer[19];
    init_permut[12] = buffer[27];
    init_permut[11] = buffer[35];
    init_permut[10] = buffer[43];
    init_permut[9] = buffer[51];
    init_permut[8] = buffer[59];
    init_permut[7] = buffer[1];
    init_permut[6] = buffer[9];
    init_permut[5] = buffer[17];
    init_permut[4] = buffer[25];
    init_permut[3] = buffer[33];
    init_permut[2] = buffer[41];
    init_permut[1] = buffer[49];
    init_permut[0] = buffer[57];
end
////////////    Final permutation   ///////////
always @(*) begin
    final_ciphertext[63] = final_cipher_temp[24];
    final_ciphertext[62] = final_cipher_temp[56];
    final_ciphertext[61] = final_cipher_temp[16];
    final_ciphertext[60] = final_cipher_temp[48];
    final_ciphertext[59] = final_cipher_temp[8];
    final_ciphertext[58] = final_cipher_temp[40];
    final_ciphertext[57] = final_cipher_temp[0];
    final_ciphertext[56] = final_cipher_temp[32];
    final_ciphertext[55] = final_cipher_temp[25];
    final_ciphertext[54] = final_cipher_temp[57];
    final_ciphertext[53] = final_cipher_temp[17];
    final_ciphertext[52] = final_cipher_temp[49];
    final_ciphertext[51] = final_cipher_temp[9];
    final_ciphertext[50] = final_cipher_temp[41];
    final_ciphertext[49] = final_cipher_temp[1];
    final_ciphertext[48] = final_cipher_temp[33];
    final_ciphertext[47] = final_cipher_temp[26];
    final_ciphertext[46] = final_cipher_temp[58];
    final_ciphertext[45] = final_cipher_temp[18];
    final_ciphertext[44] = final_cipher_temp[50];
    final_ciphertext[43] = final_cipher_temp[10];
    final_ciphertext[42] = final_cipher_temp[42];
    final_ciphertext[41] = final_cipher_temp[2];
    final_ciphertext[40] = final_cipher_temp[34];
    final_ciphertext[39] = final_cipher_temp[27];
    final_ciphertext[38] = final_cipher_temp[59];
    final_ciphertext[37] = final_cipher_temp[19];
    final_ciphertext[36] = final_cipher_temp[51];
    final_ciphertext[35] = final_cipher_temp[11];
    final_ciphertext[34] = final_cipher_temp[43];
    final_ciphertext[33] = final_cipher_temp[3];
    final_ciphertext[32] = final_cipher_temp[35];
    final_ciphertext[31] = final_cipher_temp[28];
    final_ciphertext[30] = final_cipher_temp[60];
    final_ciphertext[29] = final_cipher_temp[20];
    final_ciphertext[28] = final_cipher_temp[52];
    final_ciphertext[27] = final_cipher_temp[12];
    final_ciphertext[26] = final_cipher_temp[44];
    final_ciphertext[25] = final_cipher_temp[4];
    final_ciphertext[24] = final_cipher_temp[36];
    final_ciphertext[23] = final_cipher_temp[29];
    final_ciphertext[22] = final_cipher_temp[61];
    final_ciphertext[21] = final_cipher_temp[21];
    final_ciphertext[20] = final_cipher_temp[53];
    final_ciphertext[19] = final_cipher_temp[13];
    final_ciphertext[18] = final_cipher_temp[45];
    final_ciphertext[17] = final_cipher_temp[5];
    final_ciphertext[16] = final_cipher_temp[37];
    final_ciphertext[15] = final_cipher_temp[30];
    final_ciphertext[14] = final_cipher_temp[62];
    final_ciphertext[13] = final_cipher_temp[22];
    final_ciphertext[12] = final_cipher_temp[54];
    final_ciphertext[11] = final_cipher_temp[14];
    final_ciphertext[10] = final_cipher_temp[46];
    final_ciphertext[9] = final_cipher_temp[6];
    final_ciphertext[8] = final_cipher_temp[38];
    final_ciphertext[7] = final_cipher_temp[31];
    final_ciphertext[6] = final_cipher_temp[63];
    final_ciphertext[5] = final_cipher_temp[23];
    final_ciphertext[4] = final_cipher_temp[55];
    final_ciphertext[3] = final_cipher_temp[15];
    final_ciphertext[2] = final_cipher_temp[47];
    final_ciphertext[1] = final_cipher_temp[7];
    final_ciphertext[0] = final_cipher_temp[39];
    
end



////////// FSM ///////////
always @(*) begin
    case (state)
        IDLE: nxt_state = READ; //0
        READ: begin             //1
            nxt_state = state;
        end 
        default: nxt_state = state;
    endcase
end


assign enable_12 = (fn_sel == 1 || fn_sel == 2) ? 1 : 0;
assign enable_3  = (fn_sel == 3) ? 1 : 0;
assign enable_45 = (fn_sel == 4 || fn_sel == 5) ? 1 : 0;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        round_R <= 0;
        round_L <= 0;
        cipher_flag <= 0;      
    end
    else begin
        if (enable_12) begin
            round_R <= nxt_round_R;
            round_L <= nxt_round_L;
            cipher_flag <= nxt_cipher_flag;         
        end
        else begin
            round_R <= round_R;
            round_L <= round_L;
            cipher_flag <= cipher_flag;          
        end
    end
end
always @(posedge clk or posedge rst) begin
    if (rst) begin
        crc_flag <= 0;
    end
    else begin
        if (enable_3) begin
            crc_flag <= nxt_crc_flag;
        end
        else begin
            crc_flag <= crc_flag;
        end
    end
end
always @(posedge clk or posedge rst) begin
    if (rst) begin
        out_cnt <= 0;            
    end
    else begin
        if (enable_45) begin
            out_cnt <= nxt_out_cnt;
        end 
        else begin
            out_cnt <= out_cnt;          
        end       
    end
end
always @(posedge clk or posedge rst) begin
    if (rst) begin
        TOP_LAST_1 <= 0;
    end
    else begin
        if (fn4_enable_top_last_1) begin
            TOP_LAST_1 <= nxt_TOP_LAST_1;         
        end
        else begin
            TOP_LAST_1 <= TOP_LAST_1;          
        end
    end
end
always @(posedge clk or posedge rst) begin
    if (rst) begin
        TOP_LAST_2 <= 0;
    end
    else begin
        if (enable_top_last_2) begin
            TOP_LAST_2 <= nxt_TOP_LAST_2;            
        end
        else begin
            TOP_LAST_2 <= TOP_LAST_2;            
        end
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= 0;
        read_cnt <= 0;
        buffer <= 0;
        busy_out <= 1'b1;
        cmp_read_cnt <= 0;      
        read_flag <= 0;
    end
    else begin
        state <= nxt_state;
        read_cnt <= nxt_read_cnt;
        buffer <= nxt_buffer;
        busy_out <= nxt_busy_out;
        cmp_read_cnt <= nxt_cmp_read_cnt;
        read_flag <= nxt_read_flag;
    end
end
endmodule

module F_FUNCTION (R, L, K_in, f_out);
    input [31:0] R;    
    input [31:0] L;
    input [47:0] K_in;
    output [31:0] f_out;   
    
reg  [47:0] expansion;
wire [47:0] s_temp;
reg  [31:0] p_temp;
wire  [31:0] P_LUT;

always @(*) begin
    expansion[47] = R[0];
    expansion[46] = R[31];
    expansion[45] = R[30];
    expansion[44] = R[29];
    expansion[43] = R[28];
    expansion[42] = R[27];
    expansion[41] = R[28];
    expansion[40] = R[27];
    expansion[39] = R[26];
    expansion[38] = R[25];
    expansion[37] = R[24];
    expansion[36] = R[23];
    expansion[35] = R[24];
    expansion[34] = R[23];
    expansion[33] = R[22];
    expansion[32] = R[21];
    expansion[31] = R[20];
    expansion[30] = R[19];
    expansion[29] = R[20];
    expansion[28] = R[19];
    expansion[27] = R[18];
    expansion[26] = R[17];
    expansion[25] = R[16];
    expansion[24] = R[15];
    expansion[23] = R[16];
    expansion[22] = R[15];
    expansion[21] = R[14];
    expansion[20] = R[13];
    expansion[19] = R[12];
    expansion[18] = R[11];
    expansion[17] = R[12];
    expansion[16] = R[11];
    expansion[15] = R[10];
    expansion[14] = R[9];
    expansion[13] = R[8];
    expansion[12] = R[7];
    expansion[11] = R[8];
    expansion[10] = R[7];
    expansion[9]  = R[6];
    expansion[8]  = R[5];
    expansion[7]  = R[4];
    expansion[6]  = R[3];
    expansion[5]  = R[4];
    expansion[4]  = R[3];
    expansion[3]  = R[2];
    expansion[2]  = R[1];
    expansion[1]  = R[0];
    expansion[0]  = R[31];
end

assign s_temp = expansion ^ K_in;
///////////   S1   ///////
always @(*) begin
    case ({s_temp[47],s_temp[42]})
        2'b00:begin
            case (s_temp[46:43])
                4'b0000: p_temp[31:28] = 14;
                4'b0001: p_temp[31:28] = 4;
                4'b0010: p_temp[31:28] = 13;
                4'b0011: p_temp[31:28] = 1;
                4'b0100: p_temp[31:28] = 2;
                4'b0101: p_temp[31:28] = 15;
                4'b0110: p_temp[31:28] = 11;
                4'b0111: p_temp[31:28] = 8;
                4'b1000: p_temp[31:28] = 3;
                4'b1001: p_temp[31:28] = 10;
                4'b1010: p_temp[31:28] = 6;
                4'b1011: p_temp[31:28] = 12;
                4'b1100: p_temp[31:28] = 5;
                4'b1101: p_temp[31:28] = 9;
                4'b1110: p_temp[31:28] = 0;
                4'b1111: p_temp[31:28] = 7;
                default: p_temp[31:28] = 4; 
            endcase
        end 
        2'b01:begin
            case (s_temp[46:43])
                4'b0000: p_temp[31:28] = 0;
                4'b0001: p_temp[31:28] = 15;
                4'b0010: p_temp[31:28] = 7;
                4'b0011: p_temp[31:28] = 4;
                4'b0100: p_temp[31:28] = 14;
                4'b0101: p_temp[31:28] = 2;
                4'b0110: p_temp[31:28] = 13;
                4'b0111: p_temp[31:28] = 1;
                4'b1000: p_temp[31:28] = 10;
                4'b1001: p_temp[31:28] = 6;
                4'b1010: p_temp[31:28] = 12;
                4'b1011: p_temp[31:28] = 11;
                4'b1100: p_temp[31:28] = 9;
                4'b1101: p_temp[31:28] = 5;
                4'b1110: p_temp[31:28] = 3;
                4'b1111: p_temp[31:28] = 8;
                default: p_temp[31:28] = 0; 
            endcase
        end
        2'b10:begin
            case (s_temp[46:43])
                4'b0000: p_temp[31:28] = 4;
                4'b0001: p_temp[31:28] = 1;
                4'b0010: p_temp[31:28] = 14;
                4'b0011: p_temp[31:28] = 8;
                4'b0100: p_temp[31:28] = 13;
                4'b0101: p_temp[31:28] = 6;
                4'b0110: p_temp[31:28] = 2;
                4'b0111: p_temp[31:28] = 11;
                4'b1000: p_temp[31:28] = 15;
                4'b1001: p_temp[31:28] = 12;
                4'b1010: p_temp[31:28] = 9;
                4'b1011: p_temp[31:28] = 7;
                4'b1100: p_temp[31:28] = 3;
                4'b1101: p_temp[31:28] = 10;
                4'b1110: p_temp[31:28] = 5;
                4'b1111: p_temp[31:28] = 0;
                default: p_temp[31:28] = 0; 
            endcase
        end        
        2'b11:begin
            case (s_temp[46:43])
                4'b0000: p_temp[31:28] = 15;
                4'b0001: p_temp[31:28] = 12;
                4'b0010: p_temp[31:28] = 8;
                4'b0011: p_temp[31:28] = 2;
                4'b0100: p_temp[31:28] = 4;
                4'b0101: p_temp[31:28] = 9;
                4'b0110: p_temp[31:28] = 1;
                4'b0111: p_temp[31:28] = 7;
                4'b1000: p_temp[31:28] = 5;
                4'b1001: p_temp[31:28] = 11;
                4'b1010: p_temp[31:28] = 3;
                4'b1011: p_temp[31:28] = 14;
                4'b1100: p_temp[31:28] = 10;
                4'b1101: p_temp[31:28] = 0;
                4'b1110: p_temp[31:28] = 6;
                4'b1111: p_temp[31:28] = 13;
                default: p_temp[31:28] = 0; 
            endcase
        end        
        default: p_temp[31:28] = 0; 
    endcase
end
//////////////////  S2   ////////////////
always @(*) begin
    case ({s_temp[41],s_temp[36]})
        2'b00:begin
            case (s_temp[40:37])
                4'b0000: p_temp[27:24] = 15;
                4'b0001: p_temp[27:24] = 1 ;
                4'b0010: p_temp[27:24] = 8 ;
                4'b0011: p_temp[27:24] = 14;
                4'b0100: p_temp[27:24] = 6;
                4'b0101: p_temp[27:24] = 11;
                4'b0110: p_temp[27:24] = 3;
                4'b0111: p_temp[27:24] = 4;
                4'b1000: p_temp[27:24] = 9;
                4'b1001: p_temp[27:24] = 7;
                4'b1010: p_temp[27:24] = 2;
                4'b1011: p_temp[27:24] = 13;
                4'b1100: p_temp[27:24] = 12;
                4'b1101: p_temp[27:24] = 0;
                4'b1110: p_temp[27:24] = 5;
                4'b1111: p_temp[27:24] = 10;
                default: p_temp[27:24] = 0;
            endcase
        end 
        2'b01:begin
            case (s_temp[40:37])
                4'b0000: p_temp[27:24] = 3;
                4'b0001: p_temp[27:24] = 13;
                4'b0010: p_temp[27:24] = 4;
                4'b0011: p_temp[27:24] = 7;
                4'b0100: p_temp[27:24] = 15;
                4'b0101: p_temp[27:24] = 2;
                4'b0110: p_temp[27:24] = 8;
                4'b0111: p_temp[27:24] = 14;
                4'b1000: p_temp[27:24] = 12;
                4'b1001: p_temp[27:24] = 0;
                4'b1010: p_temp[27:24] = 1;
                4'b1011: p_temp[27:24] = 10;
                4'b1100: p_temp[27:24] = 6;
                4'b1101: p_temp[27:24] = 9;
                4'b1110: p_temp[27:24] = 11;
                4'b1111: p_temp[27:24] = 5;
                default: p_temp[27:24] = 0;
            endcase
        end
        2'b10:begin
            case (s_temp[40:37])
                4'b0000: p_temp[27:24] = 0;
                4'b0001: p_temp[27:24] = 14;
                4'b0010: p_temp[27:24] = 7;
                4'b0011: p_temp[27:24] = 11;
                4'b0100: p_temp[27:24] = 10;
                4'b0101: p_temp[27:24] = 4;
                4'b0110: p_temp[27:24] = 13;
                4'b0111: p_temp[27:24] = 1;
                4'b1000: p_temp[27:24] = 5;
                4'b1001: p_temp[27:24] = 8;
                4'b1010: p_temp[27:24] = 12;
                4'b1011: p_temp[27:24] = 6;
                4'b1100: p_temp[27:24] = 9;
                4'b1101: p_temp[27:24] = 3;
                4'b1110: p_temp[27:24] = 2;
                4'b1111: p_temp[27:24] = 15;
                default: p_temp[27:24] = 0;
            endcase
        end        
        2'b11:begin
            case (s_temp[40:37])
                4'b0000: p_temp[27:24] = 13;
                4'b0001: p_temp[27:24] = 8;
                4'b0010: p_temp[27:24] = 10;
                4'b0011: p_temp[27:24] = 1;
                4'b0100: p_temp[27:24] = 3;
                4'b0101: p_temp[27:24] = 15;
                4'b0110: p_temp[27:24] = 4;
                4'b0111: p_temp[27:24] = 2;
                4'b1000: p_temp[27:24] = 11;
                4'b1001: p_temp[27:24] = 6;
                4'b1010: p_temp[27:24] = 7;
                4'b1011: p_temp[27:24] = 12;
                4'b1100: p_temp[27:24] = 0;
                4'b1101: p_temp[27:24] = 5;
                4'b1110: p_temp[27:24] = 14;
                4'b1111: p_temp[27:24] = 9;
                default: p_temp[27:24] = 0;
            endcase
        end        
        default: p_temp[27:24] = 0; 
    endcase
end
//////////////   S3  ////////////
always @(*) begin
    case ({s_temp[35],s_temp[30]})
        2'b00:begin
            case (s_temp[34:31])
                4'b0000: p_temp[23:20] = 10;
                4'b0001: p_temp[23:20] = 0;
                4'b0010: p_temp[23:20] = 9;
                4'b0011: p_temp[23:20] = 14;
                4'b0100: p_temp[23:20] = 6;
                4'b0101: p_temp[23:20] = 3;
                4'b0110: p_temp[23:20] = 15;
                4'b0111: p_temp[23:20] = 5;
                4'b1000: p_temp[23:20] = 1;
                4'b1001: p_temp[23:20] = 13;
                4'b1010: p_temp[23:20] = 12;
                4'b1011: p_temp[23:20] = 7;
                4'b1100: p_temp[23:20] = 11;
                4'b1101: p_temp[23:20] = 4;
                4'b1110: p_temp[23:20] = 2;
                4'b1111: p_temp[23:20] = 8;
                default: p_temp[23:20] = 0;
            endcase
        end 
        2'b01:begin
            case (s_temp[34:31])
                4'b0000: p_temp[23:20] = 13;
                4'b0001: p_temp[23:20] = 7;
                4'b0010: p_temp[23:20] = 0;
                4'b0011: p_temp[23:20] = 9;
                4'b0100: p_temp[23:20] = 3;
                4'b0101: p_temp[23:20] = 4;
                4'b0110: p_temp[23:20] = 6;
                4'b0111: p_temp[23:20] = 10;
                4'b1000: p_temp[23:20] = 2;
                4'b1001: p_temp[23:20] = 8;
                4'b1010: p_temp[23:20] = 5;
                4'b1011: p_temp[23:20] = 14;
                4'b1100: p_temp[23:20] = 12;
                4'b1101: p_temp[23:20] = 11;
                4'b1110: p_temp[23:20] = 15;
                4'b1111: p_temp[23:20] = 1;
                default: p_temp[23:20] = 0;
            endcase
        end
        2'b10:begin
            case (s_temp[34:31])
                4'b0000: p_temp[23:20] = 13;
                4'b0001: p_temp[23:20] = 6;
                4'b0010: p_temp[23:20] = 4;
                4'b0011: p_temp[23:20] = 9;
                4'b0100: p_temp[23:20] = 8;
                4'b0101: p_temp[23:20] = 15;
                4'b0110: p_temp[23:20] = 3;
                4'b0111: p_temp[23:20] = 0;
                4'b1000: p_temp[23:20] = 11;
                4'b1001: p_temp[23:20] = 1;
                4'b1010: p_temp[23:20] = 2;
                4'b1011: p_temp[23:20] = 12;
                4'b1100: p_temp[23:20] = 5;
                4'b1101: p_temp[23:20] = 10;
                4'b1110: p_temp[23:20] = 14;
                4'b1111: p_temp[23:20] = 7;
                default: p_temp[23:20] = 0;
            endcase
        end        
        2'b11:begin
            case (s_temp[34:31])
                4'b0000: p_temp[23:20] = 1;
                4'b0001: p_temp[23:20] = 10;
                4'b0010: p_temp[23:20] = 13;
                4'b0011: p_temp[23:20] = 0;
                4'b0100: p_temp[23:20] = 6;
                4'b0101: p_temp[23:20] = 9;
                4'b0110: p_temp[23:20] = 8;
                4'b0111: p_temp[23:20] = 7;
                4'b1000: p_temp[23:20] = 4;
                4'b1001: p_temp[23:20] = 15;
                4'b1010: p_temp[23:20] = 14;
                4'b1011: p_temp[23:20] = 3;
                4'b1100: p_temp[23:20] = 11;
                4'b1101: p_temp[23:20] = 5;
                4'b1110: p_temp[23:20] = 2;
                4'b1111: p_temp[23:20] = 12;
                default: p_temp[23:20] = 0;
            endcase
        end        
        default: p_temp[23:20] = 0; 
    endcase
end
/////////////   S4   ///////////
always @(*) begin
    case ({s_temp[29],s_temp[24]})
        2'b00:begin
            case (s_temp[28:25])
                4'b0000: p_temp[19:16] = 7;
                4'b0001: p_temp[19:16] = 13;
                4'b0010: p_temp[19:16] = 14;
                4'b0011: p_temp[19:16] = 3;
                4'b0100: p_temp[19:16] = 0;
                4'b0101: p_temp[19:16] = 6;
                4'b0110: p_temp[19:16] = 9;
                4'b0111: p_temp[19:16] = 10;
                4'b1000: p_temp[19:16] = 1;
                4'b1001: p_temp[19:16] = 2;
                4'b1010: p_temp[19:16] = 8;
                4'b1011: p_temp[19:16] = 5;
                4'b1100: p_temp[19:16] = 11;
                4'b1101: p_temp[19:16] = 12;
                4'b1110: p_temp[19:16] = 4;
                4'b1111: p_temp[19:16] = 15;
                default: p_temp[19:16] = 0;
            endcase
        end 
        2'b01:begin
            case (s_temp[28:25])
                4'b0000: p_temp[19:16] = 13;
                4'b0001: p_temp[19:16] = 8;
                4'b0010: p_temp[19:16] = 11;
                4'b0011: p_temp[19:16] = 5;
                4'b0100: p_temp[19:16] = 6;
                4'b0101: p_temp[19:16] = 15;
                4'b0110: p_temp[19:16] = 0;
                4'b0111: p_temp[19:16] = 3;
                4'b1000: p_temp[19:16] = 4;
                4'b1001: p_temp[19:16] = 7;
                4'b1010: p_temp[19:16] = 2;
                4'b1011: p_temp[19:16] = 12;
                4'b1100: p_temp[19:16] = 1;
                4'b1101: p_temp[19:16] = 10;
                4'b1110: p_temp[19:16] = 14;
                4'b1111: p_temp[19:16] = 9;
                default: p_temp[19:16] = 0;
            endcase
        end
        2'b10:begin
            case (s_temp[28:25])
                4'b0000: p_temp[19:16] = 10;
                4'b0001: p_temp[19:16] = 6;
                4'b0010: p_temp[19:16] = 9;
                4'b0011: p_temp[19:16] = 0;
                4'b0100: p_temp[19:16] = 12;
                4'b0101: p_temp[19:16] = 11;
                4'b0110: p_temp[19:16] = 7;
                4'b0111: p_temp[19:16] = 13;
                4'b1000: p_temp[19:16] = 15;
                4'b1001: p_temp[19:16] = 1;
                4'b1010: p_temp[19:16] = 3;
                4'b1011: p_temp[19:16] = 14;
                4'b1100: p_temp[19:16] = 5;
                4'b1101: p_temp[19:16] = 2;
                4'b1110: p_temp[19:16] = 8;
                4'b1111: p_temp[19:16] = 4;
                default: p_temp[19:16] = 0;
            endcase
        end        
        2'b11:begin
            case (s_temp[28:25])
                4'b0000: p_temp[19:16] = 3;
                4'b0001: p_temp[19:16] = 15;
                4'b0010: p_temp[19:16] = 0;
                4'b0011: p_temp[19:16] = 6;
                4'b0100: p_temp[19:16] = 10;
                4'b0101: p_temp[19:16] = 1;
                4'b0110: p_temp[19:16] = 13;
                4'b0111: p_temp[19:16] = 8;
                4'b1000: p_temp[19:16] = 9;
                4'b1001: p_temp[19:16] = 4;
                4'b1010: p_temp[19:16] = 5;
                4'b1011: p_temp[19:16] = 11;
                4'b1100: p_temp[19:16] = 12;
                4'b1101: p_temp[19:16] = 7;
                4'b1110: p_temp[19:16] = 2;
                4'b1111: p_temp[19:16] = 14;
                default: p_temp[19:16] = 0;
            endcase
        end        
        default: p_temp[19:16] = 0; 
    endcase
end
//////////////////   S5    ////////////////////
always @(*) begin
    case ({s_temp[23],s_temp[18]})
        2'b00:begin
            case (s_temp[22:19])
                4'b0000: p_temp[15:12] = 2;
                4'b0001: p_temp[15:12] = 12;
                4'b0010: p_temp[15:12] = 4;
                4'b0011: p_temp[15:12] = 1;
                4'b0100: p_temp[15:12] = 7;
                4'b0101: p_temp[15:12] = 10;
                4'b0110: p_temp[15:12] = 11;
                4'b0111: p_temp[15:12] = 6;
                4'b1000: p_temp[15:12] = 8;
                4'b1001: p_temp[15:12] = 5;
                4'b1010: p_temp[15:12] = 3;
                4'b1011: p_temp[15:12] = 15;
                4'b1100: p_temp[15:12] = 13;
                4'b1101: p_temp[15:12] = 0;
                4'b1110: p_temp[15:12] = 14;
                4'b1111: p_temp[15:12] = 9;
                default: p_temp[15:12] = 0;
            endcase
        end 
        2'b01:begin
            case (s_temp[22:19])
                4'b0000: p_temp[15:12] = 14;
                4'b0001: p_temp[15:12] = 11;
                4'b0010: p_temp[15:12] = 2;
                4'b0011: p_temp[15:12] = 12;
                4'b0100: p_temp[15:12] = 4;
                4'b0101: p_temp[15:12] = 7;
                4'b0110: p_temp[15:12] = 13;
                4'b0111: p_temp[15:12] = 1;
                4'b1000: p_temp[15:12] = 5;
                4'b1001: p_temp[15:12] = 0;
                4'b1010: p_temp[15:12] = 15;
                4'b1011: p_temp[15:12] = 10;
                4'b1100: p_temp[15:12] = 3;
                4'b1101: p_temp[15:12] = 9;
                4'b1110: p_temp[15:12] = 8;
                4'b1111: p_temp[15:12] = 6;
                default: p_temp[15:12] = 0;
            endcase
        end
        2'b10:begin
            case (s_temp[22:19])
                4'b0000: p_temp[15:12] = 4;
                4'b0001: p_temp[15:12] = 2;
                4'b0010: p_temp[15:12] = 1;
                4'b0011: p_temp[15:12] = 11;
                4'b0100: p_temp[15:12] = 10;
                4'b0101: p_temp[15:12] = 13;
                4'b0110: p_temp[15:12] = 7;
                4'b0111: p_temp[15:12] = 8;
                4'b1000: p_temp[15:12] = 15;
                4'b1001: p_temp[15:12] = 9;
                4'b1010: p_temp[15:12] = 12;
                4'b1011: p_temp[15:12] = 5;
                4'b1100: p_temp[15:12] = 6;
                4'b1101: p_temp[15:12] = 3;
                4'b1110: p_temp[15:12] = 0;
                4'b1111: p_temp[15:12] = 14;
                default: p_temp[15:12] = 0;
            endcase
        end        
        2'b11:begin
            case (s_temp[22:19])
                4'b0000: p_temp[15:12] = 11;
                4'b0001: p_temp[15:12] = 8;
                4'b0010: p_temp[15:12] = 12;
                4'b0011: p_temp[15:12] = 7;
                4'b0100: p_temp[15:12] = 1;
                4'b0101: p_temp[15:12] = 14;
                4'b0110: p_temp[15:12] = 2;
                4'b0111: p_temp[15:12] = 13;
                4'b1000: p_temp[15:12] = 6;
                4'b1001: p_temp[15:12] = 15;
                4'b1010: p_temp[15:12] = 0;
                4'b1011: p_temp[15:12] = 9;
                4'b1100: p_temp[15:12] = 10;
                4'b1101: p_temp[15:12] = 4;
                4'b1110: p_temp[15:12] = 5;
                4'b1111: p_temp[15:12] = 3;
                default: p_temp[15:12] = 0;
            endcase
        end        
        default: p_temp[15:12] = 0; 
    endcase
end
////////////////////   S6    //////////////////////
always @(*) begin
    case ({s_temp[17],s_temp[12]})
        2'b00:begin
            case (s_temp[16:13])
                4'b0000: p_temp[11:8] = 12;
                4'b0001: p_temp[11:8] = 1;
                4'b0010: p_temp[11:8] = 10;
                4'b0011: p_temp[11:8] = 15;
                4'b0100: p_temp[11:8] = 9;
                4'b0101: p_temp[11:8] = 2;
                4'b0110: p_temp[11:8] = 6;
                4'b0111: p_temp[11:8] = 8;
                4'b1000: p_temp[11:8] = 0;
                4'b1001: p_temp[11:8] = 13;
                4'b1010: p_temp[11:8] = 3;
                4'b1011: p_temp[11:8] = 4;
                4'b1100: p_temp[11:8] = 14;
                4'b1101: p_temp[11:8] = 7;
                4'b1110: p_temp[11:8] = 5;
                4'b1111: p_temp[11:8] = 11;
                default: p_temp[11:8] = 0;
            endcase
        end 
        2'b01:begin
            case (s_temp[16:13])
                4'b0000: p_temp[11:8] = 10;
                4'b0001: p_temp[11:8] = 15;
                4'b0010: p_temp[11:8] = 4;
                4'b0011: p_temp[11:8] = 2;
                4'b0100: p_temp[11:8] = 7;
                4'b0101: p_temp[11:8] = 12;
                4'b0110: p_temp[11:8] = 9;
                4'b0111: p_temp[11:8] = 5;
                4'b1000: p_temp[11:8] = 6;
                4'b1001: p_temp[11:8] = 1;
                4'b1010: p_temp[11:8] = 13;
                4'b1011: p_temp[11:8] = 14;
                4'b1100: p_temp[11:8] = 0;
                4'b1101: p_temp[11:8] = 11;
                4'b1110: p_temp[11:8] = 3;
                4'b1111: p_temp[11:8] = 8;
                default: p_temp[11:8] = 0;
            endcase
        end
        2'b10:begin
            case (s_temp[16:13])
                4'b0000: p_temp[11:8] = 9;
                4'b0001: p_temp[11:8] = 14;
                4'b0010: p_temp[11:8] = 15;
                4'b0011: p_temp[11:8] = 5;
                4'b0100: p_temp[11:8] = 2;
                4'b0101: p_temp[11:8] = 8;
                4'b0110: p_temp[11:8] = 12;
                4'b0111: p_temp[11:8] = 3;
                4'b1000: p_temp[11:8] = 7;
                4'b1001: p_temp[11:8] = 0;
                4'b1010: p_temp[11:8] = 4;
                4'b1011: p_temp[11:8] = 10;
                4'b1100: p_temp[11:8] = 1;
                4'b1101: p_temp[11:8] = 13;
                4'b1110: p_temp[11:8] = 11;
                4'b1111: p_temp[11:8] = 6;
                default: p_temp[11:8] = 0;
            endcase
        end        
        2'b11:begin
            case (s_temp[16:13])
                4'b0000: p_temp[11:8] = 4;
                4'b0001: p_temp[11:8] = 3;
                4'b0010: p_temp[11:8] = 2;
                4'b0011: p_temp[11:8] = 12;
                4'b0100: p_temp[11:8] = 9;
                4'b0101: p_temp[11:8] = 5;
                4'b0110: p_temp[11:8] = 15;
                4'b0111: p_temp[11:8] = 10;
                4'b1000: p_temp[11:8] = 11;
                4'b1001: p_temp[11:8] = 14;
                4'b1010: p_temp[11:8] = 1;
                4'b1011: p_temp[11:8] = 7;
                4'b1100: p_temp[11:8] = 6;
                4'b1101: p_temp[11:8] = 0;
                4'b1110: p_temp[11:8] = 8;
                4'b1111: p_temp[11:8] = 13;
                default: p_temp[11:8] = 0;
            endcase
        end        
        default: p_temp[11:8] = 0; 
    endcase
end
///////////////   S7   //////////////
always @(*) begin
    case ({s_temp[11],s_temp[6]})
        2'b00:begin
            case (s_temp[10:7])
                4'b0000: p_temp[7:4] = 4;
                4'b0001: p_temp[7:4] = 11;
                4'b0010: p_temp[7:4] = 2;
                4'b0011: p_temp[7:4] = 14;
                4'b0100: p_temp[7:4] = 15;
                4'b0101: p_temp[7:4] = 0;
                4'b0110: p_temp[7:4] = 8;
                4'b0111: p_temp[7:4] = 13;
                4'b1000: p_temp[7:4] = 3;
                4'b1001: p_temp[7:4] = 12;
                4'b1010: p_temp[7:4] = 9;
                4'b1011: p_temp[7:4] = 7;
                4'b1100: p_temp[7:4] = 5;
                4'b1101: p_temp[7:4] = 10;
                4'b1110: p_temp[7:4] = 6;
                4'b1111: p_temp[7:4] = 1;
                default: p_temp[7:4] = 0;
            endcase
        end 
        2'b01:begin
            case (s_temp[10:7])
                4'b0000: p_temp[7:4] = 13;
                4'b0001: p_temp[7:4] = 0;
                4'b0010: p_temp[7:4] = 11;
                4'b0011: p_temp[7:4] = 7;
                4'b0100: p_temp[7:4] = 4;
                4'b0101: p_temp[7:4] = 9;
                4'b0110: p_temp[7:4] = 1;
                4'b0111: p_temp[7:4] = 10;
                4'b1000: p_temp[7:4] = 14;
                4'b1001: p_temp[7:4] = 3;
                4'b1010: p_temp[7:4] = 5;
                4'b1011: p_temp[7:4] = 12;
                4'b1100: p_temp[7:4] = 2;
                4'b1101: p_temp[7:4] = 15;
                4'b1110: p_temp[7:4] = 8;
                4'b1111: p_temp[7:4] = 6;
                default: p_temp[7:4] = 0;
            endcase
        end
        2'b10:begin
            case (s_temp[10:7])
                4'b0000: p_temp[7:4] = 1;
                4'b0001: p_temp[7:4] = 4;
                4'b0010: p_temp[7:4] = 11;
                4'b0011: p_temp[7:4] = 13;
                4'b0100: p_temp[7:4] = 12;
                4'b0101: p_temp[7:4] = 3;
                4'b0110: p_temp[7:4] = 7;
                4'b0111: p_temp[7:4] = 14;
                4'b1000: p_temp[7:4] = 10;
                4'b1001: p_temp[7:4] = 15;
                4'b1010: p_temp[7:4] = 6;
                4'b1011: p_temp[7:4] = 8;
                4'b1100: p_temp[7:4] = 0;
                4'b1101: p_temp[7:4] = 5;
                4'b1110: p_temp[7:4] = 9;
                4'b1111: p_temp[7:4] = 2;
                default: p_temp[7:4] = 0;
            endcase
        end        
        2'b11:begin
            case (s_temp[10:7])
                4'b0000: p_temp[7:4] = 6;
                4'b0001: p_temp[7:4] = 11;
                4'b0010: p_temp[7:4] = 13;
                4'b0011: p_temp[7:4] = 8;
                4'b0100: p_temp[7:4] = 1;
                4'b0101: p_temp[7:4] = 4;
                4'b0110: p_temp[7:4] = 10;
                4'b0111: p_temp[7:4] = 7;
                4'b1000: p_temp[7:4] = 9;
                4'b1001: p_temp[7:4] = 5;
                4'b1010: p_temp[7:4] = 0;
                4'b1011: p_temp[7:4] = 15;
                4'b1100: p_temp[7:4] = 14;
                4'b1101: p_temp[7:4] = 2;
                4'b1110: p_temp[7:4] = 3;
                4'b1111: p_temp[7:4] = 12;
                default: p_temp[7:4] = 0;
            endcase
        end        
        default: p_temp[7:4] = 0; 
    endcase
end
//////////////  S8   ////////////
always @(*) begin
    case ({s_temp[5],s_temp[0]})
        2'b00:begin
            case (s_temp[4:1])
                4'b0000: p_temp[3:0] = 13;
                4'b0001: p_temp[3:0] = 2;
                4'b0010: p_temp[3:0] = 8;
                4'b0011: p_temp[3:0] = 4;
                4'b0100: p_temp[3:0] = 6;
                4'b0101: p_temp[3:0] = 15;
                4'b0110: p_temp[3:0] = 11;
                4'b0111: p_temp[3:0] = 1;
                4'b1000: p_temp[3:0] = 10;
                4'b1001: p_temp[3:0] = 9;
                4'b1010: p_temp[3:0] = 3;
                4'b1011: p_temp[3:0] = 14;
                4'b1100: p_temp[3:0] = 5;
                4'b1101: p_temp[3:0] = 0;
                4'b1110: p_temp[3:0] = 12;
                4'b1111: p_temp[3:0] = 7;
                default: p_temp[3:0] = 0;
            endcase
        end 
        2'b01:begin
            case (s_temp[4:1])
                4'b0000: p_temp[3:0] = 1;
                4'b0001: p_temp[3:0] = 15;
                4'b0010: p_temp[3:0] = 13;
                4'b0011: p_temp[3:0] = 8;
                4'b0100: p_temp[3:0] = 10;
                4'b0101: p_temp[3:0] = 3;
                4'b0110: p_temp[3:0] = 7;
                4'b0111: p_temp[3:0] = 4;
                4'b1000: p_temp[3:0] = 12;
                4'b1001: p_temp[3:0] = 5;
                4'b1010: p_temp[3:0] = 6;
                4'b1011: p_temp[3:0] = 11;
                4'b1100: p_temp[3:0] = 0;
                4'b1101: p_temp[3:0] = 14;
                4'b1110: p_temp[3:0] = 9;
                4'b1111: p_temp[3:0] = 2;
                default: p_temp[3:0] = 0;
            endcase
        end
        2'b10:begin
            case (s_temp[4:1])
                4'b0000: p_temp[3:0] = 7;
                4'b0001: p_temp[3:0] = 11;
                4'b0010: p_temp[3:0] = 4;
                4'b0011: p_temp[3:0] = 1;
                4'b0100: p_temp[3:0] = 9;
                4'b0101: p_temp[3:0] = 12;
                4'b0110: p_temp[3:0] = 14;
                4'b0111: p_temp[3:0] = 2;
                4'b1000: p_temp[3:0] = 0;
                4'b1001: p_temp[3:0] = 6;
                4'b1010: p_temp[3:0] = 10;
                4'b1011: p_temp[3:0] = 13;
                4'b1100: p_temp[3:0] = 15;
                4'b1101: p_temp[3:0] = 3;
                4'b1110: p_temp[3:0] = 5;
                4'b1111: p_temp[3:0] = 8;
                default: p_temp[3:0] = 0;
            endcase
        end        
        2'b11:begin
            case (s_temp[4:1])
                4'b0000: p_temp[3:0] = 2;
                4'b0001: p_temp[3:0] = 1;
                4'b0010: p_temp[3:0] = 14;
                4'b0011: p_temp[3:0] = 7;
                4'b0100: p_temp[3:0] = 4;
                4'b0101: p_temp[3:0] = 10;
                4'b0110: p_temp[3:0] = 8;
                4'b0111: p_temp[3:0] = 13;
                4'b1000: p_temp[3:0] = 15;
                4'b1001: p_temp[3:0] = 12;
                4'b1010: p_temp[3:0] = 9;
                4'b1011: p_temp[3:0] = 0;
                4'b1100: p_temp[3:0] = 3;
                4'b1101: p_temp[3:0] = 5;
                4'b1110: p_temp[3:0] = 6;
                4'b1111: p_temp[3:0] = 11;
                default: p_temp[3:0] = 0;
            endcase
        end        
        default: p_temp[3:0] = 0; 
    endcase
end
    assign P_LUT[31] = p_temp[16];
    assign P_LUT[30] = p_temp[25];
    assign P_LUT[29] = p_temp[12];
    assign P_LUT[28] = p_temp[11];
    assign P_LUT[27] = p_temp[3];
    assign P_LUT[26] = p_temp[20];
    assign P_LUT[25] = p_temp[4];
    assign P_LUT[24] = p_temp[15];
    assign P_LUT[23] = p_temp[31];
    assign P_LUT[22] = p_temp[17];
    assign P_LUT[21] = p_temp[9];
    assign P_LUT[20] = p_temp[6];
    assign P_LUT[19] = p_temp[27];
    assign P_LUT[18] = p_temp[14];
    assign P_LUT[17] = p_temp[1];
    assign P_LUT[16] = p_temp[22];
    assign P_LUT[15] = p_temp[30];
    assign P_LUT[14] = p_temp[24];
    assign P_LUT[13] = p_temp[8];
    assign P_LUT[12] = p_temp[18];
    assign P_LUT[11] = p_temp[0];
    assign P_LUT[10] = p_temp[5];
    assign P_LUT[9]  = p_temp[29];
    assign P_LUT[8]  = p_temp[23];
    assign P_LUT[7]  = p_temp[13];
    assign P_LUT[6]  = p_temp[19];
    assign P_LUT[5]  = p_temp[2];
    assign P_LUT[4]  = p_temp[26];
    assign P_LUT[3]  = p_temp[10];
    assign P_LUT[2]  = p_temp[21];
    assign P_LUT[1]  = p_temp[28];
    assign P_LUT[0]  = p_temp[7];

assign f_out = P_LUT ^ L;

endmodule

module SUB_KEY (clk,rst, main_key, sub_key,rounds, encry_or_decry,fn_sel);
    input clk,rst;
    input [2:0] fn_sel;
    input [63:0] main_key;
    input encry_or_decry;
    input [4:0] rounds;
    output [47:0] sub_key;

/////////////////

wire [55:0] cyher_key;
reg [27:0] k_tmep_1, k_tmep_2, nxt_k_tmep_1, nxt_k_tmep_2;
wire [55:0] pc2_temp;
wire enable_key;

assign enable_key = (fn_sel == 1 || fn_sel == 2) ? 1 : 0;


assign cyher_key[55] = main_key[7];
assign cyher_key[54] = main_key[15];
assign cyher_key[53] = main_key[23];
assign cyher_key[52] = main_key[31];
assign cyher_key[51] = main_key[39];
assign cyher_key[50] = main_key[47];
assign cyher_key[49] = main_key[55];
assign cyher_key[48] = main_key[63];
assign cyher_key[47] = main_key[6];
assign cyher_key[46] = main_key[14];
assign cyher_key[45] = main_key[22];
assign cyher_key[44] = main_key[30];
assign cyher_key[43] = main_key[38];
assign cyher_key[42] = main_key[46];
assign cyher_key[41] = main_key[54];
assign cyher_key[40] = main_key[62];
assign cyher_key[39] = main_key[5];
assign cyher_key[38] = main_key[13];
assign cyher_key[37] = main_key[21];
assign cyher_key[36] = main_key[29];
assign cyher_key[35] = main_key[37];
assign cyher_key[34] = main_key[45];
assign cyher_key[33] = main_key[53];
assign cyher_key[32] = main_key[61];
assign cyher_key[31] = main_key[4];
assign cyher_key[30] = main_key[12];
assign cyher_key[29] = main_key[20];
assign cyher_key[28] = main_key[28];
assign cyher_key[27] = main_key[1];
assign cyher_key[26] = main_key[9];
assign cyher_key[25] = main_key[17];
assign cyher_key[24] = main_key[25];
assign cyher_key[23] = main_key[33];
assign cyher_key[22] = main_key[41];
assign cyher_key[21] = main_key[49];
assign cyher_key[20] = main_key[57];
assign cyher_key[19] = main_key[2];
assign cyher_key[18] = main_key[10];
assign cyher_key[17] = main_key[18];
assign cyher_key[16] = main_key[26];
assign cyher_key[15] = main_key[34];
assign cyher_key[14] = main_key[42];
assign cyher_key[13] = main_key[50];
assign cyher_key[12] = main_key[58];
assign cyher_key[11] = main_key[3];
assign cyher_key[10] = main_key[11];
assign cyher_key[9] = main_key[19];
assign cyher_key[8] = main_key[27];
assign cyher_key[7] = main_key[35];
assign cyher_key[6] = main_key[43];
assign cyher_key[5] = main_key[51];
assign cyher_key[4] = main_key[59];
assign cyher_key[3] = main_key[36];
assign cyher_key[2] = main_key[44];
assign cyher_key[1] = main_key[52];
assign cyher_key[0] = main_key[60];

always @(*) begin
    case (rounds)
        1:begin
            if (encry_or_decry) begin 
                nxt_k_tmep_1 = {cyher_key[26:0],cyher_key[27]};
                nxt_k_tmep_2 = {cyher_key[54:28],cyher_key[55]};
            end
            else begin       
                nxt_k_tmep_1 = cyher_key[27:0];
                nxt_k_tmep_2 = cyher_key[55:28];
            end
        end 
        2:begin
            if (encry_or_decry) begin
                nxt_k_tmep_1 = {cyher_key[25:0],cyher_key[27:26]}; 
                nxt_k_tmep_2 = {cyher_key[53:28],cyher_key[55:54]};                
            end
            else begin   
                nxt_k_tmep_1 = {cyher_key[0],cyher_key[27:1]}; 
                nxt_k_tmep_2 = {cyher_key[28],cyher_key[55:29]};                  
            end
        end
        3:begin  
            if (encry_or_decry) begin
                nxt_k_tmep_1 = {cyher_key[23:0],cyher_key[27:24]}; 
                nxt_k_tmep_2 = {cyher_key[51:28],cyher_key[55:52]};                        
            end
            else begin    
                nxt_k_tmep_1 = {cyher_key[2:0],cyher_key[27:3]}; 
                nxt_k_tmep_2 = {cyher_key[30:28],cyher_key[55:31]};                  
            end
        end
        4:begin 
            if (encry_or_decry) begin
                nxt_k_tmep_1 = {cyher_key[21:0],cyher_key[27:22]}; 
                nxt_k_tmep_2 = {cyher_key[49:28],cyher_key[55:50]};                        
            end  
            else begin    
                nxt_k_tmep_1 = {cyher_key[4:0],cyher_key[27:5]}; 
                nxt_k_tmep_2 = {cyher_key[32:28],cyher_key[55:33]};                  
            end          
        end
        5:begin  
            if (encry_or_decry) begin
                nxt_k_tmep_1 = {cyher_key[19:0],cyher_key[27:20]}; 
                nxt_k_tmep_2 = {cyher_key[47:28],cyher_key[55:48]};                        
            end   
            else begin    
                nxt_k_tmep_1 = {cyher_key[6:0],cyher_key[27:7]}; 
                nxt_k_tmep_2 = {cyher_key[34:28],cyher_key[55:35]};                  
            end                   
        end
        6:begin 
            if (encry_or_decry) begin
                nxt_k_tmep_1 = {cyher_key[17:0],cyher_key[27:18]}; 
                nxt_k_tmep_2 = {cyher_key[45:28],cyher_key[55:46]};                        
            end  
            else begin    
                nxt_k_tmep_1 = {cyher_key[8:0],cyher_key[27:9]}; 
                nxt_k_tmep_2 = {cyher_key[36:28],cyher_key[55:37]};                  
            end            
        end
        7:begin  
            if (encry_or_decry) begin
                nxt_k_tmep_1 = {cyher_key[15:0],cyher_key[27:16]};
                nxt_k_tmep_2 = {cyher_key[43:28],cyher_key[55:44]};                        
            end       
            else begin    
                nxt_k_tmep_1 = {cyher_key[10:0],cyher_key[27:11]}; 
                nxt_k_tmep_2 = {cyher_key[38:28],cyher_key[55:39]};                  
            end       
        end
        8:begin 
            if (encry_or_decry) begin
                nxt_k_tmep_1 = {cyher_key[13:0],cyher_key[27:14]}; 
                nxt_k_tmep_2 = {cyher_key[41:28],cyher_key[55:42]};                        
            end  
            else begin    
                nxt_k_tmep_1 = {cyher_key[12:0],cyher_key[27:13]}; 
                nxt_k_tmep_2 = {cyher_key[40:28],cyher_key[55:41]};                  
            end               
        end
        9:begin  
            if (encry_or_decry) begin
                nxt_k_tmep_1 = {cyher_key[12:0],cyher_key[27:13]}; 
                nxt_k_tmep_2 = {cyher_key[40:28],cyher_key[55:41]};                        
            end        
            else begin     
                nxt_k_tmep_1 = {cyher_key[13:0],cyher_key[27:14]}; 
                nxt_k_tmep_2 = {cyher_key[41:28],cyher_key[55:42]};                  
            end        
        end
        10:begin  
            if (encry_or_decry) begin
                nxt_k_tmep_1 = {cyher_key[10:0],cyher_key[27:11]}; 
                nxt_k_tmep_2 = {cyher_key[38:28],cyher_key[55:39]};                        
            end   
            else begin     
                nxt_k_tmep_1 = {cyher_key[15:0],cyher_key[27:16]}; 
                nxt_k_tmep_2 = {cyher_key[43:28],cyher_key[55:44]};                  
            end          
        end
        11:begin  
            if (encry_or_decry) begin
                nxt_k_tmep_1 = {cyher_key[8:0],cyher_key[27:9]}; 
                nxt_k_tmep_2 = {cyher_key[36:28],cyher_key[55:37]};                        
            end     
            else begin     
                nxt_k_tmep_1 = {cyher_key[17:0],cyher_key[27:18]}; 
                nxt_k_tmep_2 = {cyher_key[45:28],cyher_key[55:46]};                  
            end         
        end
        12:begin  
            if (encry_or_decry) begin
                nxt_k_tmep_1 = {cyher_key[6:0],cyher_key[27:7]}; 
                nxt_k_tmep_2 = {cyher_key[34:28],cyher_key[55:35]};                        
            end 
            else begin     
                nxt_k_tmep_1 = {cyher_key[19:0],cyher_key[27:20]}; 
                nxt_k_tmep_2 = {cyher_key[47:28],cyher_key[55:48]};                  
            end               
        end
        13:begin  
            if (encry_or_decry) begin
                nxt_k_tmep_1 = {cyher_key[4:0],cyher_key[27:5]}; 
                nxt_k_tmep_2 = {cyher_key[32:28],cyher_key[55:33]};                        
            end    
            else begin     
                nxt_k_tmep_1 = {cyher_key[21:0],cyher_key[27:22]}; 
                nxt_k_tmep_2 = {cyher_key[49:28],cyher_key[55:50]};                  
            end         
        end      
        14:begin  
            if (encry_or_decry) begin
                nxt_k_tmep_1 = {cyher_key[2:0],cyher_key[27:3]}; 
                nxt_k_tmep_2 = {cyher_key[30:28],cyher_key[55:31]};                        
            end  
            else begin     
                nxt_k_tmep_1 = {cyher_key[23:0],cyher_key[27:24]}; 
                nxt_k_tmep_2 = {cyher_key[51:28],cyher_key[55:52]};                  
            end             
        end   
        15:begin  
            if (encry_or_decry) begin
                nxt_k_tmep_1 = {cyher_key[0],cyher_key[27:1]}; 
                nxt_k_tmep_2 = {cyher_key[28],cyher_key[55:29]};                        
            end   
            else begin     
                nxt_k_tmep_1 = {cyher_key[25:0],cyher_key[27:26]}; 
                nxt_k_tmep_2 = {cyher_key[53:28],cyher_key[55:54]};                  
            end                
        end   
        0:begin
            if (encry_or_decry) begin
                nxt_k_tmep_1 = cyher_key[27:0];
                nxt_k_tmep_2 = cyher_key[55:28];                        
            end   
            else begin     
                nxt_k_tmep_1 = {cyher_key[26:0],cyher_key[27]}; 
                nxt_k_tmep_2 = {cyher_key[54:28],cyher_key[55]};                  
            end            
        end        
        default: begin
            nxt_k_tmep_1 = 28'b0; 
            nxt_k_tmep_2 = 28'b0;
        end
    endcase
end
assign pc2_temp = {k_tmep_2,k_tmep_1}; 

assign sub_key[47] = pc2_temp[42];
assign sub_key[46] = pc2_temp[39];
assign sub_key[45] = pc2_temp[45];
assign sub_key[44] = pc2_temp[32];
assign sub_key[43] = pc2_temp[55];
assign sub_key[42] = pc2_temp[51];
assign sub_key[41] = pc2_temp[53];
assign sub_key[40] = pc2_temp[28];
assign sub_key[39] = pc2_temp[41];
assign sub_key[38] = pc2_temp[50];
assign sub_key[37] = pc2_temp[35];
assign sub_key[36] = pc2_temp[46];
assign sub_key[35] = pc2_temp[33];
assign sub_key[34] = pc2_temp[37];
assign sub_key[33] = pc2_temp[44];
assign sub_key[32] = pc2_temp[52];
assign sub_key[31] = pc2_temp[30];
assign sub_key[30] = pc2_temp[48];
assign sub_key[29] = pc2_temp[40];
assign sub_key[28] = pc2_temp[49];
assign sub_key[27] = pc2_temp[29];
assign sub_key[26] = pc2_temp[36];
assign sub_key[25] = pc2_temp[43];
assign sub_key[24] = pc2_temp[54];
assign sub_key[23] = pc2_temp[15];
assign sub_key[22] = pc2_temp[4];
assign sub_key[21] = pc2_temp[25];
assign sub_key[20] = pc2_temp[19];
assign sub_key[19] = pc2_temp[9];
assign sub_key[18] = pc2_temp[1];
assign sub_key[17] = pc2_temp[26];
assign sub_key[16] = pc2_temp[16];
assign sub_key[15] = pc2_temp[5];
assign sub_key[14] = pc2_temp[11];
assign sub_key[13] = pc2_temp[23];
assign sub_key[12] = pc2_temp[8];
assign sub_key[11] = pc2_temp[12];
assign sub_key[10] = pc2_temp[7];
assign sub_key[9]  = pc2_temp[17];
assign sub_key[8]  = pc2_temp[0];
assign sub_key[7]  = pc2_temp[22];
assign sub_key[6]  = pc2_temp[3];
assign sub_key[5]  = pc2_temp[10];
assign sub_key[4]  = pc2_temp[14];
assign sub_key[3]  = pc2_temp[6];
assign sub_key[2]  = pc2_temp[20];
assign sub_key[1]  = pc2_temp[27];
assign sub_key[0]  = pc2_temp[24];

always @(posedge clk or posedge rst) begin
    if (rst) begin
        k_tmep_1 <= 0;
        k_tmep_2 <= 0;
    end
    else begin
        if (enable_key) begin
        k_tmep_1 <= nxt_k_tmep_1;
        k_tmep_2 <= nxt_k_tmep_2;           
        end
        else begin
        k_tmep_1 <= k_tmep_1;
        k_tmep_2 <= k_tmep_2;            
        end

    end
end
endmodule