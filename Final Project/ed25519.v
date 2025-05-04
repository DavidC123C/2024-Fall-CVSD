module ed25519 (
	input i_clk,
	input i_rst,
	input i_in_valid,
	output o_in_ready,
	input [63:0]  i_in_data,
	output o_out_valid,
	input i_out_ready,
	output [63:0] o_out_data
);

parameter para_d = 255'h 52036cee2b6ffe738cc740797779e89800700a4d4141d8ab75eb4dca135978a3;
parameter q = 255'd 57896044618658097711785492504343953926634992332820282019728792003956564819949; 
parameter q_1 = 255'd 57896044618658097711785492504343953926634992332820282019728792003956564819948; 
parameter q_inv = 255'h 2f286bca1af286bca1af286bca1af286bca1af286bca1af286bca1af286bca1b;
parameter R2 = 361;
parameter R3 = 6859;
parameter R4 = 130321;
parameter RZ = 255'd 37589973457545958193355601;

localparam  IDLE=2'd0, LOAD = 2'd1, COMPUTE = 2'd2 ,OUTPUT = 2'd3;

reg o_in_ready_w,o_in_ready_r;
reg [63:0]o_out_data_w,o_out_data_r;
reg [2:0]IO_w,IO_r;

reg [1:0] state_w,state_r;
reg [255:0] M_w,M_r;
reg [254:0] X_w,X_r;
reg [254:0] Y_w,Y_r;
reg [254:0] r_X_w,r_X_r;
reg [254:0] r_Y_w,r_Y_r;
reg [254:0] r_Z_w,r_Z_r;
reg [7:0]cnt_w,cnt_r;
reg [7:0]loop_w,loop_r;
reg Plus_P_w,Plus_P_r;

reg [254:0] P2_x_w,P2_x_r,P2_y_w,P2_y_r,P2_z_w,P2_z_r;
reg [254:0] P3_x_w,P3_x_r,P3_y_w,P3_y_r,P3_z_w,P3_z_r;
reg [254:0] P4_x_w,P4_x_r,P4_y_w,P4_y_r,P4_z_w,P4_z_r;
reg [254:0] P5_x_w,P5_x_r,P5_y_w,P5_y_r,P5_z_w,P5_z_r;
reg [254:0] P6_x_w,P6_x_r,P6_y_w,P6_y_r,P6_z_w,P6_z_r;
reg [254:0] P7_x_w,P7_x_r,P7_y_w,P7_y_r,P7_z_w,P7_z_r;
reg [254:0] P8_x_w,P8_x_r,P8_y_w,P8_y_r,P8_z_w,P8_z_r;
reg [254:0] P9_x_w,P9_x_r,P9_y_w,P9_y_r,P9_z_w,P9_z_r;
reg [254:0] P10_x_w,P10_x_r,P10_y_w,P10_y_r,P10_z_w,P10_z_r;
reg [254:0] P11_x_w,P11_x_r,P11_y_w,P11_y_r,P11_z_w,P11_z_r;
reg [254:0] P12_x_w,P12_x_r,P12_y_w,P12_y_r,P12_z_w,P12_z_r;
reg [254:0] P13_x_w,P13_x_r,P13_y_w,P13_y_r,P13_z_w,P13_z_r;
reg [254:0] P14_x_w,P14_x_r,P14_y_w,P14_y_r,P14_z_w,P14_z_r;
reg [254:0] P15_x_w,P15_x_r,P15_y_w,P15_y_r,P15_z_w,P15_z_r;


/*         MM 計算用的reg         */
reg [254:0]A_w,A_r;
reg [254:0]B_w,B_r;
reg [254:0]C_w,C_r;
reg [254:0]D_w,D_r;
reg [254:0]E_w,E_r;
reg [254:0]F_w,F_r;
reg [254:0]G_w,G_r;
reg [254:0]H_w,H_r;
reg [254:0]I_w,I_r;
/*         MM 計算用的reg         */

/*         MM module 用的 wire、reg 及 instance 的乘法器         */
// input output 用的
wire [254:0]mul_out_up_wire;
wire [254:0]mul_out_down_wire;
wire [254:0]modq_plus_out;
wire [509:0]MM1_mul_xy;
wire [254:0]MM_X_in1,MM_X_in2;
wire [254:0]MM_Y_in1,MM_Y_in2;
wire [254:0]MM_Z_in1,MM_Z_in2;

reg [254:0]MM1_mul_in1_w,MM1_mul_in1_r;
reg [254:0]MM1_mul_in2_w,MM1_mul_in2_r;
reg [509:0]MM1_mul_xy_1_w,MM1_mul_xy_1_r;
reg [509:0]MM1_mul_xy_2_w,MM1_mul_xy_2_r;
reg [509:0]MM1_mul_xy_3_w,MM1_mul_xy_3_r;

reg [254:0]MM_modq_plus_255_in1_w,MM_modq_plus_255_in1_r;
reg [254:0]MM_modq_plus_255_in2_w,MM_modq_plus_255_in2_r;
reg [254:0]MM_modq_minus_255_in1_w,MM_modq_minus_255_in1_r;
reg [254:0]MM_modq_minus_255_in2_w,MM_modq_minus_255_in2_r;
reg [254:0]Plus_reg1_w,Plus_reg1_r;
reg [254:0]Plus_reg2_w,Plus_reg2_r;
wire [254:0]MM_modq_plus_255_out;
wire [254:0]MM_modq_minus_255_out;

assign o_in_ready = o_in_ready_r;

assign o_out_valid = ((loop_r > 22) && (cnt_r == 255) && i_out_ready && (state_r == 3) ) ? 1'b1 : 1'b0;

assign o_out_data = (cnt_r == 255 && state_r == OUTPUT)?
					(IO_r[2]==0)?(|IO_r[1:0] == 0)? {1'b0,r_X_r[254 -: 63]} : r_X_r[254 -: 64]
					:(|IO_r[1:0] == 0)? {1'b0,r_Y_r[254 -: 63]} : r_Y_r[254 -: 64]
					:64'b0;



assign MM_X_in1 = (state_r == COMPUTE)? r_X_r
					:(cnt_r == 12 )?  X_r
					:(cnt_r == 13 )?  P2_x_r  
					:(cnt_r == 14 )?  P3_x_r
					:(cnt_r == 15 )?  P4_x_r
					:(cnt_r == 16 )?  P5_x_r 
					:(cnt_r == 17 )?  P6_x_r 
					:(cnt_r == 18 )?  P7_x_r 
					:(cnt_r == 19 )?  P8_x_r 
					:(cnt_r == 20 )?  P9_x_r 
					:(cnt_r == 21 )?  P10_x_r 
					:(cnt_r == 22 )?  P11_x_r 
					:(cnt_r == 23 )?  P12_x_r 
					:(cnt_r == 24 )?  P13_x_r : P14_x_r ;

assign MM_X_in2 = (state_r == LOAD)?  X_r :
					(state_r == COMPUTE)? (~Plus_P_r)? r_X_r:
					(M_r[255 -: 4] == 0)? 0 :
					(M_r[255 -: 4] == 1)? X_r :
					(M_r[255 -: 4] == 2)? P2_x_r :
					(M_r[255 -: 4] == 3)? P3_x_r :
					(M_r[255 -: 4] == 4)? P4_x_r :
					(M_r[255 -: 4] == 5)? P5_x_r :
					(M_r[255 -: 4] == 6)? P6_x_r :
					(M_r[255 -: 4] == 7)? P7_x_r :
					(M_r[255 -: 4] == 8)? P8_x_r :
					(M_r[255 -: 4] == 9)? P9_x_r :
					(M_r[255 -: 4] == 10)? P10_x_r :
					(M_r[255 -: 4] == 11)? P11_x_r :
					(M_r[255 -: 4] == 12)? P12_x_r :
					(M_r[255 -: 4] == 13)? P13_x_r :
					(M_r[255 -: 4] == 14)? P14_x_r : P15_x_r : X_r;

assign MM_Y_in1 = (state_r == COMPUTE)?r_Y_r
					:(cnt_r == 12 )?  Y_r
					:(cnt_r == 13 )?  P2_y_r  
					:(cnt_r == 14 )?  P3_y_r
					:(cnt_r == 15 )?  P4_y_r
					:(cnt_r == 16 )?  P5_y_r 
					:(cnt_r == 17 )?  P6_y_r 
					:(cnt_r == 18 )?  P7_y_r 
					:(cnt_r == 19 )?  P8_y_r 
					:(cnt_r == 20 )?  P9_y_r 
					:(cnt_r == 21 )?  P10_y_r 
					:(cnt_r == 22 )?  P11_y_r 
					:(cnt_r == 23 )?  P12_y_r 
					:(cnt_r == 24 )?  P13_y_r : P14_y_r ;

assign MM_Y_in2 = (state_r == LOAD)?  Y_r :
					(state_r == COMPUTE)? (~Plus_P_r)? r_Y_r:
					(M_r[255 -: 4] == 0)? 1 :
					(M_r[255 -: 4] == 1)? Y_r :
					(M_r[255 -: 4] == 2)? P2_y_r :
					(M_r[255 -: 4] == 3)? P3_y_r :
					(M_r[255 -: 4] == 4)? P4_y_r :
					(M_r[255 -: 4] == 5)? P5_y_r :
					(M_r[255 -: 4] == 6)? P6_y_r :
					(M_r[255 -: 4] == 7)? P7_y_r :
					(M_r[255 -: 4] == 8)? P8_y_r :
					(M_r[255 -: 4] == 9)? P9_y_r :
					(M_r[255 -: 4] == 10)? P10_y_r :
					(M_r[255 -: 4] == 11)? P11_y_r :
					(M_r[255 -: 4] == 12)? P12_y_r :
					(M_r[255 -: 4] == 13)? P13_y_r :
					(M_r[255 -: 4] == 14)? P14_y_r : P15_y_r : Y_r;

assign MM_Z_in1 = (state_r == COMPUTE)?r_Z_r
					:(cnt_r == 12 )?  1
					:(cnt_r == 13 )?  P2_z_r  
					:(cnt_r == 14 )?  P3_z_r
					:(cnt_r == 15 )?  P4_z_r
					:(cnt_r == 16 )?  P5_z_r 
					:(cnt_r == 17 )?  P6_z_r 
					:(cnt_r == 18 )?  P7_z_r 
					:(cnt_r == 19 )?  P8_z_r 
					:(cnt_r == 20 )?  P9_z_r 
					:(cnt_r == 21 )?  P10_z_r 
					:(cnt_r == 22 )?  P11_z_r 
					:(cnt_r == 23 )?  P12_z_r 
					:(cnt_r == 24 )?  P13_z_r : P14_z_r ;

assign MM_Z_in2 = (state_r == LOAD)?  1 :
					(state_r == COMPUTE)? (~Plus_P_r)? r_Z_r:
					(M_r[255 -: 4] == 0)? 1 :
					(M_r[255 -: 4] == 1)? 1 :
					(M_r[255 -: 4] == 2)? P2_z_r :
					(M_r[255 -: 4] == 3)? P3_z_r :
					(M_r[255 -: 4] == 4)? P4_z_r :
					(M_r[255 -: 4] == 5)? P5_z_r :
					(M_r[255 -: 4] == 6)? P6_z_r :
					(M_r[255 -: 4] == 7)? P7_z_r :
					(M_r[255 -: 4] == 8)? P8_z_r :
					(M_r[255 -: 4] == 9)? P9_z_r :
					(M_r[255 -: 4] == 10)? P10_z_r :
					(M_r[255 -: 4] == 11)? P11_z_r :
					(M_r[255 -: 4] == 12)? P12_z_r :
					(M_r[255 -: 4] == 13)? P13_z_r :
					(M_r[255 -: 4] == 14)? P14_z_r : P15_z_r : 1;


wire [254:0]output1_wire,output2_wire;


DW02_mult_3_stage #(255, 255) mul_3stage ( .A(MM1_mul_in1_r), .B(MM1_mul_in2_r), .TC(1'b0), .CLK(i_clk), .PRODUCT({mul_out_up_wire,mul_out_down_wire}) );


modq_510_plus_stage1 add_510_plus_stage1(.in1(MM1_mul_xy),.in2({mul_out_up_wire,mul_out_down_wire}),.out1(output1_wire),.out2(output2_wire));
modq_510_plus_stage2 add_510_plus_stage2(.in1(Plus_reg1_r),.in2(Plus_reg2_r),.out_up(modq_plus_out));

modq_255_plus MM_255_modq_plus (.in1(MM_modq_plus_255_in1_r),.in2(MM_modq_plus_255_in2_r),.out(MM_modq_plus_255_out));
modq_255_minus MM_255_modq_minus(.in1(MM_modq_minus_255_in1_r),.in2(MM_modq_minus_255_in2_r),.out(MM_modq_minus_255_out));

assign MM1_mul_xy = (state_r == COMPUTE && ~Plus_P_r)?
					(loop_r == 9 || loop_r == 19 || loop_r == 29 || loop_r == 40 || loop_r == 50)? MM1_mul_xy_1_r 
					:(loop_r == 10 || loop_r == 20 || loop_r == 30 || loop_r == 41 || loop_r == 51)? MM1_mul_xy_2_r : MM1_mul_xy_3_r
					:(loop_r == 9 || loop_r == 19 || loop_r == 29 || loop_r == 39 || loop_r == 52 || loop_r == 62 || loop_r == 72)? MM1_mul_xy_1_r 
					:(loop_r == 10 || loop_r == 20 || loop_r == 30 || loop_r == 40 || loop_r == 50 || loop_r == 63 || loop_r == 73)? MM1_mul_xy_2_r : MM1_mul_xy_3_r;




//FSM
always @(*) begin
	case(state_r)
		IDLE:begin
			state_w = LOAD;	
		end
		LOAD:begin
			state_w = (cnt_r == 25 && loop_r == 75)? COMPUTE : LOAD ;
		end
		COMPUTE:begin
			state_w = (cnt_r == 255 && loop_r == 75 && Plus_P_r)? OUTPUT : COMPUTE ;
		end
		OUTPUT:begin
			state_w = state_r;
		end
		default:begin
			state_w = state_r;
		end
	endcase
end

//Plus_P
always@(*)begin
	Plus_P_w = Plus_P_r ;
	if(state_r == IDLE)begin
		Plus_P_w = 0;
	end
	else if(state_r == LOAD && cnt_r ==25 && loop_r == 75)begin
		Plus_P_w = 1;
	end
	else if(state_r == COMPUTE)begin
		// Plus_P_w = ~Plus_P_r;
		if(cnt_r == 0 || (cnt_r[1:0] == 2'b11 && loop_r == 75 && Plus_P_r))begin
			Plus_P_w = 0;
		end
		else if(cnt_r[1:0] == 2'b11 && loop_r == 53 && ~Plus_P_r)begin
			Plus_P_w = 1;
		end
	end
end

// comb for cnt
always @(*) begin
	case (state_r)
		IDLE: begin
			cnt_w = 0;
		end
		LOAD: begin
			if(cnt_r <= 11)begin
				if( i_in_valid && o_in_ready)begin
					cnt_w = cnt_r + 1;
				end
				else cnt_w = cnt_r;
			end
			else begin
				if( loop_r == 75)begin
					cnt_w = (cnt_r == 25)? 0 : cnt_r + 1;
				end
				else cnt_w = cnt_r;
			end			
		end
		COMPUTE:begin
			if(cnt_r == 0)begin
				cnt_w = 4;
			end
			else if(cnt_r[1:0] == 2'b11 && loop_r == 75 && Plus_P_r)begin
				cnt_w = (cnt_r == 255)? 0 : cnt_r + 1 ; 
			end
			else if(cnt_r[1:0] != 2'b11)begin
				cnt_w = (loop_r == 53)?  cnt_r + 1 : cnt_r ; 
			end
			else cnt_w = cnt_r;			
		end
		OUTPUT: begin
			if(cnt_r == 0 || cnt_r == 250 || cnt_r == 252)begin
				cnt_w =(loop_r == 10)? cnt_r + 1 : cnt_r ; 
			end
			else if(cnt_r == 255)begin
				cnt_w = cnt_r;
			end
			else begin
				cnt_w =(loop_r == 20)? cnt_r + 1 : cnt_r ; 
			end			
		end
		default: begin
			cnt_w = cnt_r;
		end
	endcase
end

// comb for loop
always@(*)begin
	//loop_w = loop_r;
	if(state_r == IDLE)begin
		loop_w = 0;
	end
	else if(state_r == LOAD)begin
		if(cnt_r > 11)begin
			loop_w = ( loop_r == 75 )? (cnt_r == 25)? 75 : 0 : loop_r + 1 ;
		end
		else loop_w = loop_r;
	end
	else if(state_r == COMPUTE)begin
		if(Plus_P_r)begin
			loop_w = ( loop_r == 75 )? 0 : loop_r + 1 ;
		end
		else begin
			loop_w = ( loop_r == 53 )? 0 : loop_r + 1 ;
		end
	end
	else if(state_r == OUTPUT)begin
		if(cnt_r == 0 || cnt_r == 250 || cnt_r == 252)begin
			loop_w = (loop_r == 10)? 1 : loop_r + 1; 
		end
		else if(cnt_r == 255)begin
			loop_w = ( loop_r < 23 )? loop_r + 1 : loop_r;
		end
		else begin
			loop_w = (loop_r == 20)? 1 : loop_r + 1; 
		end
	end
end

// comb for M
always@(*)begin
	M_w = M_r;
	if(state_r == LOAD)begin
		if( i_in_valid && (cnt_r == 0 || cnt_r == 1 || cnt_r == 2 || cnt_r == 3) )begin
			M_w = {M_r[0 +: 192] , i_in_data};
		end
		else begin
			M_w = M_r;
		end
	end
	else if(state_r == COMPUTE)begin
		M_w = (Plus_P_r && loop_r == 75)? M_r << 4 : M_r ;
	end
end

// comb for X
always@(*)begin
	X_w = X_r;
	if(state_r == LOAD)begin
		if( i_in_valid && (cnt_r == 4 || cnt_r == 5 || cnt_r == 6 || cnt_r == 7) )begin
			X_w = {X_r[0 +: 191] , i_in_data};
		end
	end
end

// comb for Y
always@(*)begin
	Y_w = Y_r;
	if(state_r == LOAD)begin
		if( i_in_valid && (cnt_r == 8 || cnt_r == 9 || cnt_r == 10 || cnt_r == 11) )begin
			Y_w = {Y_r[0 +: 191] , i_in_data};
		end
	end
end

// comb for r_X
always@(*)begin
	r_X_w = r_X_r;
	if(state_r == IDLE)begin
		r_X_w = 0;
	end
	else if(state_r == COMPUTE && Plus_P_r)begin
		if(cnt_r == 0)begin
			r_X_w = (M_r[255 -: 4] == 0)? 0 :
					(M_r[255 -: 4] == 1)? X_r :
					(M_r[255 -: 4] == 2)? P2_x_r :
					(M_r[255 -: 4] == 3)? P3_x_r :
					(M_r[255 -: 4] == 4)? P4_x_r :
					(M_r[255 -: 4] == 5)? P5_x_r :
					(M_r[255 -: 4] == 6)? P6_x_r :
					(M_r[255 -: 4] == 7)? P7_x_r :
					(M_r[255 -: 4] == 8)? P8_x_r :
					(M_r[255 -: 4] == 9)? P9_x_r :
					(M_r[255 -: 4] == 10)? P10_x_r :
					(M_r[255 -: 4] == 11)? P11_x_r :
					(M_r[255 -: 4] == 12)? P12_x_r :
					(M_r[255 -: 4] == 13)? P13_x_r :
					(M_r[255 -: 4] == 14)? P14_x_r : P15_x_r;
		end
		else if(loop_r == 73)begin
			r_X_w = modq_plus_out;
		end
	end
	else if(state_r == COMPUTE && ~Plus_P_r && loop_r == 53)begin
		r_X_w = modq_plus_out;
	end 
	else if(state_r == OUTPUT)begin
		if(cnt_r == 255)begin
			if(loop_r == 20)begin
				r_X_w = modq_plus_out;
			end
			else if(loop_r == 21 && r_X_r[0])begin
				r_X_w = q - r_X_r;
			end
			else if(loop_r == 23 && i_out_ready && o_out_valid)begin
				if(IO_r[2] == 0)begin
					r_X_w = (|IO_r[1:0] == 0)? r_X_r << 63 : r_X_r << 64;
				end
			end
		end
	end
end

// comb for r_Y
always@(*)begin
	r_Y_w = r_Y_r;
	if(state_r == IDLE)begin
		r_Y_w = 1;
	end
	else if(state_r == COMPUTE && Plus_P_r)begin
		if(cnt_r == 0)begin
			r_Y_w = (M_r[255 -: 4] == 0)? 1 :
					(M_r[255 -: 4] == 1)? Y_r :
					(M_r[255 -: 4] == 2)? P2_y_r :
					(M_r[255 -: 4] == 3)? P3_y_r :
					(M_r[255 -: 4] == 4)? P4_y_r :
					(M_r[255 -: 4] == 5)? P5_y_r :
					(M_r[255 -: 4] == 6)? P6_y_r :
					(M_r[255 -: 4] == 7)? P7_y_r :
					(M_r[255 -: 4] == 8)? P8_y_r :
					(M_r[255 -: 4] == 9)? P9_y_r :
					(M_r[255 -: 4] == 10)? P10_y_r :
					(M_r[255 -: 4] == 11)? P11_y_r :
					(M_r[255 -: 4] == 12)? P12_y_r :
					(M_r[255 -: 4] == 13)? P13_y_r :
					(M_r[255 -: 4] == 14)? P14_y_r : P15_y_r;
		end
		else if(loop_r == 75)begin
			r_Y_w = modq_plus_out;
		end
	end
	else if(state_r == COMPUTE && ~Plus_P_r && loop_r == 52)begin
		r_Y_w = modq_plus_out;
	end 
	else if(state_r == OUTPUT)begin
		if(cnt_r == 255)begin
			if(loop_r == 21)begin
				r_Y_w = modq_plus_out;
			end
			else if(loop_r == 22 && r_Y_r[0])begin
				r_Y_w = q - r_Y_r;
			end
			else if(loop_r == 23 && i_out_ready && o_out_valid)begin
				if(IO_r[2] == 1) begin
					r_Y_w = (|IO_r[1:0] == 0)? r_Y_r << 63 : r_Y_r << 64;
				end
			end
		end
	end
end

// comb for r_Z
always@(*)begin
	r_Z_w = r_Z_r;
	if(state_r == IDLE)begin
		r_Z_w = 1;
	end
	else if(state_r == COMPUTE && Plus_P_r)begin
		if(cnt_r == 0)begin
			r_Z_w = (M_r[255 -: 4] == 0)? 1 :
					(M_r[255 -: 4] == 1)? 1 :
					(M_r[255 -: 4] == 2)? P2_z_r :
					(M_r[255 -: 4] == 3)? P3_z_r :
					(M_r[255 -: 4] == 4)? P4_z_r :
					(M_r[255 -: 4] == 5)? P5_z_r :
					(M_r[255 -: 4] == 6)? P6_z_r :
					(M_r[255 -: 4] == 7)? P7_z_r :
					(M_r[255 -: 4] == 8)? P8_z_r :
					(M_r[255 -: 4] == 9)? P9_z_r :
					(M_r[255 -: 4] == 10)? P10_z_r :
					(M_r[255 -: 4] == 11)? P11_z_r :
					(M_r[255 -: 4] == 12)? P12_z_r :
					(M_r[255 -: 4] == 13)? P13_z_r :
					(M_r[255 -: 4] == 14)? P14_z_r : P15_z_r;
		end
		else if(loop_r == 74)begin
			r_Z_w = modq_plus_out;
		end
	end
	else if(state_r == COMPUTE && ~Plus_P_r && loop_r == 51)begin
		r_Z_w = modq_plus_out;
	end
end


//o_in_ready
always@(*)begin
	o_in_ready_w = o_in_ready_r;
	if(state_r == LOAD)begin
		if(cnt_r < 11 || (cnt_r == 11 && ~i_in_valid) )begin
			o_in_ready_w = 1;
		end
		else begin
			o_in_ready_w = 0;
		end
	end
end
//IO 
always@(*)begin
	if((state_r == 3) && i_out_ready && (loop_r > 22))begin
		IO_w = IO_r + 1;
	end
	else IO_w = IO_r;
end

always@(*)begin
	MM1_mul_in1_w = MM1_mul_in1_r;
	MM1_mul_in2_w = MM1_mul_in2_r;
	if(state_r == LOAD || (state_r == COMPUTE && Plus_P_r )|| state_r == OUTPUT)begin
		case(loop_r)
			0:begin
				if(state_r == OUTPUT)begin
					MM1_mul_in1_w = 255'h 2f286bca1af286bca1af286bca1af286bca1af286bca1af286bca1af286bca14;
					MM1_mul_in2_w = r_Z_r;
				end
				else begin
					MM1_mul_in1_w = MM_X_in1;
					MM1_mul_in2_w = MM_X_in2;
				end
			end
			1:begin
				MM1_mul_in1_w = (state_r == OUTPUT && cnt_r == 255)? A_r : MM_Y_in1;
				MM1_mul_in2_w = (state_r == OUTPUT && cnt_r == 255)? r_Y_r : MM_Y_in2;
			end
			2:begin
				MM1_mul_in1_w = MM_Z_in1;
				MM1_mul_in2_w = MM_Z_in2;
			end
			20:begin
				if(state_r == OUTPUT)begin
					if(cnt_r == 254)begin
						MM1_mul_in1_w = modq_plus_out;
						MM1_mul_in2_w = r_X_r;
					end
					else begin
						MM1_mul_in1_w = modq_plus_out;
						MM1_mul_in2_w = modq_plus_out;
					end
				end
				else begin
					MM1_mul_in1_w = B_r;
					MM1_mul_in2_w = H_r;
				end
			end
			21:begin
				MM1_mul_in1_w = C_r;
				MM1_mul_in2_w = para_d;
			end
			22:begin
				MM1_mul_in1_w = modq_plus_out;
				MM1_mul_in2_w = modq_plus_out;
			end
			31:begin
				MM1_mul_in1_w = modq_plus_out;
				MM1_mul_in2_w = D_r;
			end
			41:begin
				MM1_mul_in1_w = modq_plus_out;
				MM1_mul_in2_w = R3;
			end
			43:begin
				MM1_mul_in1_w = A_r;
				MM1_mul_in2_w = H_r;
			end
			45:begin
				MM1_mul_in1_w = A_r;
				MM1_mul_in2_w = C_r;
			end
			53:begin
				//A*(H-C-D)
				MM1_mul_in1_w = modq_plus_out;
				MM1_mul_in2_w = R3;
			end
			54:begin
				//Z=F*G 
				MM1_mul_in1_w = F_r;
				MM1_mul_in2_w = G_r;
			end
			55:begin
				//A*C*G
				MM1_mul_in1_w = modq_plus_out;
				MM1_mul_in2_w = G_r;
			end
			63:begin
				//A*(H)*F
				MM1_mul_in1_w = modq_plus_out;
				MM1_mul_in2_w = F_r;
			end
			65:begin
				//A*(H)*F*R3
				MM1_mul_in1_w = modq_plus_out;
				MM1_mul_in2_w = R3;
			end
			3,4,5,13,14,15,23,24,25,33,34,35,44,48,46,56,57,58,66,67,68:begin
				MM1_mul_in1_w = mul_out_down_wire;
				MM1_mul_in2_w = q_inv;
			end
			6,7,8,16,17,18,26,27,28,36,37,38,47,49,51,59,60,61,69,70,71:begin
				MM1_mul_in1_w = mul_out_down_wire;
				MM1_mul_in2_w = q;
			end
			10,11,12,30,32,64:begin
				MM1_mul_in1_w = modq_plus_out;
				if(state_r == OUTPUT)begin
					if(cnt_r==0 || cnt_r == 250 || cnt_r ==252)begin
						MM1_mul_in2_w = modq_plus_out;
					end
					else if(cnt_r == 255) begin
						MM1_mul_in2_w = RZ;
					end
					else begin
						MM1_mul_in2_w = r_Z_r;
					end
				end
				else begin
					MM1_mul_in2_w = R2;
				end
			
			end
			
		endcase
	end
	else if(state_r == COMPUTE && ~Plus_P_r )begin
		case(loop_r)
			0:begin
				MM1_mul_in1_w = r_X_r;
				MM1_mul_in2_w = r_X_r;
			end
			1:begin
				MM1_mul_in1_w = r_Y_r;
				MM1_mul_in2_w = r_Y_r;
			end
			2:begin
				MM1_mul_in1_w = r_Z_r;
				MM1_mul_in2_w = r_Z_r;
			end

			20:begin
				MM1_mul_in1_w = q_1;
				MM1_mul_in2_w = modq_plus_out;
			end

			21:begin
				MM1_mul_in1_w = I_r;
				MM1_mul_in2_w = I_r;
			end

			22:begin
				MM1_mul_in1_w = 2;
				MM1_mul_in2_w = modq_plus_out;
			end

			31:begin
				MM1_mul_in1_w = MM_modq_plus_255_out;
				MM1_mul_in2_w = R4;
			end
			32:begin
				MM1_mul_in1_w = C_r;
				MM1_mul_in2_w = R4;
			end
			33:begin
				MM1_mul_in1_w = MM_modq_minus_255_out;
				MM1_mul_in2_w = R4;
			end

			41:begin
				MM1_mul_in1_w = modq_plus_out;
				MM1_mul_in2_w =C_r;
			end
			42:begin
				MM1_mul_in1_w = modq_plus_out;
				MM1_mul_in2_w = G_r;
			end
			43:begin
				MM1_mul_in1_w = modq_plus_out;
				MM1_mul_in2_w = C_r;
			end

			3,4,5,13,14,15,23,24,25,34,35,36,44,45,46:begin
				MM1_mul_in1_w = mul_out_down_wire;
				MM1_mul_in2_w = q_inv;
			end
			6,7,8,16,17,18,26,27,28,37,38,39,47,48,49:begin
				MM1_mul_in1_w = mul_out_down_wire;
				MM1_mul_in2_w = q;
			end

			11:begin
				MM1_mul_in1_w = r_X_r;
				MM1_mul_in2_w = r_Y_r;
			end
			10,12:begin
				MM1_mul_in1_w = modq_plus_out;
				MM1_mul_in2_w = R2;
			end
			
		endcase
	end
end

//MM1_mul_xy
always@(*)begin
	MM1_mul_xy_1_w = MM1_mul_xy_1_r;
	MM1_mul_xy_2_w = MM1_mul_xy_2_r;
	MM1_mul_xy_3_w = MM1_mul_xy_3_r;
	if(state_r == LOAD || (state_r == COMPUTE && Plus_P_r )|| state_r == OUTPUT)begin
		case(loop_r)
			3,13,23,33,46,56,66:begin
				MM1_mul_xy_1_w = { mul_out_up_wire,mul_out_down_wire };
			end
			4,14,24,34,44,57,67:begin
				MM1_mul_xy_2_w = { mul_out_up_wire,mul_out_down_wire };
			end
			5,15,25,35,48,58,68:begin
				MM1_mul_xy_3_w = { mul_out_up_wire,mul_out_down_wire };
			end
		endcase
	end
	else if(state_r == COMPUTE && ~Plus_P_r )begin
		case(loop_r)
			3,13,23,34,44:begin
				MM1_mul_xy_1_w = { mul_out_up_wire,mul_out_down_wire };
			end
			4,14,24,35,45:begin
				MM1_mul_xy_2_w = { mul_out_up_wire,mul_out_down_wire };
			end
			5,15,25,36,46:begin
				MM1_mul_xy_3_w = { mul_out_up_wire,mul_out_down_wire };
			end
		endcase
	end
end

//Plus_reg
always@(*)begin
	Plus_reg1_w = output1_wire;
	Plus_reg2_w = output2_wire;
end

always@(*)begin
	A_w = A_r;
	if(state_r == LOAD || (state_r == COMPUTE && Plus_P_r))begin
		if(loop_r == 22)begin
			A_w = modq_plus_out;
		end
	end
	else if(state_r == COMPUTE && ~Plus_P_r)begin
		if(loop_r == 10)begin
			A_w = modq_plus_out;
		end
		else if(loop_r == 28)begin
			A_w = MM_modq_plus_255_out;
		end
	end
	else if(state_r == OUTPUT)begin
		if(loop_r == 10 || loop_r == 20)begin
			A_w = modq_plus_out;
		end
	end
end

//B
always@(*)begin
	B_w = B_r;
	if(state_r == LOAD || (state_r == COMPUTE && Plus_P_r))begin
		if( loop_r == 42)begin
			B_w = modq_plus_out;
		end
		else if(loop_r == 6)begin
			B_w = MM_modq_plus_255_out;
		end
	end
	else if(state_r == COMPUTE && ~Plus_P_r)begin
		if(loop_r == 11)begin
			B_w = modq_plus_out;
		end
	end
end

//C
always@(*)begin
	C_w = C_r;
	if(state_r == LOAD || (state_r == COMPUTE && Plus_P_r))begin
		if(loop_r == 20)begin
			C_w = modq_plus_out;
		end
		else if(loop_r == 41)begin
			C_w = MM_modq_plus_255_out;
		end
	end
	else if(state_r == COMPUTE && ~Plus_P_r)begin
		if(loop_r == 12)begin
			C_w = modq_plus_out;
		end
		else if(state_r == COMPUTE && ~Plus_P_r)begin
			if(loop_r == 31)begin
				C_w = MM_modq_plus_255_out;
			end
			else if(loop_r == 38)begin
				C_w = MM_modq_minus_255_out;
			end
		end
	end
end

//D
always@(*)begin
	D_w = D_r;
	if(state_r == LOAD || (state_r == COMPUTE && Plus_P_r))begin
		if(loop_r == 21)begin
			D_w = modq_plus_out;
		end
	end
	else if(state_r == COMPUTE && ~Plus_P_r)begin
		if(loop_r == 20)begin
			D_w = modq_plus_out;
		end
	end
end

//E
always@(*)begin
	E_w = E_r;
	if(state_r == LOAD || (state_r == COMPUTE && Plus_P_r))begin
		if(loop_r == 31 ||loop_r == 41 || loop_r == 51)begin
			E_w = modq_plus_out;
		end
	end
	else if(state_r == COMPUTE && ~Plus_P_r)begin
		if(loop_r == 21)begin
			E_w = modq_plus_out;
		end
	end
end

//F
always@(*)begin
	F_w = F_r;
	if(state_r == LOAD || (state_r == COMPUTE && Plus_P_r))begin
		if(loop_r == 53)begin
			F_w = MM_modq_minus_255_out;
		end
	end
	else if(state_r == COMPUTE && ~Plus_P_r)begin
		if(loop_r == 22)begin
			F_w = modq_plus_out;
		end
	end
end

//G
always@(*)begin
	G_w = G_r;
	if(state_r == LOAD || (state_r == COMPUTE && Plus_P_r))begin
		if(loop_r == 53)begin
			G_w = MM_modq_plus_255_out;
		end
	end
	else if(state_r == COMPUTE && ~Plus_P_r)begin
		if(loop_r == 30)begin
			G_w = modq_plus_out;
		end
		else if(loop_r == 39)begin
			G_w = MM_modq_minus_255_out;
		end
	end
end

//H
always@(*)begin
	H_w = H_r;
	if(state_r == LOAD || (state_r == COMPUTE && Plus_P_r))begin
		if(loop_r == 40)begin
			H_w = modq_plus_out;
		end
		else if(loop_r == 7)begin
			H_w = MM_modq_plus_255_out;
		end
		else if(loop_r == 42)begin
			H_w = MM_modq_minus_255_out;
		end
	end
	else if(state_r == COMPUTE && ~Plus_P_r)begin
		if(loop_r == 32)begin
			H_w = modq_plus_out;
		end
	end
end

//I
always@(*)begin
	I_w = I_r;
	if(state_r == COMPUTE && ~Plus_P_r)begin
		if(loop_r == 6)begin
			I_w = MM_modq_plus_255_out;
		end
		else if(loop_r == 31)begin
			I_w = modq_plus_out;
		end
		else if(loop_r == 33)begin
			I_w = MM_modq_minus_255_out;
		end
	end
end

//MM_modq_plus_255
always@(*)begin
	MM_modq_plus_255_in1_w = MM_modq_plus_255_in1_r;
	MM_modq_plus_255_in2_w = MM_modq_plus_255_in2_r;
	if(state_r == LOAD || (state_r == COMPUTE && Plus_P_r))begin
		if(loop_r == 40)begin
			//C = C + D
			MM_modq_plus_255_in1_w = C_r;
			MM_modq_plus_255_in2_w = D_r;
		end
		else if(loop_r == 52)begin
			// G = B + E
			MM_modq_plus_255_in1_w = B_r;
			MM_modq_plus_255_in2_w = E_r;
		end
		else if(loop_r == 5)begin
				//求(self.X + self.Y) 
			MM_modq_plus_255_in1_w = MM_X_in1;//self.X
			MM_modq_plus_255_in2_w = MM_Y_in1;
		end
		else if(loop_r == 6)begin
			//求(other.X + other.Y)
			MM_modq_plus_255_in1_w = MM_X_in2;//other.X
			MM_modq_plus_255_in2_w = MM_Y_in2;
		end
	end
	else if(state_r == COMPUTE && ~Plus_P_r)begin
		if(loop_r == 5)begin
			MM_modq_plus_255_in1_w = r_X_r;//other.X
			MM_modq_plus_255_in2_w = r_Y_r;
		end
		else if(loop_r == 27)begin
			MM_modq_plus_255_in1_w = A_r;//other.X
			MM_modq_plus_255_in2_w = B_r;
		end
		else if(loop_r == 30)begin
			MM_modq_plus_255_in1_w = modq_plus_out;//other.X
			MM_modq_plus_255_in2_w = B_r;
		end
	end
end

//MM_modq_minus_255
always@(*)begin
	MM_modq_minus_255_in1_w = MM_modq_minus_255_in1_r;
	MM_modq_minus_255_in2_w = MM_modq_minus_255_in2_r;
	if(state_r == LOAD || (state_r == COMPUTE && Plus_P_r))begin
		if(loop_r == 41)begin
			//H = H - C
			MM_modq_minus_255_in1_w = H_r;
			MM_modq_minus_255_in2_w = MM_modq_plus_255_out;
		end
		else if(loop_r == 52)begin
			// F = B - E
			MM_modq_minus_255_in1_w = B_r;
			MM_modq_minus_255_in2_w = E_r;
		end
	end
	else if((state_r == COMPUTE && ~Plus_P_r))begin
		if(loop_r == 32)begin
			MM_modq_minus_255_in1_w = I_r;
			MM_modq_minus_255_in2_w = A_r;
		end
		else if(loop_r == 37)begin
			MM_modq_minus_255_in1_w = C_r;
			MM_modq_minus_255_in2_w = H_r;
		end
		else if(loop_r == 38)begin
			MM_modq_minus_255_in1_w = G_r;
			MM_modq_minus_255_in2_w = B_r;
		end
	end
end

/*           MM module 的運算               */

//window 2P ~ 15P
always@(*)begin
	P2_x_w = P2_x_r;    P2_y_w = P2_y_r;    P2_z_w = P2_z_r;
	P3_x_w = P3_x_r;    P3_y_w = P3_y_r;    P3_z_w = P3_z_r;
	P4_x_w = P4_x_r;    P4_y_w = P4_y_r;    P4_z_w = P4_z_r;
	P5_x_w = P5_x_r;    P5_y_w = P5_y_r;    P5_z_w = P5_z_r;
	P6_x_w = P6_x_r;    P6_y_w = P6_y_r;    P6_z_w = P6_z_r;
	P7_x_w = P7_x_r;    P7_y_w = P7_y_r;    P7_z_w = P7_z_r;
	P8_x_w = P8_x_r;    P8_y_w = P8_y_r;    P8_z_w = P8_z_r;
	P9_x_w = P9_x_r;    P9_y_w = P9_y_r;    P9_z_w = P9_z_r;
	P10_x_w = P10_x_r;  P10_y_w = P10_y_r;  P10_z_w = P10_z_r;
	P11_x_w = P11_x_r;  P11_y_w = P11_y_r;  P11_z_w = P11_z_r;
	P12_x_w = P12_x_r;  P12_y_w = P12_y_r;  P12_z_w = P12_z_r;
	P13_x_w = P13_x_r;  P13_y_w = P13_y_r;  P13_z_w = P13_z_r;
	P14_x_w = P14_x_r;  P14_y_w = P14_y_r;  P14_z_w = P14_z_r;
	P15_x_w = P15_x_r;  P15_y_w = P15_y_r;  P15_z_w = P15_z_r;

	if(state_r == LOAD)begin
		case(cnt_r)
			12: begin
				if(loop_r == 73) begin
					P2_x_w = modq_plus_out;
				end
				if(loop_r == 74) begin
					P2_z_w = modq_plus_out;
				end
				if(loop_r == 75) begin
					P2_y_w = modq_plus_out;
				end
			end
			13: begin
				if(loop_r == 73) begin
					P3_x_w = modq_plus_out;
				end
				if(loop_r == 74) begin
					P3_z_w = modq_plus_out;
				end
				if(loop_r == 75) begin
					P3_y_w = modq_plus_out;
				end
			end
			14: begin
				if(loop_r == 73) begin
					P4_x_w = modq_plus_out;
				end
				if(loop_r == 74) begin
					P4_z_w = modq_plus_out;
				end
				if(loop_r == 75) begin
					P4_y_w = modq_plus_out;
				end
			end
			15: begin
				if(loop_r == 73) begin
					P5_x_w = modq_plus_out;
				end
				if(loop_r == 74) begin
					P5_z_w = modq_plus_out;
				end
				if(loop_r == 75) begin
					P5_y_w = modq_plus_out;
				end
			end
			16: begin
				if(loop_r == 73) begin
					P6_x_w = modq_plus_out;
				end
				if(loop_r == 74) begin
					P6_z_w = modq_plus_out;
				end
				if(loop_r == 75) begin
					P6_y_w = modq_plus_out;
				end
			end
			17: begin
				if(loop_r == 73) begin
					P7_x_w = modq_plus_out;
				end
				if(loop_r == 74) begin
					P7_z_w = modq_plus_out;
				end
				if(loop_r == 75) begin
					P7_y_w = modq_plus_out;
				end
			end
			18: begin
				if(loop_r == 73) begin
					P8_x_w = modq_plus_out;
				end
				if(loop_r == 74) begin
					P8_z_w = modq_plus_out;
				end
				if(loop_r == 75) begin
					P8_y_w = modq_plus_out;
				end
			end
			19: begin
				if(loop_r == 73) begin
					P9_x_w = modq_plus_out;
				end
				if(loop_r == 74) begin
					P9_z_w = modq_plus_out;
				end
				if(loop_r == 75) begin
					P9_y_w = modq_plus_out;
				end
			end
			20: begin
				if(loop_r == 73) begin
					P10_x_w = modq_plus_out;
				end
				if(loop_r == 74) begin
					P10_z_w = modq_plus_out;
				end
				if(loop_r == 75) begin
					P10_y_w = modq_plus_out;
				end
			end
			21: begin
				if(loop_r == 73) begin
					P11_x_w = modq_plus_out;
				end
				if(loop_r == 74) begin
					P11_z_w = modq_plus_out;
				end
				if(loop_r == 75) begin
					P11_y_w = modq_plus_out;
				end
			end
			22: begin
				if(loop_r == 73) begin
					P12_x_w = modq_plus_out;
				end
				if(loop_r == 74) begin
					P12_z_w = modq_plus_out;
				end
				if(loop_r == 75) begin
					P12_y_w = modq_plus_out;
				end
			end
			23: begin
				if(loop_r == 73) begin
					P13_x_w = modq_plus_out;
				end
				if(loop_r == 74) begin
					P13_z_w = modq_plus_out;
				end
				if(loop_r == 75) begin
					P13_y_w = modq_plus_out;
				end
			end
			24: begin
				if(loop_r == 73) begin
					P14_x_w = modq_plus_out;
				end
				if(loop_r == 74) begin
					P14_z_w = modq_plus_out;
				end
				if(loop_r == 75) begin
					P14_y_w = modq_plus_out;
				end
			end
			25: begin
				if(loop_r == 73) begin
					P15_x_w = modq_plus_out;
				end
				if(loop_r == 74) begin
					P15_z_w = modq_plus_out;
				end
				if(loop_r == 75) begin
					P15_y_w = modq_plus_out;
				end
			end
		endcase
	end
end

always @(posedge i_clk)begin
	if(i_rst)begin
		state_r <= IDLE;
		o_in_ready_r <= 0;
		IO_r <= 0;
		cnt_r <= 0;
		loop_r <= 0;
		M_r <= 0;
		X_r <= 0;
		Y_r <= 0;
		r_X_r <= 0;
		r_Y_r <= 0;
		r_Z_r <= 0;
		
		MM1_mul_in1_r <= 0;
		MM1_mul_in2_r <= 0;
		MM1_mul_xy_1_r <= 0;
		MM1_mul_xy_2_r <= 0;
		MM1_mul_xy_3_r <= 0;
		A_r <= 0;
		B_r <= 0;
		C_r <= 0;
		D_r <= 0;
		E_r <= 0;
		F_r <= 0;
		G_r <= 0;
		H_r <= 0;
		I_r <= 0;
		MM_modq_plus_255_in1_r <= 0;
		MM_modq_plus_255_in2_r <= 0;
		MM_modq_minus_255_in1_r <= 0;
		MM_modq_minus_255_in2_r <= 0;

		P2_x_r <= 0;	P2_y_r <= 0;	P2_z_r <= 0;
		P3_x_r <= 0;	P3_y_r <= 0;	P3_z_r <= 0;
		P4_x_r <= 0;	P4_y_r <= 0;	P4_z_r <= 0;
		P5_x_r <= 0;	P5_y_r <= 0;	P5_z_r <= 0;
		P6_x_r <= 0;	P6_y_r <= 0;	P6_z_r <= 0;
		P7_x_r <= 0;	P7_y_r <= 0;	P7_z_r <= 0;
		P8_x_r <= 0;	P8_y_r <= 0;	P8_z_r <= 0;
		P9_x_r <= 0;	P9_y_r <= 0;	P9_z_r <= 0;
		P10_x_r <= 0;	P10_y_r <= 0;	P10_z_r <= 0;
		P11_x_r <= 0;	P11_y_r <= 0;	P11_z_r <= 0;
		P12_x_r <= 0;	P12_y_r <= 0;	P12_z_r <= 0;
		P13_x_r <= 0;	P13_y_r <= 0;	P13_z_r <= 0;
		P14_x_r <= 0;	P14_y_r <= 0;	P14_z_r <= 0;
		P15_x_r <= 0;	P15_y_r <= 0;	P15_z_r <= 0;

		Plus_P_r <= 0;
		
		Plus_reg1_r <= 0;
		Plus_reg2_r <= 0;
	end
	else begin
		state_r <= state_w;
		o_in_ready_r <= o_in_ready_w;
		IO_r <= IO_w;
		cnt_r <= cnt_w;
		loop_r <= loop_w;
		M_r <= M_w;
		X_r <= X_w;
		Y_r <= Y_w;
		r_X_r <= r_X_w;
		r_Y_r <= r_Y_w;
		r_Z_r <= r_Z_w;
		
		MM1_mul_in1_r <= MM1_mul_in1_w;
		MM1_mul_in2_r <= MM1_mul_in2_w;
		MM1_mul_xy_1_r <= MM1_mul_xy_1_w;
		MM1_mul_xy_2_r <= MM1_mul_xy_2_w;
		MM1_mul_xy_3_r <= MM1_mul_xy_3_w;
		A_r <= A_w;
		B_r <= B_w;
		C_r <= C_w;
		D_r <= D_w;
		E_r <= E_w;
		F_r <= F_w;
		G_r <= G_w;
		H_r <= H_w;
		I_r <= I_w;
		MM_modq_plus_255_in1_r <= MM_modq_plus_255_in1_w;
		MM_modq_plus_255_in2_r <= MM_modq_plus_255_in2_w;
		MM_modq_minus_255_in1_r <= MM_modq_minus_255_in1_w;
		MM_modq_minus_255_in2_r <= MM_modq_minus_255_in2_w;

		P2_x_r <= P2_x_w;	P2_y_r <= P2_y_w;	P2_z_r <= P2_z_w;
		P3_x_r <= P3_x_w;	P3_y_r <= P3_y_w;	P3_z_r <= P3_z_w;
		P4_x_r <= P4_x_w;	P4_y_r <= P4_y_w;	P4_z_r <= P4_z_w;
		P5_x_r <= P5_x_w;	P5_y_r <= P5_y_w;	P5_z_r <= P5_z_w;
		P6_x_r <= P6_x_w;	P6_y_r <= P6_y_w;	P6_z_r <= P6_z_w;
		P7_x_r <= P7_x_w;	P7_y_r <= P7_y_w;	P7_z_r <= P7_z_w;
		P8_x_r <= P8_x_w;	P8_y_r <= P8_y_w;	P8_z_r <= P8_z_w;
		P9_x_r <= P9_x_w;	P9_y_r <= P9_y_w;	P9_z_r <= P9_z_w;
		P10_x_r <= P10_x_w;	P10_y_r <= P10_y_w;	P10_z_r <= P10_z_w;
		P11_x_r <= P11_x_w;	P11_y_r <= P11_y_w;	P11_z_r <= P11_z_w;
		P12_x_r <= P12_x_w;	P12_y_r <= P12_y_w;	P12_z_r <= P12_z_w;
		P13_x_r <= P13_x_w;	P13_y_r <= P13_y_w;	P13_z_r <= P13_z_w;
		P14_x_r <= P14_x_w;	P14_y_r <= P14_y_w;	P14_z_r <= P14_z_w;
		P15_x_r <= P15_x_w;	P15_y_r <= P15_y_w;	P15_z_r <= P15_z_w;

		Plus_P_r <= Plus_P_w;
		
		Plus_reg1_r <= Plus_reg1_w;
		Plus_reg2_r <= Plus_reg2_w;
	end
end

endmodule


module modq_510_plus_stage1(
	input [509:0] in1,
	input [509:0] in2,
	output [254:0]out1,
	output [254:0]out2
);

	wire [254:0]LSB_in1;
	wire [254:0]LSB_in2;
	wire [255:0]result;

	assign LSB_in1 = in1[0 +: 255];
	assign LSB_in2 = in2[0 +: 255];
	assign result = LSB_in1 + LSB_in2;

	assign out1 = in1[509 -: 255];
	assign out2 = (result[255])? in2[509 -: 255] + 1 : in2[509 -: 255];

endmodule

module modq_510_plus_stage2(
	input [254:0] in1,
	input [254:0] in2,
	output [254:0] out_up
);

	parameter q = 255'h 7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffed;

	wire carry;
	wire [254:0]result;

	assign {carry,result} = in1 + in2;

	assign out_up = (carry == 1 || (&result[254 -: 249]==1 && result[0 +: 5]>= 5'b1101))? result - q : result  ;

endmodule

module modq_255_plus(
	input [254:0] in1,
	input [254:0] in2,
	output [254:0] out
);

parameter q = 255'h 7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffed;

wire [255:0]result;//加出來是256 bit

assign result = in1 + in2;

assign out = (result[255] == 1 || (&result[254 -: 249]==1 && result[0 +: 5]>= 5'b1101))? result - q : result ;

endmodule

module modq_255_minus(
	input [254:0] in1,
	input [254:0] in2,
	output [254:0] out
);

wire [255:0]result;//加出來最多256 bit 
wire [255:0]test;
wire [255:0]temp;
parameter q = 255'h 7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffed;

assign temp = in1 - in2;

assign result = (in1 >= in2)? temp : temp + q;
assign test = (result >= q)? result - q : result ;
assign out = test[0 +: 255];

endmodule