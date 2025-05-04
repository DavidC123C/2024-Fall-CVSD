module alu #(
    parameter INST_W = 4,
    parameter INT_W  = 6,
    parameter FRAC_W = 10,
    parameter DATA_W = INT_W + FRAC_W
)(
    input                      i_clk,
    input                      i_rst_n,

    input                      i_in_valid,
    output                     o_busy,
    input         [INST_W-1:0] i_inst,
    input  signed [DATA_W-1:0] i_data_a,
    input  signed [DATA_W-1:0] i_data_b,

    output                     o_out_valid,
    output        [DATA_W-1:0] o_data
);

//////////FSM////////////
localparam IDLE = 3'b000;
localparam INPUT = 3'b001;
localparam COMPUTE = 3'b010;
localparam TEMP = 3'b011; 
localparam OUTPUT = 3'b100;
    // Wires and Regs
reg o_busy_in ;
reg out_valid_in;

reg signed [DATA_W-1:0] i_A, i_B, nxt_i_A, nxt_i_B;
reg [INST_W-1:0] inst, nxt_inst;
reg signed [DATA_W-1:0] out1, nxt_out1;
reg [2:0] state, nxt_state;
reg       busy, nxt_busy;
reg       valid, nxt_valid;
reg signed [DATA_W:0] add, sub;
reg signed [2*DATA_W-1 :0] mul, nxt_mul;
reg signed [22:0] mul_part, sat_mul;
reg signed [22:0] round_mul;
reg signed  [2*DATA_W - 1:0] left, part_left;
reg [DATA_W - 1:0] revermatch; 
reg signed [DATA_W+3:0] data_acc [0:DATA_W-1], nxt_data_acc [0:DATA_W-1];
reg signed [20:0] temp_data_acc;
wire [3:0] index ;
reg flag ;
reg signed [15:0] mul_temp;
reg signed [45:0] soft_mul;
reg signed [15:0] soft_test;
reg signed [15:0] soft_neg; 
reg [15:0] val16;
reg [7:0] val8;
reg [3:0] val4;
reg [4:0] result;




assign o_data = out1;
assign index  = i_A[3:0];  
assign o_busy = o_busy_in;
assign o_out_valid = out_valid_in;

    // Combinatorial Blocks
always @(*) begin
    if (state == COMPUTE) begin
        flag = 1'b1;
    end
    else flag = 1'b0;
end

/////FSM///////////
always @(*) begin
    case (state)
        IDLE:begin
            nxt_state = INPUT;
        end 
        INPUT:begin
            if (i_in_valid) begin
                nxt_state = COMPUTE;
            end
            else nxt_state = state;
        end
        COMPUTE:begin
            nxt_state = TEMP;
        end
        TEMP:begin
            nxt_state = OUTPUT;
        end
        OUTPUT:begin
            nxt_state = IDLE;
        end
        default: nxt_state = state;
    endcase
end
always @(*) begin
    case (state)
        INPUT:begin
        if (i_in_valid) begin
            nxt_i_A = i_data_a;
            nxt_i_B = i_data_b;
            nxt_inst = i_inst;
        end
        else begin
            nxt_i_A = i_A;
            nxt_i_B = i_B;
            nxt_inst = inst;
        end
        end 
        default: begin
            nxt_i_A = i_A;
            nxt_i_B = i_B;
            nxt_inst = inst;
        end
    endcase
end

always @(*) begin
    if (state == OUTPUT) begin
        out_valid_in = 1'b1;  
    end
    else out_valid_in = 1'b0;  
end


always @(*) begin
    if (state == INPUT) begin
        o_busy_in = 1'b0;
    end
    else o_busy_in = 1'b1;
end





integer i;
always @(*) begin
    for(i=0;i<DATA_W;i=i+1)begin
    nxt_data_acc[i] = data_acc[i];
    end

    case (inst)
        0: begin
            add = i_A + i_B;
            nxt_out1 = (!add[DATA_W] && add[DATA_W - 1]) ? 16'b0111_1111_1111_1111 :
                      (add[DATA_W] && !add[DATA_W - 1]) ? 16'b1000_0000_0000_0000 : add[DATA_W-1:0];
        end
        1:begin
            sub = i_A - i_B;
            nxt_out1 = (!sub[DATA_W] && sub[DATA_W - 1]) ?  16'b0111_1111_1111_1111 : 
                      (sub[DATA_W] && !sub[DATA_W - 1]) ?  16'b1000_0000_0000_0000 : sub[DATA_W-1:0];

        end
        2:begin
            mul = i_A*i_B;  
            mul_part = mul[2*DATA_W-1:9]; 
            if(mul_part[0] == 1'b1)begin
                round_mul = mul_part + 1'b1;
            end
            else begin
                round_mul = mul_part ;
            end

            sat_mul = (!round_mul[22] && (round_mul[21:11]> 11'b000_0001_1111)) ? 23'b011_1111_1111_1111_1111_1111 :  
                      (round_mul[22]  && (round_mul[21:11]< 11'b111_1110_0000)) ? 23'b100_0000_0000_0000_0000_0000 : round_mul;
            if ((sat_mul == 23'b011_1111_1111_1111_1111_1111) || (sat_mul == 23'b100_0000_0000_0000_0000_0000)) begin
                nxt_out1 = sat_mul[22:7];
            end
            else nxt_out1 = sat_mul[16:1];

        end
        3:begin
            if (flag == 1'b1) begin
            temp_data_acc = data_acc[index] + i_B;
            nxt_data_acc[index] = temp_data_acc[19:0]; 
            end
            else nxt_data_acc[index] = data_acc[index];
            
            nxt_out1 = (!data_acc[index][DATA_W+3] && (data_acc[index][19:10]>10'b00_0001_1111))? 16'b0111_1111_1111_1111 :
                       (data_acc[index][DATA_W+3]  && (data_acc[index][19:10]<10'b11_1110_0000)) ? 16'b1000_0000_0000_0000 : data_acc[index][DATA_W-1:0];
                                                                                                

        end
        4:begin  
            if(!i_A[DATA_W-1] &&  i_A[14:10]>=5'b00010) soft_mul = {6'b0,i_A,24'b0}; //x>=2
            else if (!i_A[DATA_W-1] && i_A[15:10]>=5'b0) begin  //0<x<2

                    soft_mul = ((i_A<<<1'b1) + 16'b0000_1000_0000_0000)*(30'b000000_01010101010101_0101_010101);
            end
            else if (i_A[15:10] == 6'b111111) begin   // -1<x<0
                soft_test = i_A + 16'b0000_1000_0000_0000;
                soft_mul = (soft_test)*(30'b000000_01010101010101_0101_010101);
            end
            else if (i_A[15:10] == 6'b111110) begin
                soft_neg = (i_A<<<1'b1) + 16'b0001_0100_0000_0000;
                soft_mul = soft_neg*(30'b000000_000111000111000111_000111);
            end
            else if (i_A[15:10] == 6'b111101) begin
                soft_neg = (i_A + 16'b0000_1100_0000_0000);
                soft_mul = soft_neg*(30'b000000_000111000111000111_000111);
            end
            else soft_mul = 46'b0;
            
            nxt_out1 = ((soft_mul != 46'b01_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111) || (soft_mul != 46'b10_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000)) && (soft_mul[23] == 1'b1)?
                      soft_mul[DATA_W+23:24] + 1'b1:
                      ((soft_mul != 46'b01_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111_1111) || (soft_mul != 46'b10_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000)) && (soft_mul[23] == 1'b0)?
                      soft_mul[DATA_W+23:24]:soft_mul[39:24];
                      

        end
        5:begin  //XOR
            nxt_out1 = i_A ^ i_B;
        end

        6:begin  //Arithmetic Right Shift
            nxt_out1 = i_A >>> i_B;
        end
        7:begin  // Left retation
            left = {i_A,i_A};
            part_left = left << i_B;
            nxt_out1 = part_left[2*DATA_W-1:DATA_W];
        end
        8:begin  //Count Leading Zero
            result[4] = (i_A[15:0] == 16'b0) ? 1 : 0;
            val16     = (result[4]) ? 16'b1111_1111_1111_1111 : i_A;
            result[3] = (val16[15:8] == 8'b0) ? 1 : 0;
            val8      = (result[3]) ? val16[7:0] : val16[15:8];
            result[2] = (val8[7:4] == 4'b0) ? 1 : 0;
            val4      = (result[2]) ? val8[3:0] : val8[7:4];
            result[1] = (val4[3:2] == 2'b0) ? 1 : 0;
            result[0] = (result[1]) ? ~val4[1] : ~val4[3];
            nxt_out1 = {11'b0,result};
        end

        9:begin  //Reverse Match 4
            nxt_out1[0] = (i_A[3:0] == i_B[15:12])  ? 1'b1 : 1'b0;
            nxt_out1[1] = (i_A[4:1] == i_B[14:11])  ? 1'b1 : 1'b0;
            nxt_out1[2] = (i_A[5:2] == i_B[13:10])  ? 1'b1 : 1'b0;
            nxt_out1[3] = (i_A[6:3] == i_B[12:9])   ? 1'b1 : 1'b0;
            nxt_out1[4] = (i_A[7:4] == i_B[11:8])   ? 1'b1 : 1'b0;
            nxt_out1[5] = (i_A[8:5] == i_B[10:7])   ? 1'b1 : 1'b0;
            nxt_out1[6] = (i_A[9:6] == i_B[9:6])    ? 1'b1 : 1'b0;
            nxt_out1[7] = (i_A[10:7] == i_B[8:5])   ? 1'b1 : 1'b0;
            nxt_out1[8] = (i_A[11:8] == i_B[7:4])   ? 1'b1 : 1'b0;
            nxt_out1[9] = (i_A[12:9] == i_B[6:3])   ? 1'b1 : 1'b0;
            nxt_out1[10] = (i_A[13:10] == i_B[5:2]) ? 1'b1 : 1'b0;
            nxt_out1[11] = (i_A[14:11] == i_B[4:1]) ? 1'b1 : 1'b0;
            nxt_out1[12] = (i_A[15:12] == i_B[3:0]) ? 1'b1 : 1'b0;
            nxt_out1[15:13] = 3'b000;
            end

        default: begin 
            nxt_out1 = out1;
        end

    endcase
end


    // Sequential Blocks
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            out1 <= 0;
            i_A <= 0;
            i_B <= 0;
            state <= 0;
            inst <= 0;
            for ( i=0 ;i<DATA_W ;i=i+1) begin
                data_acc[i] <= 0;
            end
            
        end
        else begin
            out1 <= nxt_out1;
            i_A <= nxt_i_A;
            i_B <= nxt_i_B;
            state <= nxt_state;
            inst <= nxt_inst;
            for ( i=0 ;i<DATA_W ;i=i+1) begin
                data_acc[i] <= nxt_data_acc[i];
            end
        end
    end


endmodule
