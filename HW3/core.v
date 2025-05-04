
module core (                       //Don't modify interface
	input         i_clk,
	input         i_rst_n,
	input         i_op_valid,
	input  [ 3:0] i_op_mode,
    output        o_op_ready,
	input         i_in_valid,
	input  [ 7:0] i_in_data,
	output        o_in_ready,
	output        o_out_valid,
	output [13:0] o_out_data
);




parameter IDLE = 4'd0;
parameter READY = 4'd1;
parameter CHECK = 4'd2;
parameter SHIFT = 4'd3;
parameter LOAD_IMAGE = 4'd4;
parameter CONV = 4'd5;
parameter MED = 4'd6;
parameter NMS = 4'd7;
parameter TEMP = 4'd8;
parameter OUT_PUT = 4'd9;

// ---------------------------------------------------------------------------
reg [7:0] in_reg, nxt_in_reg;
wire [7:0] rdata_u0, rdata_u1, rdata_u2, rdata_u3;
reg [3:0] state, nxt_state;
reg [10:0] cnt_2047, nxt_cnt_2047;
reg [8:0] display_cnt, nxt_display_cnt;
reg flag_disp, nxt_flag_disp;
wire [8:0] display_limit;
reg [8:0] disp_addr_u0, nxt_disp_addr_u0;
reg [8:0] disp_addr_u123, nxt_disp_addr_u123;
reg [13:0] out_disp;
reg [7:0] temp_disp;
wire [8:0] sram_addr_u0,sram_addr_u1,sram_addr_u2,sram_addr_u3;
wire sram_wen_u0,sram_wen_u1,sram_wen_u2,sram_wen_u3;

reg [2:0] x, nxt_x, y, nxt_y; 
reg [5:0] z, nxt_z;
reg [8:0] cnt_512_u0, nxt_cnt_512_u0, cnt_512_u1, nxt_cnt_512_u1, cnt_512_u2, nxt_cnt_512_u2, cnt_512_u3, nxt_cnt_512_u3;


reg [7:0] sram_out_u0, nxt_sram_out_u0, sram_out_u1, nxt_sram_out_u1, sram_out_u2, nxt_sram_out_u2, sram_out_u3, nxt_sram_out_u3;
reg output_disp_flag, nxt_output_disp_flag;
reg [8:0] out_disp_counter,nxt_out_disp_counter;
reg [3:0] op_mode, nxt_op_mode;
reg op_valid_in, nxt_op_valid_in;
reg in_valid, nxt_in_valid;
reg op_ready_out,nxt_op_ready_out;
reg in_ready_out,nxt_in_ready_out;


reg disp_initial_flag, nxt_disp_initial_flag;
reg [13:0] o_out_data_r;
reg [3:0] med_counter,nxt_med_counter;
reg [7:0] median_reg [0:8];
reg [7:0] nxt_median_reg [0:8];
reg [8:0] op_addr_u0, nxt_op_addr_u0, op_addr_u1, nxt_op_addr_u1, op_addr_u2, nxt_op_addr_u2, op_addr_u3, nxt_op_addr_u3; 
wire [8:0] large_mul_16;
reg [5:0] large_cnt, nxt_large_cnt;
reg op_flag, nxt_op_flag;
wire [7:0] median_w;
reg [7:0] out_median [0:3];
reg [7:0] nxt_out_median [0:3];
/////////Sobel Gradient + NMS
wire signed [8:0]  data0_negative_xy, data3_negative_x, data6_negative_x;
wire signed [8:0]  data1_negative_y, data2_negative_y;
wire signed [8:0]  temp_data_02_x, temp_data_35_x, temp_data_68_x;
wire signed [8:0]  temp_data_06_y, temp_data_17_y, temp_data_28_y;
wire signed [9:0]  mul_data_35_x, mul_data_17_y;
wire signed [10:0]  gx,gy;
reg [10:0] gx_abs, nxt_gx_abs, gy_abs, nxt_gy_abs;
wire signed [18:0] tan_shift_left1;
wire signed [11:0] tan_shift_r2, tan_shift_r3;
wire signed [12:0] tan_shift_r5, tan_shift_r7;
wire signed [17:0] gx_tan_22_5;
wire signed [19:0] gx_tan_67_5;
wire signed [12:0] temp_tan_23;
wire signed [13:0] temp_tan_57;
reg [17:0] gx_tan_22_5_abs;
reg [19:0] gx_tan_67_5_abs;
reg [1:0] compare, nxt_compare;
reg [13:0] G_A, nxt_G_A, G_B, nxt_G_B, G_C, nxt_G_C, G_D, nxt_G_D;
reg [1:0] compare_A, nxt_compare_A, compare_B, nxt_compare_B, compare_C, nxt_compare_C, compare_D, nxt_compare_D;
reg [13:0] temp_nms_A, temp_nms_B, temp_nms_C, temp_nms_D;
///////////  CONV /////////
reg [16:0] conv_A, nxt_conv_A, conv_B, nxt_conv_B, conv_C, nxt_conv_C, conv_D, nxt_conv_D;
wire [9:0] temp_16_plus, temp_16; 
wire [9:0] temp_8_plus, temp_8;
wire [9:0] temp_4_plus;
reg  [13:0] round_A, round_B, round_C, round_D;


integer i;
integer j;
///////input output signal
assign o_op_ready  = op_ready_out ;
assign o_in_ready  = in_ready_out ;
//assign o_out_valid = out_valid ;
assign o_out_valid = ((output_disp_flag) ) ? 1'b1 :
					((state == MED) && (large_cnt != 0) && ((med_counter == 2)||(med_counter == 3)||(med_counter == 4)||(med_counter == 5))) ? 1'b1:	
		((large_cnt == z) && ((med_counter == 1) || (med_counter == 2) || (med_counter == 3) || (med_counter == 4))) ? 1'b1 : 
					((state == NMS) && (large_cnt != 0) && ((med_counter == 2)||(med_counter == 3)||(med_counter == 4)||(med_counter == 5)))? 1'b1 : 1'b0;

always @(*) begin
	if ((state == TEMP) || (state == CHECK && op_valid_in)) begin 
		nxt_disp_initial_flag = 1'b1;
	end
	else nxt_disp_initial_flag = 1'b0;
end

always @(*) begin
	if (state == READY) begin
		nxt_op_ready_out = 1'd1;
	end
	else nxt_op_ready_out = 1'd0;

end

always @(*) begin
	if (state == CHECK || state == LOAD_IMAGE || READY) begin //load data
		nxt_in_ready_out = 1'd1;
	end
	else nxt_in_ready_out = 1'd0;
end


always @(*) begin
	if (i_in_valid) begin
		nxt_in_reg = i_in_data;
	end
	else nxt_in_reg = in_reg;
end

always @(*) begin
	if ((state == OUT_PUT) && (display_cnt == 2'd2)) begin  
		nxt_output_disp_flag = 1'b1;
	end
	else if (out_disp_counter == display_limit) begin
		nxt_output_disp_flag = 1'b0;
	end
	else nxt_output_disp_flag = output_disp_flag;
end
always @(*) begin
	if ((state == OUT_PUT) && (output_disp_flag)) begin
		nxt_out_disp_counter = out_disp_counter + 1'b1;
	end
	else if (state != OUT_PUT) begin
		nxt_out_disp_counter = 1'b0;
	end
	else nxt_out_disp_counter = out_disp_counter;
end
/////i_op_mode 
always @(*) begin
	if (i_op_valid) begin
		nxt_op_mode = i_op_mode;
	end
	else nxt_op_mode = op_mode;
end
/////i_op_valid
always @(*) begin
	if ((op_mode == 4'b0000) && i_op_valid) begin
		nxt_op_valid_in = 1'b1;
	end
	else if (i_op_valid) begin
		nxt_op_valid_in = 1'b1;
	end
	else nxt_op_valid_in = 1'b0;
end
/////i_in_valid
always @(*) begin
	nxt_in_valid = i_in_valid;
end

	sram_512x8 U0 (.CLK(i_clk) ,.A(sram_addr_u0) ,.D(in_reg) ,.CEN(1'b0) ,.WEN(sram_wen_u0) ,.Q(rdata_u0));
	sram_512x8 U1 (.CLK(i_clk) ,.A(sram_addr_u1) ,.D(in_reg) ,.CEN(1'b0) ,.WEN(sram_wen_u1) ,.Q(rdata_u1));
	sram_512x8 U2 (.CLK(i_clk) ,.A(sram_addr_u2) ,.D(in_reg) ,.CEN(1'b0) ,.WEN(sram_wen_u2) ,.Q(rdata_u2));
	sram_512x8 U3 (.CLK(i_clk) ,.A(sram_addr_u3) ,.D(in_reg) ,.CEN(1'b0) ,.WEN(sram_wen_u3) ,.Q(rdata_u3));

	Median m0 (.i_clk(i_clk) ,.i_rst_n(i_rst_n) ,.in0(median_reg[0]) ,.in1(median_reg[1]) ,.in2(median_reg[2]) ,.in3(median_reg[3]) ,.in4(median_reg[4]) 
			,.in5(median_reg[5]) ,.in6(median_reg[6]) ,.in7(median_reg[7]) ,.in8(median_reg[8]) ,.result_median(median_w));




always @(*) begin
	if ((state == TEMP) || (state == CONV) || (state == MED) || (state == NMS) || (state == OUT_PUT)) begin
		nxt_sram_out_u0 = rdata_u0;
		nxt_sram_out_u1 = rdata_u1;
		nxt_sram_out_u2 = rdata_u2;
		nxt_sram_out_u3 = rdata_u3;
	end
	else begin
		nxt_sram_out_u0 = sram_out_u0;
		nxt_sram_out_u1 = sram_out_u1;
		nxt_sram_out_u2 = sram_out_u2;
		nxt_sram_out_u3 = sram_out_u3;
	end
end
// ---------------------------------------------------------------------------



// Continuous Assignment     
assign sram_wen_u0 = ((state == LOAD_IMAGE) && (cnt_2047[1:0] ==2'd0) && (in_valid) ) ? 1'b0 :  1'b1;	
assign sram_wen_u1 = ((state == LOAD_IMAGE) && (cnt_2047[1:0] ==2'd1) && (in_valid) ) ? 1'b0 :  1'b1;
assign sram_wen_u2 = ((state == LOAD_IMAGE) && (cnt_2047[1:0] ==2'd2) && (in_valid) ) ? 1'b0 :  1'b1;
assign sram_wen_u3 = ((state == LOAD_IMAGE) && (cnt_2047[1:0] ==2'd3) && (in_valid) ) ? 1'b0 :  1'b1;
assign sram_addr_u0 = ((state == LOAD_IMAGE) && (cnt_2047[1:0]==1'd0)) ? cnt_512_u0 : ((state == OUT_PUT) && (flag_disp)) ? disp_addr_u0 :
					   (((state == MED) || (state == NMS) || (state == CONV)) && op_flag) ? op_addr_u0 : 1'b0;	
																	
assign sram_addr_u1 = ((state == LOAD_IMAGE) && (cnt_2047[1:0]==1'd1)) ? cnt_512_u1 : ((state == OUT_PUT) && (flag_disp)) ? disp_addr_u123 : 
						(((state == MED) || (state == NMS) || (state == CONV)) && op_flag)? op_addr_u1 : 1'b0;
assign sram_addr_u2 = ((state == LOAD_IMAGE) && (cnt_2047[1:0]==2'd2)) ? cnt_512_u2 : ((state == OUT_PUT) && (flag_disp)) ? disp_addr_u123 :
						(((state == MED) || (state == NMS) || (state == CONV)) && op_flag)? op_addr_u2 :1'b0;
assign sram_addr_u3 = ((state == LOAD_IMAGE) && (cnt_2047[1:0]==2'd3)) ? cnt_512_u3 : ((state == OUT_PUT) && (flag_disp)) ? disp_addr_u123 : 
						(((state == MED) || (state == NMS) || (state == CONV)) && op_flag)? op_addr_u3 :1'b0;
																				
always @(*) begin
	if (!sram_wen_u0) begin
		nxt_cnt_512_u0 = cnt_512_u0 + 1'b1;
	end
	else nxt_cnt_512_u0 = cnt_512_u0;
end
always @(*) begin
	if (!sram_wen_u1) begin
		nxt_cnt_512_u1 = cnt_512_u1 + 1'b1;
	end
	else nxt_cnt_512_u1 = cnt_512_u1;
end
always @(*) begin
	if (!sram_wen_u2) begin
		nxt_cnt_512_u2 = cnt_512_u2 + 1'b1;
	end
	else nxt_cnt_512_u2 = cnt_512_u2;
end
always @(*) begin
	if (!sram_wen_u3) begin
		nxt_cnt_512_u3 = cnt_512_u3 + 1'b1;
	end
	else nxt_cnt_512_u3 = cnt_512_u3;
end
//display counter
assign display_limit = (z << 2'd2) - 1'b1; 
always @(*) begin														
	if ((state == TEMP || state == OUT_PUT) && (display_cnt != display_limit)) begin  
		nxt_display_cnt = display_cnt + 1'b1;
	end
	else if ((state != OUT_PUT)) begin
		 nxt_display_cnt = 1'b0;
	end
	else begin
		nxt_display_cnt = display_cnt;
	end
end

always @(*) begin
	if ((op_mode == 4'b0111) && op_valid_in) begin 
		nxt_flag_disp = 1'b1;
	end
	else if ((op_mode != 4'b0111) && op_valid_in) begin
		nxt_flag_disp = 1'b0;
	end
	else nxt_flag_disp = flag_disp;
end
///////////////disp_address////////////
always @(*) begin
	if (state == OUT_PUT || state == TEMP) begin
		if ((disp_initial_flag) && (x==3'd0)) begin 
			nxt_disp_addr_u0 = y << 1'b1 ;
		end
		else if ((disp_initial_flag) && (x==3'd4)) begin 
			nxt_disp_addr_u0 = (y << 1'b1) + 1'b1 ;
		end
		else if ((disp_initial_flag) && (x==3))begin   
			nxt_disp_addr_u0 = (y << 1'b1) + 1'b1;
		end
		else if (display_cnt[1:0] == 2'b10) begin
			nxt_disp_addr_u0 = disp_addr_u0 + 2'd2;
		end
		else if (display_cnt[1:0] == 2'b00) begin
			nxt_disp_addr_u0 = disp_addr_u0 + 4'd14;
		end
		else nxt_disp_addr_u0 = disp_addr_u0;
	end
	else nxt_disp_addr_u0 = 8'd0;
end
always @(*) begin    
	if (state == OUT_PUT || state == TEMP) begin
		if ((disp_initial_flag) && ((x==3'd0) || (x==3'd1)||(x==3'd2)||(x==3'd3))) begin
			nxt_disp_addr_u123 = y << 1'b1 ;
		end
		else if ((disp_initial_flag) && ((x==3'd4) || (x==3'd5)||(x==3'd6)||(x==3'd7))) begin
			nxt_disp_addr_u123 = (y << 1'b1) + 1'b1 ;
		end
		else if (display_cnt[1:0] == 2'b10) begin
			nxt_disp_addr_u123 = disp_addr_u123 + 2'd2;
		end
		else if (display_cnt[1:0] == 2'b00) begin
			nxt_disp_addr_u123 = disp_addr_u123 + 4'd14;
		end
		else nxt_disp_addr_u123 = disp_addr_u123;
	end
	else nxt_disp_addr_u123 = 8'd0;
end

///////////////OUT////////////////////
always @(*) begin
	if (output_disp_flag) begin
		if ((((x==0)||(x==4)) && (out_disp_counter[0]==1'b0)) || ((x==3) && (out_disp_counter[0]==1'b1))) begin
		out_disp = {6'b0,sram_out_u0};
		end
		else if ((((x==0)||(x==4)) && (out_disp_counter[0]==1'b1)) || (((x==1)||(x==5)) && (out_disp_counter[0]==1'b0))) begin
			out_disp = {6'b0,sram_out_u1};
		end
		else if ((((x==1)||(x==5)) && (out_disp_counter[0]==1'b1)) || (((x==2)||(x==6)) && (out_disp_counter[0]==1'b0))) begin
			out_disp = {6'b0,sram_out_u2};
		end
		else if ((((x==2)||(x==6)) && (out_disp_counter[0]==1'b1)) || ((x==3) && (out_disp_counter[0]==1'b0))) begin
			out_disp = {6'b0,sram_out_u3};
		end
		else out_disp = {6'b0,sram_out_u0};
	end
	else out_disp = {6'b0,sram_out_u0};
end

assign o_out_data = o_out_data_r;
always @(*) begin
	if (state == OUT_PUT && op_mode == 4'b0111) begin
		o_out_data_r = out_disp;
	end
	else if (state == MED) begin
		case (large_cnt)
			1:begin
				case (med_counter)
					2: o_out_data_r = {6'b0,out_median[0]};
					3: o_out_data_r = {6'b0,out_median[1]};
					4: o_out_data_r = {6'b0,out_median[2]};
					5: o_out_data_r = {6'b0,out_median[3]};
					default: o_out_data_r = {6'b0,out_median[0]};
				endcase
			end 
			2:begin
				case (med_counter)
					2: o_out_data_r = {6'b0,out_median[0]};
					3: o_out_data_r = {6'b0,out_median[1]};
					4: o_out_data_r = {6'b0,out_median[2]};
					5: o_out_data_r = {6'b0,out_median[3]};
					default: o_out_data_r = {6'b0,out_median[0]};
				endcase
			end
			3:begin
				case (med_counter)
					2: o_out_data_r = {6'b0,out_median[0]};
					3: o_out_data_r = {6'b0,out_median[1]};
					4: o_out_data_r = {6'b0,out_median[2]};
					5: o_out_data_r = {6'b0,out_median[3]};
					default: o_out_data_r = {6'b0,out_median[0]};
				endcase
			end
			4:begin
				case (med_counter)
					2: o_out_data_r = {6'b0,out_median[0]};
					3: o_out_data_r = {6'b0,out_median[1]};
					4: o_out_data_r = {6'b0,out_median[2]};
					5: o_out_data_r = {6'b0,out_median[3]};
					default: o_out_data_r = {6'b0,out_median[0]};
				endcase
			end
			default: o_out_data_r = {6'b0,out_median[0]}; 
		endcase
	end
	else if ((state == CONV) && (large_cnt == z)) begin
		case (med_counter)
			1: o_out_data_r = round_A;
			2: o_out_data_r = round_B;
			3: o_out_data_r = round_C;
			4: o_out_data_r = round_D;
			default: o_out_data_r =	14'b0;		
		endcase
	end
	else if (state == NMS) begin
		case (large_cnt)
			1:begin
				case (med_counter)
					2: o_out_data_r = temp_nms_A;
					3: o_out_data_r = temp_nms_B;
					4: o_out_data_r = temp_nms_C;
					5: o_out_data_r = temp_nms_D;
					default: o_out_data_r = 14'b0;
				endcase
			end 
			2:begin
				case (med_counter)
					2: o_out_data_r = temp_nms_A;
					3: o_out_data_r = temp_nms_B;
					4: o_out_data_r = temp_nms_C;
					5: o_out_data_r = temp_nms_D;
					default: o_out_data_r = 14'b0;
				endcase				
			end
			3:begin
				case (med_counter)
					2: o_out_data_r = temp_nms_A;
					3: o_out_data_r = temp_nms_B;
					4: o_out_data_r = temp_nms_C;
					5: o_out_data_r = temp_nms_D;
					default: o_out_data_r = 14'b0;
				endcase
			end
			4:begin
				case (med_counter)
					2: o_out_data_r = temp_nms_A;
					3: o_out_data_r = temp_nms_B;
					4: o_out_data_r = temp_nms_C;
					5: o_out_data_r = temp_nms_D;
					default: o_out_data_r = 14'b0;
				endcase
			end
			default: o_out_data_r = 14'b0;
		endcase
	end
	else o_out_data_r =	13'b0;	
end
always @(*) begin
	if (state == SHIFT) begin
		if ((x == 1'b0) && (op_mode == 4'b0010)) begin
			nxt_x = x;
		end
		else if ((x == 3'd6) && (op_mode == 4'b0001))begin
			nxt_x = x;
		end
		else if (op_mode == 4'b0010)begin //left shift
			nxt_x = x - 1'b1;
		end
		else if (op_mode == 4'b0001)begin  //right shift
			nxt_x = x + 1'b1;
		end  
		else nxt_x = x;
	end
	else nxt_x = x;
end
always @(*) begin
	if (state == SHIFT) begin
		if ((y == 1'b0) && (op_mode == 4'b0011)) begin
			nxt_y = y;
		end		
		else if ((y == 3'd6) && (op_mode == 4'b0100))begin
			nxt_y = y;
		end
		else if (op_mode == 4'b0011)begin //up shift
			nxt_y = y - 1'b1;
		end
		else if (op_mode == 4'b0100)begin //down shift
			nxt_y = y + 1'b1;
		end
		else nxt_y = y;
	end
	else nxt_y = y;
end
always @(*) begin
	if (state == SHIFT) begin
		if ((z == 6'd32) && (op_mode == 4'b0101)) begin //reduce channel depth------
			nxt_z = z - 5'd16;
		end
		else if ((z == 5'd16) && (op_mode == 4'b0101)) begin //reduce channel depth
			nxt_z = z - 4'd8;
		end
		else if ((z == 4'd8) && (op_mode == 4'b0110)) begin //increase channel depth
			nxt_z = z + 4'd8;
		end
		else if ((z == 5'd16) && (op_mode == 4'b0110)) begin //increase channel depth
			nxt_z = z + 5'd16;
		end
		else nxt_z = z;
	end
	else nxt_z = z;
end
assign large_mul_16 = large_cnt << 4;
always @(*) begin
	nxt_op_addr_u0 = op_addr_u0;
	//case (large_cnt)
	//	0:begin
			case (med_counter)
				0:begin
					case (y) 
						1,2,3,4,5,6:begin
							case (x)
								0,1:begin
									nxt_op_addr_u0 = ((y-1) << 1'b1) + large_mul_16;
								end 
								3,4,5:begin
									nxt_op_addr_u0 = (((y-1) << 1'b1) + 6'd1) + large_mul_16;
								end

							endcase
						end 
					endcase
				end 
				1:begin
					case (y)
						0:begin
							case (x)
								0,1:begin
									nxt_op_addr_u0 = (y << 1'b1) + large_mul_16 ;
								end 
								3,4,5:begin
									nxt_op_addr_u0 = ((y << 1'b1) + 6'd1) + large_mul_16;
								end
							endcase
						end 
						1,2,3,4,5,6:begin
							case (x)
								0,1:begin
									nxt_op_addr_u0 = (y << 1'b1) + large_mul_16 ;
								end 
								3,4,5:begin
									nxt_op_addr_u0 = ((y << 1'b1) + 6'd1) + large_mul_16;
								end
							endcase							
						end
 
					endcase
				end
				2:begin
					nxt_op_addr_u0 = op_addr_u0 + 2;
				end
				3:begin 
					nxt_op_addr_u0 = op_addr_u0 + 2;
				end
				4:begin 
					case (y) 
						1,2,3,4,5,6:begin
							case (x)
								0,1:begin
									nxt_op_addr_u0 = ((y-1) << 1'b1) + large_mul_16;
								end 
								2,3,4,5:begin 
									nxt_op_addr_u0 = (((y-1) << 1'b1) + 6'd1) + large_mul_16;
								end

							endcase
						end 
					endcase					
				end
				5:begin
					case (y)
						0:begin
							case (x)
								0,1:begin
									nxt_op_addr_u0 = (y << 1'b1) + large_mul_16;
								end 
								2,3,4,5:begin
									nxt_op_addr_u0 = ((y << 1'b1) + 6'd1) + large_mul_16;
								end
							endcase
						end 
						1,2,3,4,5,6:begin
							case (x)
								0,1:begin
									nxt_op_addr_u0 = (y << 1'b1) + large_mul_16;
								end 
								2,3,4,5:begin
									nxt_op_addr_u0 = ((y << 1'b1) + 6'd1) + large_mul_16;
								end
							endcase							
						end

					endcase					
				end
				6:begin
					nxt_op_addr_u0 = op_addr_u0 + 2;
				end
				7:begin
					nxt_op_addr_u0 = op_addr_u0 + 2;
				end

			endcase
end
always @(*) begin
	nxt_op_addr_u1 = op_addr_u1;
	case (med_counter)
		0:begin
			case (y)
				1,2,3,4,5,6:begin
					case (x)
						0,1,2:begin
							nxt_op_addr_u1 = ((y-1) << 1'b1) + large_mul_16;
						end 
						4,5,6:begin
							nxt_op_addr_u1 = (((y-1) << 1'b1) + 6'd1) + large_mul_16;
						end
					endcase
				end
			endcase
		end 
		1:begin
			case (y)
				0:begin
					case (x)
						0,1,2:begin
							nxt_op_addr_u1 = (y << 1'b1) + large_mul_16;
						end 
						4,5,6:begin
							nxt_op_addr_u1 = ((y << 1'b1) + 6'd1) + large_mul_16;
						end
					endcase					
				end 
				1,2,3,4,5,6:begin
					case (x)
						0,1,2:begin
							nxt_op_addr_u1 = (y << 1'b1) + large_mul_16;
						end 
						4,5,6:begin
							nxt_op_addr_u1 = ((y << 1'b1) + 6'd1) + large_mul_16;
						end
					endcase
				end
			endcase
		end
		2:begin
			nxt_op_addr_u1 = op_addr_u1 + 2;
		end
		3:begin
			nxt_op_addr_u1 = op_addr_u1 + 2;
		end
		4:begin
			case (y)
				1,2,3,4,5,6:begin
					case (x)
						0,1:begin
							nxt_op_addr_u1 = ((y-1) << 1'b1) + large_mul_16;
						end 
						3,4,5:begin
							nxt_op_addr_u1 = (((y-1) << 1'b1) + 6'd1) + large_mul_16;
						end
					endcase
				end
			endcase
		end
		5:begin
			case (y)
				0:begin
					case (x)
						0,1:begin
							nxt_op_addr_u1 = (y << 1'b1) + large_mul_16;
						end 
						3,4,5:begin
							nxt_op_addr_u1 = ((y << 1'b1) + 6'd1) + large_mul_16;
						end
					endcase					
				end 
				1,2,3,4,5,6:begin
					case (x)
						0,1:begin
							nxt_op_addr_u1 = (y << 1'b1) + large_mul_16;
						end 
						3,4,5:begin
							nxt_op_addr_u1 = ((y << 1'b1) + 6'd1) + large_mul_16;
						end
					endcase
				end
			endcase			
		end
		6:begin
			nxt_op_addr_u1 = op_addr_u1 + 2;
		end
		7:begin
			nxt_op_addr_u1 = op_addr_u1 + 2;
		end
	endcase
end
//addr_u2
always @(*) begin
	nxt_op_addr_u2 = op_addr_u2;
	case (med_counter)
		0:begin
			case (y)
				1,2,3,4,5,6:begin
					case (x)
						1,2,3:begin
							nxt_op_addr_u2 = ((y-1) << 1'b1) + large_mul_16;
						end 
						5,6:begin
							nxt_op_addr_u2 = (((y-1) << 1'b1) + 6'd1) + large_mul_16;
						end
					endcase
				end
			endcase
		end 
		1:begin
			case (y)
				0:begin
					case (x)
						1,2,3:begin
							nxt_op_addr_u2 = (y << 1'b1) + large_mul_16;
						end 
						5,6:begin
							nxt_op_addr_u2 = ((y << 1'b1) + 6'd1) + large_mul_16;
						end
					endcase					
				end 
				1,2,3,4,5,6:begin
					case (x)
						1,2,3:begin
							nxt_op_addr_u2 = (y << 1'b1) + large_mul_16;
						end 
						5,6:begin
							nxt_op_addr_u2 = ((y << 1'b1) + 6'd1) + large_mul_16;
						end
					endcase
				end
			endcase
		end
		2:begin
			nxt_op_addr_u2 = op_addr_u2 + 2;
		end
		3:begin
			nxt_op_addr_u2 = op_addr_u2 + 2;
		end
		4:begin
			case (y)
				1,2,3,4,5,6:begin
					case (x)
						0,1,2:begin
							nxt_op_addr_u2 = ((y-1) << 1'b1) + large_mul_16;
						end 
						4,5,6:begin
							nxt_op_addr_u2 = (((y-1) << 1'b1) + 6'd1) + large_mul_16;
						end
					endcase
				end
			endcase
		end
		5:begin
			case (y)
				0:begin
					case (x)
						0,1,2:begin
							nxt_op_addr_u2 = (y << 1'b1) + large_mul_16;
						end 
						4,5,6:begin
							nxt_op_addr_u2 = ((y << 1'b1) + 6'd1) + large_mul_16;
						end
					endcase					
				end 
				1,2,3,4,5,6:begin
					case (x)
						0,1,2:begin
							nxt_op_addr_u2 = (y << 1'b1) + large_mul_16;
						end 
						4,5,6:begin
							nxt_op_addr_u2 = ((y << 1'b1) + 6'd1) + large_mul_16;
						end
					endcase
				end
			endcase			
		end
		6:begin
			nxt_op_addr_u2 = op_addr_u2 + 2;
		end
		7:begin
			nxt_op_addr_u2 = op_addr_u2 + 2;
		end
	endcase
end
///addr_u3
always @(*) begin
	nxt_op_addr_u3 = op_addr_u3;
	case (med_counter)
		0:begin
			case(y)
				1,2,3,4,5,6:begin
					case (x)
						2,3,4:begin
							nxt_op_addr_u3 = ((y-1) << 1'b1) + large_mul_16;
						end 
						6:begin
							nxt_op_addr_u3 = (((y-1) << 1'b1) + 6'd1) + large_mul_16;
						end
					endcase
				end
			endcase
		end 
		1:begin
			case (y)
				0:begin
					case (x)
						2,3,4:begin
							nxt_op_addr_u3 = (y << 1'b1) + large_mul_16;
						end 
						6:begin
							nxt_op_addr_u3 = ((y << 1'b1) + 6'd1) + large_mul_16;
						end
					endcase					
				end 
				1,2,3,4,5,6:begin
					case (x)
						2,3,4:begin
							nxt_op_addr_u3 = (y << 1'b1) + large_mul_16;
						end 
						6:begin
							nxt_op_addr_u3 = ((y << 1'b1) + 6'd1) + large_mul_16;
						end
					endcase
				end
			endcase
		end
		2:begin
			nxt_op_addr_u3 = op_addr_u3 + 2;
		end
		3:begin
			nxt_op_addr_u3 = op_addr_u3 + 2;
		end
		4:begin
			case (y)
				1,2,3,4,5,6:begin
					case (x)
						1,2,3:begin
							nxt_op_addr_u3 = ((y-1) << 1'b1) + large_mul_16;
						end 
						5,6:begin
							nxt_op_addr_u3 = (((y-1) << 1'b1) + 6'd1) + large_mul_16;
						end
					endcase
				end
			endcase
		end
		5:begin
			case (y)
				0:begin
					case (x)
						1,2,3:begin
							nxt_op_addr_u3 = (y << 1'b1) + large_mul_16;
						end 
						5,6:begin
							nxt_op_addr_u3 = ((y << 1'b1) + 6'd1) + large_mul_16;
						end
					endcase					
				end 
				1,2,3,4,5,6:begin
					case (x)
						1,2,3:begin
							nxt_op_addr_u3 = (y << 1'b1) + large_mul_16;
						end 
						5,6:begin
							nxt_op_addr_u3 = ((y << 1'b1) + 6'd1) + large_mul_16;
						end
					endcase
				end
			endcase			
		end
		6:begin
			nxt_op_addr_u3 = op_addr_u3 + 2;
		end
		7:begin
			nxt_op_addr_u3 = op_addr_u3 + 2;
		end
	endcase
end

always @(*) begin
		for (j = 0;j<4 ;j=j+1) begin
			nxt_out_median[j] = out_median[j];
		end		

		case (large_cnt)
			0:begin
				case (med_counter)
					7:  nxt_out_median[0] = median_w; 
					8:  nxt_out_median[2] = median_w; 
					
				endcase
			end 
			1:begin
				case (med_counter)
					0:  nxt_out_median[1] = median_w; 
					1:  nxt_out_median[3] = median_w; 
					7:  nxt_out_median[0] = median_w; 
					8:  nxt_out_median[2] = median_w; 
				endcase
			end
			2:begin
				case (med_counter)
					0:  nxt_out_median[1] = median_w; 
					1:  nxt_out_median[3] = median_w; 
					7:  nxt_out_median[0] = median_w; 
					8:  nxt_out_median[2] = median_w; 
				endcase
			end
			3:begin
				case (med_counter)
					0:  nxt_out_median[1] = median_w; 
					1:  nxt_out_median[3] = median_w; 
					7:  nxt_out_median[0] = median_w; 
					8:  nxt_out_median[2] = median_w; 
				endcase
			end
			4:begin
				case (med_counter)
					0: nxt_out_median[1] = median_w;
					1: nxt_out_median[3] = median_w;
					
				endcase
			end
		endcase
end

always @(*) begin
	for (i=0;i<9 ;i=i+1 ) begin
		nxt_median_reg[i] = median_reg[i];
	end	
	case (med_counter)
		0:begin
			for (i=0;i<9 ;i=i+1 ) begin
				nxt_median_reg[i] = 8'b0;
			end				
		end
		3:begin
			case (y)
				1,2,3,4,5,6:begin
					case (x)
						0: begin
							nxt_median_reg[0] = 0;
							nxt_median_reg[1] = sram_out_u0;
							nxt_median_reg[2] = sram_out_u1;
						end
						1:begin
							nxt_median_reg[0] = sram_out_u0;
							nxt_median_reg[1] = sram_out_u1;
							nxt_median_reg[2] = sram_out_u2;
						end
						2:begin
							nxt_median_reg[0] = sram_out_u1;
							nxt_median_reg[1] = sram_out_u2;
							nxt_median_reg[2] = sram_out_u3;	
						end
						3:begin
							nxt_median_reg[0] = sram_out_u2;
							nxt_median_reg[1] = sram_out_u3;
							nxt_median_reg[2] = sram_out_u0;
						end
						4:begin
							nxt_median_reg[0] = sram_out_u3;
							nxt_median_reg[1] = sram_out_u0;
							nxt_median_reg[2] = sram_out_u1;
						end
						5:begin
							nxt_median_reg[0] = sram_out_u0;
							nxt_median_reg[1] = sram_out_u1;
							nxt_median_reg[2] = sram_out_u2;
						end
						6:begin
							nxt_median_reg[0] = sram_out_u1;
							nxt_median_reg[1] = sram_out_u2;
							nxt_median_reg[2] = sram_out_u3;
						end
					endcase
				end
			endcase
		end 
		4:begin
			case (y)
				0,1,2,3,4,5,6:begin
					case (x)
						0:begin
							nxt_median_reg[3] = 0;
							nxt_median_reg[4] = sram_out_u0;
							nxt_median_reg[5] = sram_out_u1;
						end 
						1:begin
							nxt_median_reg[3] = sram_out_u0;
							nxt_median_reg[4] = sram_out_u1;
							nxt_median_reg[5] = sram_out_u2;
						end
						2:begin
							nxt_median_reg[3] = sram_out_u1;
							nxt_median_reg[4] = sram_out_u2;
							nxt_median_reg[5] = sram_out_u3;
						end
						3:begin
							nxt_median_reg[3] = sram_out_u2;
							nxt_median_reg[4] = sram_out_u3;
							nxt_median_reg[5] = sram_out_u0;
						end
						4:begin
							nxt_median_reg[3] = sram_out_u3;
							nxt_median_reg[4] = sram_out_u0;
							nxt_median_reg[5] = sram_out_u1;
						end
						5:begin
							nxt_median_reg[3] = sram_out_u0;
							nxt_median_reg[4] = sram_out_u1;
							nxt_median_reg[5] = sram_out_u2;
						end
						6:begin
							nxt_median_reg[3] = sram_out_u1;
							nxt_median_reg[4] = sram_out_u2;
							nxt_median_reg[5] = sram_out_u3;
						end
					endcase
				end
			endcase
		end
		5:begin
			case (y) 
				0,1,2,3,4,5,6:begin
					case (x)
					0: begin
						nxt_median_reg[6] = 0;
						nxt_median_reg[7] = sram_out_u0;
						nxt_median_reg[8] = sram_out_u1;
					end
					1:begin
						nxt_median_reg[6] = sram_out_u0;
						nxt_median_reg[7] = sram_out_u1;
						nxt_median_reg[8] = sram_out_u2;	
					end
					2:begin
						nxt_median_reg[6] = sram_out_u1;
						nxt_median_reg[7] = sram_out_u2;
						nxt_median_reg[8] = sram_out_u3;	
					end
					3:begin
						nxt_median_reg[6] = sram_out_u2;
						nxt_median_reg[7] = sram_out_u3;
						nxt_median_reg[8] = sram_out_u0;
					end
					4:begin
						nxt_median_reg[6] = sram_out_u3;
						nxt_median_reg[7] = sram_out_u0;
						nxt_median_reg[8] = sram_out_u1;
					end
					5:begin
						nxt_median_reg[6] = sram_out_u0;
						nxt_median_reg[7] = sram_out_u1;
						nxt_median_reg[8] = sram_out_u2;
					end
					6:begin
						nxt_median_reg[6] = sram_out_u1;
						nxt_median_reg[7] = sram_out_u2;
						nxt_median_reg[8] = sram_out_u3;
					end
					endcase
				end
			endcase
			end
		6:begin
			case (y) 
				0,1,2,3,4,5:begin
					case (x)
						0:begin
							for (i =0 ;i<6 ;i=i+1 ) begin
								nxt_median_reg[i] = median_reg[i+3];
							end
							nxt_median_reg[6] = 0;
							nxt_median_reg[7] = sram_out_u0;
							nxt_median_reg[8] = sram_out_u1;					
						end 
						1:begin
							for (i =0 ;i<6 ;i=i+1 ) begin
								nxt_median_reg[i] = median_reg[i+3];
							end
							nxt_median_reg[6] = sram_out_u0;
							nxt_median_reg[7] = sram_out_u1;
							nxt_median_reg[8] = sram_out_u2;	
						end
						2:begin
							for (i =0 ;i<6 ;i=i+1 ) begin
								nxt_median_reg[i] = median_reg[i+3];
							end
							nxt_median_reg[6] = sram_out_u1;
							nxt_median_reg[7] = sram_out_u2;
							nxt_median_reg[8] = sram_out_u3;	
							end
						3:begin
							for (i =0 ;i<6 ;i=i+1 ) begin
								nxt_median_reg[i] = median_reg[i+3];
							end
							nxt_median_reg[6] = sram_out_u2;
							nxt_median_reg[7] = sram_out_u3;
							nxt_median_reg[8] = sram_out_u0;
						end
						4:begin
							for (i =0 ;i<6 ;i=i+1 ) begin
								nxt_median_reg[i] = median_reg[i+3];
							end
							nxt_median_reg[6] = sram_out_u3;
							nxt_median_reg[7] = sram_out_u0;
							nxt_median_reg[8] = sram_out_u1;
						end
						5:begin
							for (i =0 ;i<6 ;i=i+1 ) begin
								nxt_median_reg[i] = median_reg[i+3];
							end
							nxt_median_reg[6] = sram_out_u0;
							nxt_median_reg[7] = sram_out_u1;
							nxt_median_reg[8] = sram_out_u2;
						end
						6:begin
							for (i =0 ;i<6 ;i=i+1 ) begin
								nxt_median_reg[i] = median_reg[i+3];
							end
							nxt_median_reg[6] = sram_out_u1;
							nxt_median_reg[7] = sram_out_u2;
							nxt_median_reg[8] = sram_out_u3;
						end				
					endcase
				end
				6:begin
					for (i =0 ;i<6 ;i=i+1 ) begin
						nxt_median_reg[i] = median_reg[i+3];
					end
						nxt_median_reg[6] = 8'b0;
						nxt_median_reg[7] = 8'b0;
						nxt_median_reg[8] = 8'b0;										
				end
		endcase
		end
		7:begin
			case (y)
				0:begin
					nxt_median_reg[0] = 0;
					nxt_median_reg[1] = 0;
					nxt_median_reg[2] = 0;
				end 
				1,2,3,4,5,6:begin
					case (x)
						0:begin
							nxt_median_reg[0] = sram_out_u0;
							nxt_median_reg[1] = sram_out_u1;
							nxt_median_reg[2] = sram_out_u2;							
						end 
						1:begin
							nxt_median_reg[0] = sram_out_u1;
							nxt_median_reg[1] = sram_out_u2;
							nxt_median_reg[2] = sram_out_u3;								
						end
						2:begin
							nxt_median_reg[0] = sram_out_u2;
							nxt_median_reg[1] = sram_out_u3;
							nxt_median_reg[2] = sram_out_u0;								
						end
						3:begin
							nxt_median_reg[0] = sram_out_u3;
							nxt_median_reg[1] = sram_out_u0;
							nxt_median_reg[2] = sram_out_u1;	
						end
						4:begin
							nxt_median_reg[0] = sram_out_u0;
							nxt_median_reg[1] = sram_out_u1;
							nxt_median_reg[2] = sram_out_u2;	
						end
						5:begin
							nxt_median_reg[0] = sram_out_u1;
							nxt_median_reg[1] = sram_out_u2;
							nxt_median_reg[2] = sram_out_u3;	
						end
						6:begin
							nxt_median_reg[0] = sram_out_u2;
							nxt_median_reg[1] = sram_out_u3;
							nxt_median_reg[2] = 0;	
						end
					endcase
				end
			endcase
		end
		8:begin
			case (x)
				0:begin
					nxt_median_reg[3] = sram_out_u0;
					nxt_median_reg[4] = sram_out_u1;
					nxt_median_reg[5] = sram_out_u2;							
				end 
				1:begin
					nxt_median_reg[3] = sram_out_u1;
					nxt_median_reg[4] = sram_out_u2;
					nxt_median_reg[5] = sram_out_u3;								
				end
				2:begin
					nxt_median_reg[3] = sram_out_u2;
					nxt_median_reg[4] = sram_out_u3;
					nxt_median_reg[5] = sram_out_u0;								
				end
				3:begin
					nxt_median_reg[3] = sram_out_u3;
					nxt_median_reg[4] = sram_out_u0;
					nxt_median_reg[5] = sram_out_u1;	
				end
				4:begin
					nxt_median_reg[3] = sram_out_u0;
					nxt_median_reg[4] = sram_out_u1;
					nxt_median_reg[5] = sram_out_u2;	
				end
				5:begin
					nxt_median_reg[3] = sram_out_u1;
					nxt_median_reg[4] = sram_out_u2;
					nxt_median_reg[5] = sram_out_u3;	
				end
				6:begin
					nxt_median_reg[3] = sram_out_u2;
					nxt_median_reg[4] = sram_out_u3;
					nxt_median_reg[5] = 0;	
				end					
			endcase
		end
		9:begin
			case (x)
				0:begin
					nxt_median_reg[6] = sram_out_u0;
					nxt_median_reg[7] = sram_out_u1;
					nxt_median_reg[8] = sram_out_u2;							
				end 
				1:begin
					nxt_median_reg[6] = sram_out_u1;
					nxt_median_reg[7] = sram_out_u2;
					nxt_median_reg[8] = sram_out_u3;								
				end
				2:begin
					nxt_median_reg[6] = sram_out_u2;
					nxt_median_reg[7] = sram_out_u3;
					nxt_median_reg[8] = sram_out_u0;								
				end
				3:begin
					nxt_median_reg[6] = sram_out_u3;
					nxt_median_reg[7] = sram_out_u0;
					nxt_median_reg[8] = sram_out_u1;	
				end
				4:begin
					nxt_median_reg[6] = sram_out_u0;
					nxt_median_reg[7] = sram_out_u1;
					nxt_median_reg[8] = sram_out_u2;	
				end
				5:begin
					nxt_median_reg[6] = sram_out_u1;
					nxt_median_reg[7] = sram_out_u2;
					nxt_median_reg[8] = sram_out_u3;	
				end
				6:begin
					nxt_median_reg[6] = sram_out_u2;
					nxt_median_reg[7] = sram_out_u3;
					nxt_median_reg[8] = 0;	
				end					
			endcase			
		end
		10:begin 
			case(y)
				0,1,2,3,4,5:begin
					case (x)
						0:begin
							for (i =0 ;i<6 ;i=i+1 ) begin
								nxt_median_reg[i] = median_reg[i+3];
							end
							nxt_median_reg[6] = sram_out_u0;
							nxt_median_reg[7] = sram_out_u1;
							nxt_median_reg[8] = sram_out_u2;					
						end 
						1:begin
							for (i =0 ;i<6 ;i=i+1 ) begin
								nxt_median_reg[i] = median_reg[i+3];
							end
							nxt_median_reg[6] = sram_out_u1;
							nxt_median_reg[7] = sram_out_u2;
							nxt_median_reg[8] = sram_out_u3;	
						end
						2:begin
							for (i =0 ;i<6 ;i=i+1 ) begin
								nxt_median_reg[i] = median_reg[i+3];
							end
							nxt_median_reg[6] = sram_out_u2;
							nxt_median_reg[7] = sram_out_u3;
							nxt_median_reg[8] = sram_out_u0;	
						end
						3:begin
							for (i =0 ;i<6 ;i=i+1 ) begin
								nxt_median_reg[i] = median_reg[i+3];
							end
							nxt_median_reg[6] = sram_out_u3;
							nxt_median_reg[7] = sram_out_u0;
							nxt_median_reg[8] = sram_out_u1;
						end
						4:begin
							for (i =0 ;i<6 ;i=i+1 ) begin
								nxt_median_reg[i] = median_reg[i+3];
							end
							nxt_median_reg[6] = sram_out_u0;
							nxt_median_reg[7] = sram_out_u1;
							nxt_median_reg[8] = sram_out_u2;
						end
						5:begin
							for (i =0 ;i<6 ;i=i+1 ) begin
								nxt_median_reg[i] = median_reg[i+3];
							end
							nxt_median_reg[6] = sram_out_u1;
							nxt_median_reg[7] = sram_out_u2;
							nxt_median_reg[8] = sram_out_u3;
						end
						6:begin
							for (i =0 ;i<6 ;i=i+1 ) begin
								nxt_median_reg[i] = median_reg[i+3];
							end
							nxt_median_reg[6] = sram_out_u2;
							nxt_median_reg[7] = sram_out_u3;
							nxt_median_reg[8] = 0;
						end				
					endcase										
				end
				6:begin
					for (i =0 ;i<6 ;i=i+1 ) begin
						nxt_median_reg[i] = median_reg[i+3];
					end
					nxt_median_reg[6] = 8'b0;
					nxt_median_reg[7] = 8'b0;
					nxt_median_reg[8] = 8'b0;										
				end
			endcase
		end
	endcase
end
always @(*) begin
	if (((op_mode == 4'b1000) || (op_mode == 4'b1001) || (op_mode == 4'b1010)) && op_valid_in) begin 
		nxt_op_flag = 1'b1;
	end
	else if (((op_mode != 4'b1000) || (op_mode != 4'b1001) || (op_mode != 4'b1010)) && op_valid_in) begin
		nxt_op_flag = 1'b0;
	end
	else nxt_op_flag = op_flag;
end
always @(*) begin
	if (med_counter == 10) begin
		nxt_large_cnt = large_cnt + 1;
	end
	else if ((state == READY)) begin
		nxt_large_cnt = 0;
	end
	else nxt_large_cnt = large_cnt;
end





always @(*) begin
	if (((state == MED) || (state == NMS) || (state == CONV)) && (med_counter != 4'd10)) begin 
		nxt_med_counter = med_counter + 4'd1;
	end
	else if (med_counter == 4'd10) begin
		nxt_med_counter = 4'd0;
	end
	else if (state == READY) begin
		nxt_med_counter = 4'd0;
	end
	else nxt_med_counter = med_counter;
end

/////////////////////////////////  NMS  ////////////
assign data0_negative_xy = ~({1'b0,median_reg[0]}) + 9'd1;
assign temp_data_02_x    = data0_negative_xy + median_reg[2];
assign data3_negative_x  = ~({1'b0,median_reg[3]}) + 9'd1;
assign temp_data_35_x    = data3_negative_x + median_reg[5];
assign data6_negative_x  = ~({1'b0,median_reg[6]}) + 9'd1;
assign temp_data_68_x    = data6_negative_x + median_reg[8];
assign mul_data_35_x     = temp_data_35_x <<< 1'b1;

assign temp_data_06_y   = data0_negative_xy + median_reg[6];
assign data1_negative_y = ~({1'b0,median_reg[1]}) + 9'd1;
assign temp_data_17_y   = data1_negative_y + median_reg[7];
assign data2_negative_y = ~({1'b0,median_reg[2]}) + 9'd1;
assign temp_data_28_y   = data2_negative_y + median_reg[8];
assign mul_data_17_y    = temp_data_17_y <<< 1'b1;//X2

assign gx = temp_data_02_x + mul_data_35_x + temp_data_68_x;
assign gy = temp_data_06_y + mul_data_17_y + temp_data_28_y;

always @(*) begin
	if (gx[10]) begin
		gx_abs = ~(gx) + 1'b1;
	end
	else gx_abs = gx;
end
always @(*) begin
	if (gy[10]) begin
		gy_abs = ~(gy) + 1'b1;
	end
	else gy_abs = gy;
end

always @(*) begin
nxt_G_A = G_A;
nxt_G_B = G_B;
nxt_G_C = G_C;
nxt_G_D = G_D;
	case (large_cnt)
		0:begin
			case (med_counter)
				6:  nxt_G_A = gx_abs + gy_abs;
				7:  nxt_G_C = gx_abs + gy_abs;
				10 :nxt_G_B = gx_abs + gy_abs;
			endcase
		end 
		1,2,3:begin
			case (med_counter)
				0:  nxt_G_D = gx_abs + gy_abs;
				6:  nxt_G_A = gx_abs + gy_abs;
				7:  nxt_G_C = gx_abs + gy_abs;
				10 :nxt_G_B = gx_abs + gy_abs;
			endcase
		end
		4: begin 
			case (med_counter)			
				0:  nxt_G_D = gx_abs + gy_abs;
			endcase
		end
	endcase
end



assign tan_shift_left1 = {gx,8'b0};
assign tan_shift_r2    = {gx,1'b0}; 
assign tan_shift_r3    = {{1{gx[10]}},gx};  
assign tan_shift_r5    = {gx,2'b0};  
assign tan_shift_r7    = {{2{gx[10]}},gx};     
assign temp_tan_23     = tan_shift_r2 + tan_shift_r3;
assign temp_tan_57     = tan_shift_r5 + tan_shift_r7;
assign gx_tan_22_5     = {temp_tan_23[12],temp_tan_23,4'b0} + {{4{temp_tan_57[13]}},temp_tan_57};
assign gx_tan_67_5     = {temp_tan_23[12],temp_tan_23,4'b0} + {{4{temp_tan_57[13]}},temp_tan_57} + tan_shift_left1;

always @(*) begin
	if (gx_tan_22_5[17]) begin
		gx_tan_22_5_abs = ~(gx_tan_22_5) + 18'd1;
	end
	else gx_tan_22_5_abs = gx_tan_22_5;
end
always @(*) begin
	if (gx_tan_67_5[19]) begin
		gx_tan_67_5_abs = ~(gx_tan_67_5) + 20'd1;
	end
	else gx_tan_67_5_abs = gx_tan_67_5;
end

always @(*) begin
	if ({gy_abs,7'b0} < gx_tan_22_5_abs) begin
		compare = 2'd0;
	end			 
	else if({2'b0,gy_abs,7'b0} > gx_tan_67_5_abs) begin  
		compare = 2'd2;
	end
	else if (gx[10] ^ gy[10]) begin
		compare = 2'd3;
	end
	else compare = 2'd1;
end
always @(*) begin
nxt_compare_A = compare_A;
nxt_compare_B = compare_B;
nxt_compare_C = compare_C;
nxt_compare_D = compare_D;
	case (large_cnt)
		0:begin
			case (med_counter)
				6:  nxt_compare_A = compare;
				7:  nxt_compare_C = compare;
				10 :nxt_compare_B = compare;
			endcase
		end 
		1,2,3:begin
			case (med_counter)
				0:  nxt_compare_D = compare;
				6:  nxt_compare_A = compare;
				7:  nxt_compare_C = compare;
				10 :nxt_compare_B = compare;
			endcase
		end
		4: begin 
			case (med_counter)			
				0:  nxt_compare_D = compare;
			endcase
		end
	endcase
end

always @(*) begin
temp_nms_A = G_A;
	case (compare_A)
		2'd0:begin
			if (G_A < G_B) begin
				temp_nms_A = 14'b0;
			end
			else temp_nms_A = G_A;
		end 
		2'd1:begin
			if(G_A < G_D)begin
				temp_nms_A = 14'b0;
			end
			else temp_nms_A = G_A;
		end
		2'd2:begin
			if (G_A < G_C) begin
				temp_nms_A = 14'b0;
			end
			else temp_nms_A = G_A;
		end
	endcase
end

always @(*) begin
temp_nms_B = G_B;
	case (compare_B)
		2'd0:begin
			if (G_B < G_A) begin
				temp_nms_B = 14'b0;
			end
			else temp_nms_B = G_B;
		end 
		2'd2:begin
			if(G_B < G_D)begin
				temp_nms_B = 14'b0;
			end
			else temp_nms_B = G_B;
		end
		2'd3:begin
			if (G_B < G_C) begin
				temp_nms_B = 14'b0;
			end
			else temp_nms_B = G_B;
		end
	endcase
end

always @(*) begin
temp_nms_C = G_C;
	case (compare_C)
		2'd0:begin
			if (G_C < G_D) begin
				temp_nms_C = 14'b0;
			end
			else temp_nms_C = G_C;
		end 
		2'd2:begin
			if(G_C < G_A)begin
				temp_nms_C = 14'b0;
			end
			else temp_nms_C = G_C;
		end
		2'd3:begin
			if (G_C < G_B) begin
				temp_nms_C = 14'b0;
			end
			else temp_nms_C = G_C;
		end
	endcase
end

always @(*) begin
temp_nms_D = G_D;
	case (compare_D)
		2'd0:begin
			if (G_D < G_C) begin
				temp_nms_D = 14'b0;
			end
			else temp_nms_D = G_D;
		end 
		2'd1:begin
			if(G_D < G_A)begin
				temp_nms_D = 14'b0;
			end
			else temp_nms_D = G_D;
		end
		2'd2:begin
			if (G_D < G_B) begin
				temp_nms_D = 14'b0;
			end
			else temp_nms_D = G_D;
		end
	endcase
end

///////////////   CONV ///////////////////
assign temp_16_plus = median_reg[0] + median_reg[2] + median_reg[6] + median_reg[8];
assign temp_8_plus  = median_reg[1] + median_reg[3] + median_reg[5] + median_reg[7];
assign temp_4_plus  = median_reg[4];

always @(*) begin
nxt_conv_A = conv_A;
nxt_conv_B = conv_B;
nxt_conv_C = conv_C;
nxt_conv_D = conv_D;
	case (z)
		32:begin
			case (large_cnt)
				0:begin
					case (med_counter)
						0:begin
							nxt_conv_A = 17'b0;
							nxt_conv_B = 17'b0;
							nxt_conv_C = 17'b0;
							nxt_conv_D = 17'b0;
						end
						6:  nxt_conv_A = conv_A + {6'b0,temp_16_plus} + {5'b0,temp_8_plus,1'b0} + {4'b0,temp_4_plus,2'b0};
						7:  nxt_conv_C = conv_C + {6'b0,temp_16_plus} + {5'b0,temp_8_plus,1'b0} + {4'b0,temp_4_plus,2'b0};
						10: nxt_conv_B = conv_B + {6'b0,temp_16_plus} + {5'b0,temp_8_plus,1'b0} + {4'b0,temp_4_plus,2'b0}; 
					endcase
				end 
				32:begin
					case (med_counter)
						0: nxt_conv_D = conv_D + {6'b0,temp_16_plus} + {5'b0,temp_8_plus,1'b0} + {4'b0,temp_4_plus,2'b0};
						5:begin
							nxt_conv_A = 16'b0; 
							nxt_conv_B = 16'b0; 
							nxt_conv_C = 16'b0; 
							nxt_conv_D = 16'b0; 
						end
					endcase
				end
				default: begin
					case (med_counter)
						0:  nxt_conv_D = conv_D + {6'b0,temp_16_plus} + {5'b0,temp_8_plus,1'b0} + {4'b0,temp_4_plus,2'b0};
						6:  nxt_conv_A = conv_A + {6'b0,temp_16_plus} + {5'b0,temp_8_plus,1'b0} + {4'b0,temp_4_plus,2'b0};
						7:  nxt_conv_C = conv_C + {6'b0,temp_16_plus} + {5'b0,temp_8_plus,1'b0} + {4'b0,temp_4_plus,2'b0};
						10: nxt_conv_B = conv_B + {6'b0,temp_16_plus} + {5'b0,temp_8_plus,1'b0} + {4'b0,temp_4_plus,2'b0};			
					endcase
				end
			endcase
		end
		16:begin
			case (large_cnt)
				0:begin
					case (med_counter)
						0:begin
							nxt_conv_A = 17'b0;
							nxt_conv_B = 17'b0;
							nxt_conv_C = 17'b0;
							nxt_conv_D = 17'b0;
						end
						6:  nxt_conv_A = conv_A + {6'b0,temp_16_plus} + {5'b0,temp_8_plus,1'b0} + {4'b0,temp_4_plus,2'b0};
						7:  nxt_conv_C = conv_C + {6'b0,temp_16_plus} + {5'b0,temp_8_plus,1'b0} + {4'b0,temp_4_plus,2'b0};
						10: nxt_conv_B = conv_B + {6'b0,temp_16_plus} + {5'b0,temp_8_plus,1'b0} + {4'b0,temp_4_plus,2'b0};
					endcase
				end 
				16:begin
					case (med_counter)
						0: nxt_conv_D = conv_D + {6'b0,temp_16_plus} + {5'b0,temp_8_plus,1'b0} + {4'b0,temp_4_plus,2'b0};
						5:begin
							nxt_conv_A = 16'b0; 
							nxt_conv_B = 16'b0; 
							nxt_conv_C = 16'b0; 
							nxt_conv_D = 16'b0; 
						end 
					endcase
				end
				default: begin
					case (med_counter)
						0:  nxt_conv_D = conv_D + {6'b0,temp_16_plus} + {5'b0,temp_8_plus,1'b0} + {4'b0,temp_4_plus,2'b0};
						6:  nxt_conv_A = conv_A + {6'b0,temp_16_plus} + {5'b0,temp_8_plus,1'b0} + {4'b0,temp_4_plus,2'b0};
						7:  nxt_conv_C = conv_C + {6'b0,temp_16_plus} + {5'b0,temp_8_plus,1'b0} + {4'b0,temp_4_plus,2'b0};
						10: nxt_conv_B = conv_B + {6'b0,temp_16_plus} + {5'b0,temp_8_plus,1'b0} + {4'b0,temp_4_plus,2'b0};			
					endcase
				end
			endcase			
		end
		8:begin
			case (large_cnt)
				0:begin
					case (med_counter)
						0:begin
							nxt_conv_A = 17'b0;
							nxt_conv_B = 17'b0;
							nxt_conv_C = 17'b0;
							nxt_conv_D = 17'b0;
						end
						6:  nxt_conv_A = conv_A + {6'b0,temp_16_plus} + {5'b0,temp_8_plus,1'b0} + {4'b0,temp_4_plus,2'b0};
						7:  nxt_conv_C = conv_C + {6'b0,temp_16_plus} + {5'b0,temp_8_plus,1'b0} + {4'b0,temp_4_plus,2'b0};
						10: nxt_conv_B = conv_B + {6'b0,temp_16_plus} + {5'b0,temp_8_plus,1'b0} + {4'b0,temp_4_plus,2'b0};
					endcase
				end 
				8:begin
					case (med_counter)
						0: nxt_conv_D = conv_D + {6'b0,temp_16_plus} + {5'b0,temp_8_plus,1'b0} + {4'b0,temp_4_plus,2'b0};
						5:begin
							nxt_conv_A = 16'b0; 
							nxt_conv_B = 16'b0; 
							nxt_conv_C = 16'b0; 
							nxt_conv_D = 16'b0; 
						end
					endcase
				end
				default: begin
					case (med_counter)
						0:  nxt_conv_D = conv_D + {6'b0,temp_16_plus} + {5'b0,temp_8_plus,1'b0} + {4'b0,temp_4_plus,2'b0};
						6:  nxt_conv_A = conv_A + {6'b0,temp_16_plus} + {5'b0,temp_8_plus,1'b0} + {4'b0,temp_4_plus,2'b0};
						7:  nxt_conv_C = conv_C + {6'b0,temp_16_plus} + {5'b0,temp_8_plus,1'b0} + {4'b0,temp_4_plus,2'b0};
						10: nxt_conv_B = conv_B + {6'b0,temp_16_plus} + {5'b0,temp_8_plus,1'b0} + {4'b0,temp_4_plus,2'b0};			
					endcase
				end
			endcase
		end
	endcase
end

always @(*) begin
	if (conv_A[3]) begin
		round_A = conv_A[16:4] + 13'd1;
	end
	else round_A = conv_A[16:4];
end
always @(*) begin
	if (conv_B[3]) begin
		round_B = conv_B[16:4] + 13'd1;
	end
	else round_B = conv_B[16:4];
end
always @(*) begin
	if (conv_C[3]) begin
		round_C = conv_C[16:4] + 13'd1;
	end
	else round_C = conv_C[16:4];
end
always @(*) begin
	if (conv_D[3]) begin
		round_D = conv_D[16:4] + 13'd1;
	end
	else round_D = conv_D[16:4];
end
// ---------------------------------------------------------------------------
// Combinational Blocks
// ---------------------------------------------------------------------------
// ------------------ FSM ------------------- //
always @(*) begin
	case (state)
		IDLE:begin
			nxt_state = READY;
		end 
		READY:begin
			nxt_state = CHECK;
		end
		CHECK:begin
			if (op_valid_in) begin
				case (op_mode)
					4'd0:  nxt_state = LOAD_IMAGE;
					4'd1:  nxt_state = SHIFT;
					4'd2:  nxt_state = SHIFT;
					4'd3:  nxt_state = SHIFT;
					4'd4:  nxt_state = SHIFT;
					4'd5:  nxt_state = SHIFT;	
					4'd6:  nxt_state = SHIFT;	
					4'd7:  nxt_state = TEMP;
					4'd8:  nxt_state = CONV;  
					4'd9:  nxt_state = MED;  
					4'd10: nxt_state = NMS;  
					default: nxt_state = state;
				endcase
			end
			else nxt_state = state;
		end		
		SHIFT: begin
			nxt_state = READY;
		end
		LOAD_IMAGE:begin
			if ((op_mode == 4'b0000) && (cnt_2047 != 11'd2047)) begin
				nxt_state = state;
			end
			else nxt_state = READY;
		end
		CONV:begin
			if ((large_cnt == (z)) && (med_counter == 5)) begin 
				nxt_state = READY;
			end
			else nxt_state = state;
		end
		MED: begin							
			if ((large_cnt == 4) && (med_counter == 5)) begin 
				nxt_state = READY;				
			end
			else nxt_state = state;
		end
		NMS: begin
			if ((large_cnt == 4) && (med_counter == 5)) begin 
				nxt_state = READY;				
			end
			else nxt_state = state;
		end
		TEMP: begin 
			if (op_mode == 4'b0111) begin
				nxt_state = OUT_PUT;
			end
			else nxt_state = state;
		end
		OUT_PUT: begin
			if (out_disp_counter == display_limit) begin  
				nxt_state = READY;
			end
			else nxt_state = OUT_PUT;
			
		end
		default: nxt_state = state;
	endcase
end



always @(*) begin
	if ((state == LOAD_IMAGE) && in_valid) begin
		nxt_cnt_2047 = cnt_2047 + 1'b1;
	end
	else nxt_cnt_2047 = cnt_2047 ;
end

// ---------------------------------------------------------------------------
// Sequential Block
// ---------------------------------------------------------------------------
// ---- Write your sequential block design here ---- //
always @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
		state <= 0;
		cnt_2047 <= 0;
		display_cnt <= 0;
		flag_disp <= 0;
		disp_addr_u0 <= 0;
		in_reg <= 0;
		disp_addr_u123 <= 0;
		x <= 0;
		y <= 0;
		z <= 32;
		cnt_512_u0 <= 0;
		cnt_512_u1 <= 0;
		cnt_512_u2 <= 0;
		cnt_512_u3 <= 0;
		sram_out_u0 <= 0;
		sram_out_u1 <= 0;
		sram_out_u2 <= 0;
		sram_out_u3 <= 0;
		out_disp_counter <= 0;
		output_disp_flag <= 0;
		op_mode <= 0;
		op_valid_in <= 0;
		in_valid <= 0;
		in_ready_out <= 0;
		op_ready_out <= 0;
		disp_initial_flag <= 0;
		op_addr_u0 <= 0;
		op_addr_u1 <= 0;
		op_addr_u2 <= 0;
		op_addr_u3 <= 0;
		for (i=0;i<9 ;i=i+1 ) begin
			median_reg[i] <= 8'b0;
		end	
		op_flag <= 0;
		med_counter <= 0;
		for (j = 0;j<4 ;j=j+1) begin
			out_median[j] <= 8'b0;
		end
		large_cnt <= 0;
		G_A <= 0;
		G_B <= 0;
		G_C <= 0;
		G_D <= 0;
		compare_A <= 0;
		compare_B <= 0;
		compare_C <= 0;
		compare_D <= 0;
		conv_A <= 0;
		conv_B <= 0;
		conv_C <= 0;
		conv_D <= 0;
    end
    else begin
		state <= nxt_state;
		cnt_2047 <= nxt_cnt_2047;
		display_cnt <= nxt_display_cnt;
		flag_disp <= nxt_flag_disp;
		disp_addr_u0 <= nxt_disp_addr_u0;
		in_reg <= nxt_in_reg;
		disp_addr_u123 <= nxt_disp_addr_u123;
		x <= nxt_x;
		y <= nxt_y;
		z <= nxt_z;
		cnt_512_u0 <= nxt_cnt_512_u0;
		cnt_512_u1 <= nxt_cnt_512_u1;
		cnt_512_u2 <= nxt_cnt_512_u2;
		cnt_512_u3 <= nxt_cnt_512_u3;
		sram_out_u0 <= nxt_sram_out_u0;
		sram_out_u1 <= nxt_sram_out_u1;
		sram_out_u2 <= nxt_sram_out_u2;
		sram_out_u3 <= nxt_sram_out_u3;
		out_disp_counter <= nxt_out_disp_counter;
		output_disp_flag <= nxt_output_disp_flag;
		op_mode <= nxt_op_mode;
		op_valid_in <= nxt_op_valid_in;
		in_valid <= nxt_in_valid;
		in_ready_out <= nxt_in_ready_out;
		op_ready_out <= nxt_op_ready_out;
		disp_initial_flag <= nxt_disp_initial_flag;
		op_addr_u0 <= nxt_op_addr_u0;
		op_addr_u1 <= nxt_op_addr_u1;
		op_addr_u2 <= nxt_op_addr_u2;
		op_addr_u3 <= nxt_op_addr_u3;
		for (i=0;i<9 ;i=i+1 ) begin
			median_reg[i] <= nxt_median_reg[i];
		end	
		op_flag <= nxt_op_flag;
		med_counter <= nxt_med_counter;
		for (j = 0;j<4 ;j=j+1) begin
			out_median[j] <= nxt_out_median[j];
		end
		large_cnt <= nxt_large_cnt;
		G_A <= nxt_G_A;
		G_B <= nxt_G_B;
		G_C <= nxt_G_C;
		G_D <= nxt_G_D;
		compare_A <= nxt_compare_A;
		compare_B <= nxt_compare_B;
		compare_C <= nxt_compare_C;
		compare_D <= nxt_compare_D;
		conv_A <= nxt_conv_A;
		conv_B <= nxt_conv_B;
		conv_C <= nxt_conv_C;
		conv_D <= nxt_conv_D;
	end
end

endmodule
module Compare_2 (
	input [7:0] in0,
	input [7:0] in1,
	output [7:0] max,
	output [7:0] min
);
	assign min = (in0 > in1) ? in1 : in0;
	assign max = (in0 > in1) ? in0 : in1;
endmodule

module Compare_3 (
	input [7:0] in0,
	input [7:0] in1,
	input [7:0] in2,
	output [7:0] max,
	output [7:0] median,	
	output [7:0] min
);
	wire [7:0] temp_min0, temp_min1 , temp_max;
	Compare_2 C1(.in0(in0)       ,.in1(in1)       ,.min(temp_min0) ,.max(temp_max));
	Compare_2 C2(.in0(temp_max)  ,.in1(in2)       ,.min(temp_min1) ,.max(max));
	Compare_2 C3(.in0(temp_min0) ,.in1(temp_min1) ,.min(min)       ,.max(median));
endmodule

module Median (i_clk,i_rst_n,in0,in1,in2,in3,in4,in5,in6,in7,in8,result_median);
	input i_clk;
	input i_rst_n;
	input [7:0] in0;
	input [7:0] in1;
	input [7:0] in2;
	input [7:0] in3;
	input [7:0] in4;
	input [7:0] in5;
	input [7:0] in6;
	input [7:0] in7;
	input [7:0] in8;

	output [7:0] result_median;

	wire [7:0] temp_max0, temp_max1, temp_max2;
	wire [7:0] temp_med0, temp_med1, temp_med2;
	wire [7:0] temp_min0, temp_min1, temp_min2;
	wire [7:0] temp_big1, temp_small_1, temp_big2, max_min, temp_big3, temp_small_2, min_max, temp_small_3, temp_med3, temp_med4, mid_mid;
	wire [7:0] temp_bigger, temp_smaller;

	reg  [7:0] pipe_max, pipe_mid, pipe_min, nxt_pipe_max, nxt_pipe_mid, nxt_pipe_min;

	Compare_3 M1(.in0(in0) ,.in1(in1) ,.in2(in2) ,.max(temp_max0) ,.median(temp_med0) ,.min(temp_min0));
	Compare_3 M2(.in0(in3) ,.in1(in4) ,.in2(in5) ,.max(temp_max1) ,.median(temp_med1) ,.min(temp_min1));
	Compare_3 M3(.in0(in6) ,.in1(in7) ,.in2(in8) ,.max(temp_max2) ,.median(temp_med2) ,.min(temp_min2));
	Compare_2 M4(.in0(temp_max0) ,.in1(temp_max1) ,.max(temp_big1) ,.min(temp_small_1));
	Compare_2 M5(.in0(temp_small_1) ,.in1(temp_max2) ,.max(temp_big2) ,.min(max_min)); 
	Compare_2 M6(.in0(temp_min0) ,.in1(temp_min1) ,.max(temp_big3) ,.min(temp_small_2));
	Compare_2 M7(.in0(temp_big3) ,.in1(temp_min2) ,.max(min_max) ,.min(temp_small_3)); 
	Compare_3 M8(.in0(temp_med0) ,.in1(temp_med1) ,.in2(temp_med2) ,.max(temp_med3) ,.median(mid_mid) ,.min(temp_med4));
	Compare_3 M9(.in0(pipe_max) ,.in1(pipe_mid) ,.in2(pipe_min) ,.max(temp_bigger) ,.median(result_median) ,.min(temp_smaller)); 

always @(*) begin
	nxt_pipe_max = max_min;
	nxt_pipe_mid = mid_mid;
	nxt_pipe_min = min_max;
end
always @(posedge i_clk or negedge i_rst_n) begin
    if (!i_rst_n) begin
		pipe_max <= 0;
		pipe_mid <= 0;
		pipe_min <= 0;
	end
	else begin
		pipe_max <= nxt_pipe_max;
		pipe_mid <= nxt_pipe_mid;
		pipe_min <= nxt_pipe_min;
	end
end
endmodule
