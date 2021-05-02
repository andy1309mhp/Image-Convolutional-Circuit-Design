
`timescale 1ns/10ps

module  CONV(
	input		clk,
	input		reset,
	output	reg	busy,	
	input		ready,	
			
	output	reg[11:0]	iaddr,
	input	[19:0]	idata,	
	
	output	 reg	cwr,
	output	 reg[11:0]	caddr_wr,
	output	 reg[19:0]	cdata_wr,
	
	output	 	reg crd,
	output	 	reg[11:0] caddr_rd,
	input	 	[19:0] cdata_rd,
	
	output	 	reg[2:0] csel
	);



reg[3:0] state, next_state;
parameter IDLE = 4'b0000;
parameter layer0 = 4'b0001;
parameter check0 = 4'b0010;
parameter layer1 = 4'b0011;
parameter check1 = 4'b0100;

reg [3:0] step,step2;
reg signed[19:0]layer0_buffer[0:8];
reg signed[19:0] layer1_buffer[0:3];


wire signed[39:0]layer0_product;
wire signed[19:0] layer0_f;
wire signed[19:0] layer0_rl;



wire signed[19:0] tmp1,tmp2;
wire signed[19:0] max_pool;



reg[7:0] row,col;
reg[7:0] pointer;
reg signed[19:0]kernel[0:8];
reg signed[19:0] B0;
integer i;

initial begin
	busy = 0;
	kernel[0] = 20'h0A89E;
	kernel[1] = 20'h092D5;
	kernel[2] = 20'h06D43;
	kernel[3] = 20'h01004;
	kernel[4] = 20'hF8F71;
	kernel[5] = 20'hF6E54;
	kernel[6] = 20'hFA6D7;
	kernel[7] = 20'hFC834;
	kernel[8] = 20'hFAC19;
	B0 = 20'h01310;
end


//layer0
assign layer0_product = (layer0_buffer[0])*(kernel[0])+(layer0_buffer[1])*(kernel[1])+
                        (layer0_buffer[2])*(kernel[2])+(layer0_buffer[3])*(kernel[3])+
                        (layer0_buffer[4])*(kernel[4])+(layer0_buffer[5])*(kernel[5])+
                        (layer0_buffer[6])*(kernel[6])+(layer0_buffer[7])*(kernel[7])+
                        (layer0_buffer[8])*(kernel[8]);

assign layer0_f = (layer0_product[15:0]>16'h8000)?layer0_product[35:16]+1+B0:layer0_product[35:16]+B0;
assign layer0_rl = (layer0_f>0)?layer0_f:0;

//layer1 maxpool
assign tmp1 = (layer1_buffer[0]>layer1_buffer[1])?layer1_buffer[0]:layer1_buffer[1];
assign tmp2 = (layer1_buffer[2]>layer1_buffer[3])?layer1_buffer[2]:layer1_buffer[3];
assign max_pool = (tmp1>=tmp2)?tmp1:tmp2;




always@(posedge clk)begin
	if(reset)begin
		busy <= 0;
	end
	else begin
		if(state == check1)begin
			busy<=0;
		end
		else begin
			if(ready & !reset)begin
				busy <= 1;
			end
		end
	end
end

always@(posedge clk or negedge reset)begin
	if(reset)begin
		state <= IDLE;
	end
	else begin
		state <= next_state;
	end
end

always@(*)begin
	case(state)
		IDLE:begin
			if(!ready)begin
				next_state = layer0;
			end
			else begin
				next_state = state;
			end
		end
		layer0:begin
			if(caddr_wr == 4095)begin
				next_state = check0;
			end
			else begin
				next_state = state;
			end
		end
		check0:begin
			next_state = layer1;
		end
		layer1:begin
			if(caddr_wr == 1023 & step==6)begin
				next_state = check1;
			end
			else begin
				next_state = state;
			end
		end
		check1:begin
			
		end

	endcase

end





always@(posedge clk or negedge reset)begin
	if(reset)begin
		pointer<=0;
	end
	else begin
		if(state == layer0)begin
			if((step==5 && (row==63 ||row==0)) || step==7)begin
				if(pointer==63)begin
					pointer<=0;
				end
				else begin
					pointer<=pointer+1;
				end
			end
		end
		else if(state == layer1)begin
			if(step==5)begin
				if(pointer == 62)begin
					pointer<=0;
				end
				else begin
					pointer<=pointer+2;
				end
			end
		end
		else begin
			pointer <= 0;
		end
		
	end
end


always@(posedge clk or negedge reset)begin
	if(reset)begin
		row<=0;
	end
	else begin
		if(state==layer0)begin
			if((step==5 && (row==63 ||row==0)) || step==7)begin
				if(pointer==63)begin
					row<=row+1;
				end
				else begin
					row<=row;
				end
			end
		end
		else if(state==layer1)begin
			if(step==5)begin
				if(pointer == 62)begin
					row<=row+2;
				end
				else begin
					row<=row;
				end
			end

		end
		else begin
			row<=row;
		end
	end
end



always@(posedge clk or negedge reset)begin
	if(reset)begin
		cwr<=0;
	end
	else begin
		if(state == layer0)begin
			if((step==5 && (row==63 ||row==0)) || step==7)begin
				cwr<=1;
			end
			else begin
				cwr<=0;
			end
		end
		else if(state == layer1)begin
			if(step==5)begin
				cwr <= 1;
			end
			else begin
				cwr<=0;
			end
		end
		else begin
			cwr<=0;
		end
	end
end








always@(posedge clk or negedge reset)begin
	if(reset)begin
		csel<=0;
	end
	else begin
		if(state == layer0)begin
			csel<=1;
		end
		else if(state==layer1)begin
			if(step==5)begin
				csel<=3;
			end
			else begin
				csel<=1;
			end
	
		end
		else begin
			csel<=csel;
		end
	end
end





always@(posedge clk or negedge reset)begin
	if(reset)begin
		cdata_wr<=0;
		caddr_wr<=0;
		step<=0;
		iaddr<=0;
		caddr_rd<=0;
		crd<=0;
		for(i=0;i<9;i=i+1)
			layer0_buffer[i]<=0;
	end
	else begin
		if(state == layer0 && row == 0)begin
			case(step)
				0:begin
					if(iaddr==0)begin
						layer0_buffer[0]<=0;
						layer0_buffer[1]<=0;
						layer0_buffer[2]<=0;
						layer0_buffer[3]<=0;
						layer0_buffer[6]<=0;
						step<=step+1;
						iaddr<=iaddr;
					end
					else begin
						layer0_buffer[0]<=layer0_buffer[1];
						layer0_buffer[1]<=layer0_buffer[2];
						layer0_buffer[3]<=layer0_buffer[4];
						layer0_buffer[4]<=layer0_buffer[5];
						layer0_buffer[6]<=layer0_buffer[7];
						layer0_buffer[7]<=layer0_buffer[8];
						if(iaddr==63)begin
							layer0_buffer[2]<=0;
							layer0_buffer[5]<=0;
							layer0_buffer[8]<=0;
							iaddr<=iaddr;
							step<=5;
						end
						else begin
							iaddr<=iaddr+1;
							step<=step+2;
						end
					end
				end
				1:begin
					layer0_buffer[4]<=idata;
					iaddr<=iaddr+1;
					step<=step+1;
				end
				2:begin
					layer0_buffer[5]<=idata;
					iaddr<=iaddr+63;
					if(pointer==0)begin
						step<=step+1;
					end
					else begin
						step<=step+2;
					end
				end
				3:begin
					layer0_buffer[7]<=idata;
					iaddr<=iaddr+1;
					step<=step+1;
				end
				4:begin
					layer0_buffer[8]<=idata;
					iaddr<=iaddr;
					step<=step+1;
				end
				5:begin
					caddr_wr<= pointer + row*64;
					cdata_wr<=layer0_rl;
					iaddr<=pointer+1;;
					step<=0;
				end
			endcase
		end
		else if(state == layer0 && row==63)begin
			case(step)
				0:begin
					if(pointer==0)begin
						layer0_buffer[0]<=0;
						layer0_buffer[3]<=0;
						layer0_buffer[6]<=0;
						layer0_buffer[7]<=0;
						layer0_buffer[8]<=0;
						step<=step+1;
						iaddr<=iaddr-64;
					end
					else begin
						layer0_buffer[0]<=layer0_buffer[1];
						layer0_buffer[1]<=layer0_buffer[2];
						layer0_buffer[3]<=layer0_buffer[4];
						layer0_buffer[4]<=layer0_buffer[5];
						layer0_buffer[6]<=layer0_buffer[7];
						layer0_buffer[7]<=layer0_buffer[8];
						step<=step+2;
						iaddr<=iaddr-63;
						if(pointer == 63)begin
							layer0_buffer[2]<=0;
							layer0_buffer[5]<=0;
							layer0_buffer[6]<=0;
							layer0_buffer[7]<=0;
							layer0_buffer[8]<=0;
							step<=5;
						end
					end
				end
				1:begin
					layer0_buffer[1]<=idata;
					iaddr<=iaddr+1;
					step<=step+1;
				end
				2:begin
					layer0_buffer[2]<=idata;
					if(pointer==0)begin
						iaddr<=iaddr+63;
						step<=step+1;
					end
					else begin
						iaddr<=iaddr+64;
						step<=step+2;
					end
				end
				3:begin
					layer0_buffer[4]<=idata;
					iaddr<=iaddr+1;
					step<=step+1;
				end
				4:begin
					layer0_buffer[5]<=idata;
					iaddr<=iaddr;
					step<=step+1;
				end
				5:begin
					caddr_wr<= pointer + row*64;
					cdata_wr<=layer0_rl;
					iaddr<=row*64+pointer+1;
					step<=0;
				end
			endcase
		end
		else if(state == layer0)begin
			case(step)
				0:begin
					if(pointer == 0)begin
						layer0_buffer[0]<=0;
						layer0_buffer[3]<=0;
						layer0_buffer[6]<=0;
						step<=step+1;
						iaddr<=iaddr-64;
					end
					else begin
						layer0_buffer[0]<=layer0_buffer[1];
						layer0_buffer[1]<=layer0_buffer[2];
						layer0_buffer[3]<=layer0_buffer[4];
						layer0_buffer[4]<=layer0_buffer[5];
						layer0_buffer[6]<=layer0_buffer[7];
						layer0_buffer[7]<=layer0_buffer[8];
						step<=step+2;
						iaddr<=iaddr-63;
						if(pointer == 63)begin
							layer0_buffer[2]<=0;
							layer0_buffer[5]<=0;
							layer0_buffer[8]<=0;
							step<=7;
						end
					end
				end
				1:begin
					layer0_buffer[1]<=idata;
					iaddr<=iaddr+1;
					step<=step+1;
				end
				2:begin
					layer0_buffer[2]<=idata;
					if(pointer == 0)begin
						iaddr<=iaddr+63;
						step<=step+1;
					end
					else begin
						iaddr<=iaddr+64;
						step<=step+2;
					end
				end
				3:begin
					layer0_buffer[4]<=idata;
					iaddr<=iaddr+1;
					step<=step+1;
				end
				4:begin
					layer0_buffer[5]<=idata;
					if(pointer == 0)begin
						iaddr<=iaddr+63;
						step<=step+1;
					end
					else begin
						iaddr<=iaddr+64;
						step<=step+2;
					end
				end
				5:begin
					layer0_buffer[7]<=idata;
					iaddr<=iaddr+1;
					step<=step+1;
				end
				6:begin
					layer0_buffer[8]<=idata;
					iaddr<=iaddr;
					step<=step+1;
				end
				7:begin
					caddr_wr<= pointer + row*64;
					cdata_wr<=layer0_rl;
					iaddr<=row*64+pointer+1;
					step<=0;
				end
			endcase
		end
		else if(state == layer1)begin
			case(step)
				0:begin
					caddr_rd<=row*64+pointer;
					caddr_wr <=caddr_wr;
					crd<=1;
					step<=step+1;
				end
				1:begin
					layer1_buffer[0]<=cdata_rd;
					caddr_rd<=caddr_rd+1;
					caddr_wr <=caddr_wr;
					crd<=1;
					step<=step+1;
				end
				2:begin
					layer1_buffer[1]<=cdata_rd;
					caddr_rd<=caddr_rd+63;
					caddr_wr <=caddr_wr;
					crd<=1;
					step<=step+1;
				end
				3:begin
					layer1_buffer[2]<=cdata_rd;
					caddr_rd<=caddr_rd+1;
					caddr_wr <=caddr_wr;
					crd<=1;
					step<=step+1;
				end
				4:begin
					layer1_buffer[3]<=cdata_rd;
					caddr_rd<=caddr_rd;
					caddr_wr <=caddr_wr;
					crd<=0;
					step<=step+1;
				end
				5:begin
					cdata_wr <=max_pool;
					caddr_wr <=caddr_wr;
					crd<=0;
					step<=step+1;
				end
				6:begin
					caddr_wr <=caddr_wr+1;
					crd<=0;
					step<=0;

				end
			endcase
		end
		else begin
			cdata_wr<=0;
			caddr_wr<=0;
			step<=0;
			iaddr<=0;
			for(i=0;i<9;i=i+1)
				layer0_buffer[i]<=0;
		end
	end
end	















endmodule




