/*
Huffman Encoder (without pipelining) 
*/

//State variable names
`define INIT 3'b111
`define GET_DATA 3'b000  	
`define BUILD_TREE 3'b001
`define DECODE_TREE 3'b010
`define SEND_SYMBOLS 3'b011
`define SEND_CODE 3'b100
`define SEND_LENGTH 3'b101

module huff_encoder(
			input wire clock,								//Clock
			input wire [bit_width:0]data_in,				//Input data from another module
			input wire data_enable,						//This bit has to be high for data to be accepted
			output reg [2*bit_width+2:0]data_out,				//Output data from this module
			output reg data_recv,							//This bit should remain high whenever data is being sent
			output reg code_map_recv						//This bit should be high whenever code map is being sent
			);	

						
parameter bit_width = 7;
parameter col_length = 255; 	//2 power bit width, no support for 2**bit_width in verilog 1995
parameter No_of_Data = 100;

reg [7:0]Prob_list[col_length:0];				//Probability list
reg [7:0]temp2;
reg [bit_width:0]Sym_list[col_length:0];		//Symbols list
reg [bit_width:0]Sym,temp1;						//Symbol holder variable

reg [0:2*bit_width+2]Code_list[col_length:0];		//Codes list
reg [bit_width:0]Code_length[col_length:0];		//Code lengths

reg [bit_width:0]Huff_list[col_length:0];		//List used to perform the algorithm on
reg [bit_width:0]Pair_list[2*col_length+2:0];	//The pair list, an abstraction for the tree concept. even - decode 0. odd - decode 1.

reg [2:0]state = `INIT;						//State variable
integer step = 0;								//Number of steps of tree building algorithm
reg [bit_width:0]pos,newpos = 0;				//Variables to hold values of positions in pair table

reg [bit_width:0]col = 'b0;						//Column length
reg [bit_width:0]Data[No_of_Data:0];

integer i= 32'h0;	
integer j= 32'h0;
integer k= 32'h0;							//Loop variables
reg flag = 0;										//Flag
integer pair_count= 0, sym_count = 0;


/*Steps for build_tree:
1)Add 2nd least + least probabilities	
2)Add 2nd least and least in pair table (function add_pair does 2 and 3)
3)Remove least symbol from Huff_list
4)Push sort 

Steps for decode_tree:
1)Search for each element from top.
2)If even, append symbol 0, else 1. Increment code length.
3)If 0, keep going. if 1, do pos - 1. Change variable and do as for 0.
*/

always @(posedge clock) begin

	case(state)
	
	
	`INIT: begin
	Sym_list[0] = 'b0;
	Prob_list[0] = 'b0;
	
	for(j=0;j<col_length;j=j+1) begin
	Code_list[j] = 'bz;
	Prob_list[j] = 'b0;
	Sym_list[j] = 'bz;
	Code_length[j] = 'b0;
	end
	
	
	data_out = 'bz;
	state = `GET_DATA;
	end
	
	
	`GET_DATA: begin
	if(data_enable) begin
		Data[i] = data_in;
		i=i+1'b1;
		
			for(j=0;j<=col_length; j=j+1) begin
				if(data_in == Sym_list[j]) begin
					Prob_list[j] = Prob_list[j] + 1;
					
					begin:SORT
						for(k=j-1;k>=0;k=k-1) begin
							if(Prob_list[k] <= Prob_list[j]) begin
								temp1 = Sym_list[j];
								temp2 = Prob_list[j];
								Sym_list[j] = Sym_list[k];
								Prob_list[j] = Prob_list[k];
								Sym_list[k] = temp1;
								Prob_list[k] = temp2;
								
								Huff_list[j] = Sym_list[j];
								Huff_list[k] = Sym_list[k];
								
							end
						end
					end		//end of Sort	
					flag=1;
				end	//End of if 
			end		//End of for loop
			
				
			if(!flag) begin
				Sym_list[col] = data_in;
				Huff_list[col] = data_in;
				Prob_list[col] = 'b1;
				col = col+1;
			end		
			
			flag= 0;
			
		if(i == No_of_Data)	begin	
		state = `BUILD_TREE;
		sym_count = col;
		//$display("col:",col);
		//for(i=0;i<col_length;i=i+1)
		//$display(Huff_list[i],"  ", Prob_list[i]);
		col = col -1 ;
		end
	end
	end
	
	
	`BUILD_TREE: begin
		code_map_recv = 0;
		data_recv = 0;
		if(col) begin			//One step per cycle
			Prob_list[col-1] = Prob_list[col] + Prob_list[col-1];		//Added probabilities
		
			Pair_list[step] = Huff_list[col-1];			//Add in pair table
			Pair_list[step+1] = Huff_list[col];
		
			col = col - 1;		//removing least symbol
			pair_count = pair_count +2;
		
			begin:SORT1
				for(k=col-1;k>=0;k=k-1) begin
					if(Prob_list[k] < Prob_list[j]) begin
						temp1 = Huff_list[j];
						temp2 = Prob_list[j];
						Huff_list[j] = Huff_list[k];
						Prob_list[j] = Prob_list[k];
						Huff_list[k] = temp1;
						Prob_list[k] = temp2;
					end
				end
			end
			
			step = step + 2;
		end	
		
		else 
			if(col == 0) begin
			state = `DECODE_TREE; 
			//for(i=0;i<2*col_length;i=i+1)
			//$display(Pair_list[i]);
			//$display(sym_count, "  ",pair_count);
			i=0;
			j=0;
			
			Sym = Sym_list[0];
			end
		end
	
	
	`DECODE_TREE: begin
		code_map_recv = 1;
		data_recv = 1;
		//One symbol per cycle decoding
		//i - symbol number, j - iteration for code
		
		if(Sym == Pair_list[j]) begin
		
			if(j%2 == 0) begin
				Code_list[i]= Code_list[i]<<1 | 'b0;
				j=j+2;
			end
				
			else begin
				Code_list[i]= Code_list[i]<<1 | 'b1;
				Sym = Pair_list[j-1]; 
				j=j+1;
			end	
			
			Code_length[i] = Code_length[i] + 1;
		end
		
		else
			j=j+1;
		
		if(j>pair_count-1) begin
			i=i+1;
			j=0;
			Sym = Sym_list[i];
			end
		
		if(i==sym_count)	begin
			state = `SEND_LENGTH;
			//for(k=0;k<col_length;k=k+1)
			//$display(Sym_list[k],"  ","%b",Code_list[k],"  ",Code_length[k]);
			i=0;
		end
		
	end


	`SEND_LENGTH: begin
	//send data in reverse order	
		data_out = Code_length[i];
		i = i+1;
		
		if(i == sym_count) begin
			state = `SEND_CODE;
			i = 0;
			end
		
		data_recv = 1;	
		code_map_recv = 0;
	end
	
	`SEND_CODE: begin
		data_recv = 0;
		code_map_recv = 1;	
		data_out = Code_list[i];
		i = i+1;
		
		if(i == sym_count) begin
			state = `SEND_SYMBOLS;
			i = 0;
			end
		end
	
	`SEND_SYMBOLS: begin
		data_recv = 1;
		code_map_recv = 1;
		data_out = Sym_list[i];
		i = i+1;	
		if(i == sym_count)
			state = `GET_DATA;
		end
	
	endcase
end



endmodule
		
