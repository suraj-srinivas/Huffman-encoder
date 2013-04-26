/* test bench */
`timescale 1ns / 1ps

module huff_encoder_tb;

  // Inputs
	reg clock;
	reg [2:0] data_in;
	reg data_enable;

	// Outputs
	wire [6:0] data_out;
	wire data_recv;
	wire code_map_recv;
   
	integer i,handle;
	integer seed = 1;
	
	// Instantiate the Unit Under Test (UUT)
	huff_encoder #(2,8,20) uut (
		.clock(clock), 
		.data_in(data_in), 
		.data_enable(data_enable), 
		.data_out(data_out), 
		.data_recv(data_recv), 
		.code_map_recv(code_map_recv)
	);


	initial begin 
	forever #10 clock = ~clock;
	end
	
	initial begin
		// Initialize Inputs
		
		$log("verilog.log");
		clock = 0;
		data_in = 0;
		data_enable = 0;
		
		handle = $fopen ("Output.txt");
		handle = handle | 1;
		
		$fmonitor(1,"clock:",clock," data_recv:",data_recv,"   code_map:",code_map_recv,"   data_enable:", data_enable,"   data_out:%b",data_out,"   data_in:%b",data_in);
		
		for(i=0;i<22;i=i+1) begin 
				#20 data_enable=1;
				data_in = $random(seed);
		end
		
		#10
		data_in = 'bz;
		data_enable = 0;
		
		#2100;
		$finish;
		$fclose(handle);

	end
      
endmodule
