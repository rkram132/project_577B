`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   19:31:26 10/19/2022
// Design Name:   input_controller
// Module Name:   /home/ise/polarit_check_on_reset/tb_input_controller_contention_check.v
// Project Name:  polarit_check_on_reset
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: input_controller
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module tb_input_controller_contention_check;

	// Inputs
	reg si;
	reg clk;
	reg reset;
	reg [63:0] di;
	reg polarity;
	reg grant_arbiter_1;
	reg grant_arbiter_2;

	// Outputs
	wire ri;
	wire [63:0] output_1;
	wire [63:0] output_2;


	wire [63:0] input_buffer_for_odd_packets, input_buffer_for_even_packets;
	wire [2:0] state,next_state;

	assign  input_buffer_for_odd_packets = uut.input_buffer_for_odd_packets;
	assign  input_buffer_for_even_packets = uut.input_buffer_for_even_packets;
	assign  state = uut.state;
	assign  next_state = uut.next_state;

	// Instantiate the Unit Under Test (UUT)
	input_controller uut (
		.si(si), 
		.clk(clk), 
		.reset(reset), 
		.ri(ri), 
		.di(di), 
		.output_1(output_1), 
		.output_2(output_2), 
		.polarity(polarity), 
		.grant_arbiter_1(grant_arbiter_1), 
		.grant_arbiter_2(grant_arbiter_2)
	);


integer fp;
initial begin
fp = $fopen("o_p_of_testbench.txt", "w");
$fmonitor(fp, "At time = %3d ns, clk = %d, reset= %d, polarity= %d", $time,clk,reset,polarity);
end

// We have a 4ns clock
parameter clk_period = 4;
always #(clk_period/2) clk = ~clk;


	initial begin
		// Initialize Inputs
		clk = 1;
		reset = 1;
		grant_arbiter_1 = 0;
		grant_arbiter_2 = 0;
		//data is stored in previous routers output even buffer | cw direction packet flow intended
		// di = 64'bvc_dir_reserved_hopvalue_source_payload;
		#(2 * clk_period); //reset for 4 clocks
	
		# (0.5 * clk_period);//update which data to send in negedge of clock
		reset = 0;
		si = 1;
		di = 64'b0_0_000000_00000111_0000000000000000_00000000000000000000000000000001; // 3 hops
		# (0.5 * clk_period); // posedge where external even buffer transfers to internal even buffer
		polarity = 1;
		grant_arbiter_1 = 0;
		grant_arbiter_2 = 0;
		
		# (0.5 * clk_period);//update which data to send in negedge of clock for to be captured in posedge of clock
		si = 1;
		di = 64'b1_0_000000_00000001_0000000000000000_00000000000000000000000000000010; // 1 hops
		# (0.5 * clk_period);// posedge where next o/p packet gets into system in odd buffer | inside transfer of even buffer happens
		// posedge where external odd buffer transfers to internal odd buffer
		polarity = 0;
		grant_arbiter_1 = 1;
		grant_arbiter_2 = 0;
		
		# (0.5 * clk_period);//update which data to send in negedge of clock
		si = 1;
		di = 64'b0_0_000000_00000011_0000000000000000_00000000000000000000000000000011; // 2 hops // Note the vc bit
		# (0.5 * clk_period);// posedge where next o/p packet gets into system in even buffer | inside transfer of odd buffer happens
		// posedge where external even buffer transfers to internal odd buffer
		polarity = 1;
		grant_arbiter_1 = 0;
		grant_arbiter_2 = 0;
		
		# (0.5 * clk_period);//update which data to send in negedge of clock
		si = 1;
		di = 64'b1_0_000000_00000111_0000000000000000_00000000000000000000000000000011; // 3 hops
		# (0.5 * clk_period);// posedge where next o/p packet gets into system
		polarity = 0;
		grant_arbiter_1 = 1;
		grant_arbiter_2 = 0;
	
		# (0.5 * clk_period);//update which data to send in negedge of clock
		si = 1;
		di = 64'b1_0_000000_00000111_0000000000000000_00000000000000000000000000000011; // 3 hops
		# (0.5 * clk_period);// posedge where next o/p packet gets into system
		polarity = 1;
		grant_arbiter_1 = 1;
		grant_arbiter_2 = 0;
	
		#(4 * clk_period); //Let it run for 4 clocks
		// First test is to just see that input buffers take in value and pass it in straightforward condition when there is no grant issues (for o/p buffer side first, will check for the pe o/p bufferes later)
		
		// Wait 100 ns for global reset to finish
        
		// Add stimulus here
		$finish;
	end
		

/*	initial begin
		// Initialize Inputs
		si = 0;
		clk = 0;
		reset = 0;
		di = 0;
		polarity = 0;
		grant_arbiter_1 = 0;
		grant_arbiter_2 = 0;

		// Wait 100 ns for global reset to finish
		#100;
        
		// Add stimulus here

	end
	*/
      
endmodule

