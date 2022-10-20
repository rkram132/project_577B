`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    18:41:07 10/16/2022 
// Design Name: 
// Module Name:    input_controller 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module input_controller(
    input si,
	 input clk,
	 input reset,
    output reg ri, //RI should also indicate whether the input buffer is empty or not
    input [63:0] di,
	 output reg [63:0] output_1, 
	 output reg [63:0] output_2,
	 input polarity,
	 input grant_arbiter_1,
	 input grant_arbiter_2
    );

//output reg ri;
//output reg [63:0] output_1, output_2;


// Need only 1 buffer right?? as at one point only 1 packet exists at a time in the buffer -> NO
reg [63:0] input_buffer_for_odd_packets;
reg [63:0] input_buffer_for_even_packets;

//reg grant_arbiter_1;
//reg grant_arbiter_2;
// This tells the i/p controller that it has been allowed to send its data to the relevant o/p Buffer
							 // This is a internal variable, On the arbiter end, there should be 2 such signals going to .....
							 //........the input ctrl of say cw and that of pe to tell which of the two actually gor the permission to send........
							 //.....in there packetes to the o/p buffer

reg [2:0] state,next_state;

parameter idle = 3'b000;
parameter odd_clock_injection_to_even_input_buffer = 3'b001;
parameter contention_at_either_input_or_pe_arbiters_for_input_even_buffer = 3'b010; // So either of the arbiters grant can be 0 and if they are not able to flow to o/p buffer, we then have to stop the flow behind this register
parameter transfer_to_pe_out_even_buffer = 3'b011;
parameter transfer_to_even_output_buffer = 3'b100;
parameter transfer_to_odd_output_buffer = 3'b101;
parameter transfer_to_pe_out_odd_buffer = 3'b110;
parameter contention_at_either_input_or_pe_arbiters_for_input_odd_buffer = 3'b111;


//*********************************
//******state memory block*********
//*********************************
	always @(posedge clk) begin
		if (reset) begin
			state <= idle;
		end
		else begin
			state <= next_state;
		end	
		
	end

//*********************************
//***** next state logic block*****
//*********************************
	always @(*) begin //basically all i/p changes to be considered
		
		case (state)
			//****************************************	0		
			idle: begin
			
				if (si== 1 && polarity == 1 && grant_arbiter_1 == 1) 
					next_state =  odd_clock_injection_to_even_input_buffer;
					
				else if (si ==1 && polarity == 0 && grant_arbiter_1 == 1)
					next_state =  transfer_to_pe_out_even_buffer;
				else
					next_state = state;
				
			end		
			//****************************************	1
			odd_clock_injection_to_even_input_buffer: begin
				
				if ( input_buffer_for_even_packets[48] != 0 && grant_arbiter_1 == 1 && polarity == 0 && si) begin
					
						//input_buffer_for_even_packets[48] REPRESENTS the LSB of hop count
						input_buffer_for_even_packets[55:48] = input_buffer_for_even_packets[55:48]>>1; // hop updated // Q. NEED to check if this is ok in moore
						next_state = transfer_to_even_output_buffer;
				
						end
				
				else if ( input_buffer_for_even_packets[48] == 0 && grant_arbiter_2 == 1 && polarity == 0 && si) begin
						
						//No reduction to hop as it was 0; can still keep it wont matter as right shift to 0's is still 0;
						next_state = transfer_to_pe_out_even_buffer;
						
						end
				
				// Maybe can make this else as we should go here regardless
				// Wont polarity be 0 just after this state anyways, so maybe don't need to put
				else if ((grant_arbiter_1 == 0 && input_buffer_for_even_packets[48] != 0 && polarity == 0) || (grant_arbiter_2 == 0 && input_buffer_for_even_packets[48] == 0 && polarity == 0)) begin
				
						next_state = contention_at_either_input_or_pe_arbiters_for_input_even_buffer;
				
						end
				
				else
					next_state = state; // Maybe take to idle instead
				
			end
			//****************************************	2
			// This state will come only if neither of the routers from previous 
			contention_at_either_input_or_pe_arbiters_for_input_even_buffer: begin
				
				if (polarity == 1) begin
						next_state = state;
						end
						
				else if (input_buffer_for_even_packets[48] != 0 && grant_arbiter_1 == 0 && polarity == 0 && si) begin
						input_buffer_for_even_packets[55:48] = input_buffer_for_even_packets[55:48]>>1; // hop updated // Q. NEED to check if this is ok in moore
						next_state = transfer_to_even_output_buffer;
						end
				
				else if (input_buffer_for_even_packets[48] == 0 && grant_arbiter_2 == 1 && polarity == 0 && si) begin
						
						next_state = transfer_to_pe_out_even_buffer;
						end
						
				else
				next_state = state;
				
			end
			//****************************************	3
			transfer_to_pe_out_even_buffer: begin
				
				if (input_buffer_for_odd_packets[48] != 0 && grant_arbiter_1 == 1 && polarity == 1 && si) begin
						
						input_buffer_for_odd_packets[55:48] = input_buffer_for_odd_packets[55:48]>>1;
						next_state = transfer_to_odd_output_buffer;
						
						end
				// Note that the brown lines from v1.1 are not including si as they seem irrelevant		
				else if (input_buffer_for_odd_packets[48] == 0 && grant_arbiter_2 == 1 && polarity == 1 && si) begin //si is not relevant as data must still keep flowing
					
						input_buffer_for_odd_packets[55:48] = input_buffer_for_odd_packets[55:48]>>1;
						next_state = transfer_to_pe_out_odd_buffer;
						
						end

				else if ((grant_arbiter_1 == 0 && input_buffer_for_odd_packets[48] != 0 && polarity == 1) || (grant_arbiter_2 == 0 && input_buffer_for_odd_packets[48] == 0 && polarity == 1)) begin
				
						next_state = contention_at_either_input_or_pe_arbiters_for_input_odd_buffer;
						
						end
						
				else
						next_state = state;
				
				
			end
			//****************************************	4
			transfer_to_even_output_buffer: begin
				
				if (input_buffer_for_odd_packets[48] != 0 && grant_arbiter_1 == 1 && polarity == 1 && si) begin
						
						input_buffer_for_odd_packets[55:48] = input_buffer_for_odd_packets[55:48]>>1;
						next_state = transfer_to_odd_output_buffer;
						
						end
				
				else if (input_buffer_for_odd_packets[48] == 0 && grant_arbiter_2 == 1 && polarity == 1 && si) begin
						
						next_state = transfer_to_pe_out_odd_buffer;
						
						end

				else if ((grant_arbiter_1 == 0 && input_buffer_for_odd_packets[48] != 0 && polarity == 1) || (grant_arbiter_2 == 0 && input_buffer_for_odd_packets[48] == 0 && polarity == 1)) begin
						
						next_state = transfer_to_pe_out_odd_buffer;
						
						end
						
				else
						next_state = state;
				
			end
			//****************************************	5
			transfer_to_odd_output_buffer: begin
				
				if (input_buffer_for_even_packets[48] == 0 && grant_arbiter_2 == 1 && polarity == 0 && si) begin
						
						next_state = transfer_to_pe_out_even_buffer;
						
						end
				
				else if (input_buffer_for_even_packets[48] != 0 && grant_arbiter_1 == 1 && polarity == 0 && si) begin
						
						input_buffer_for_even_packets[55:48] = input_buffer_for_even_packets[55:48]>>1;
						next_state = transfer_to_even_output_buffer;
						
						end
						
				else if ((grant_arbiter_1 == 0 && input_buffer_for_even_packets[48] != 0 && polarity == 0) || (grant_arbiter_2 == 0 && input_buffer_for_even_packets[48] == 0 && polarity == 0)) begin
				
						next_state = contention_at_either_input_or_pe_arbiters_for_input_even_buffer;
				
						end
						
				else
						next_state = state;
					
			end
			//****************************************	6
			transfer_to_pe_out_odd_buffer: begin
			
				if(input_buffer_for_even_packets[48] != 0 && grant_arbiter_1 == 1 && polarity == 0 && si) begin
						
						input_buffer_for_even_packets[55:48] = input_buffer_for_even_packets[55:48]>>1;
						next_state = transfer_to_even_output_buffer;
						end
						
				else if(input_buffer_for_even_packets[48] == 0 && grant_arbiter_2 == 1 && polarity == 1 && si) begin
						
						input_buffer_for_even_packets[55:48] = input_buffer_for_even_packets[55:48]>>1;
						next_state = transfer_to_pe_out_even_buffer;
						end	

				else if ((grant_arbiter_1 == 0 && input_buffer_for_even_packets[48] != 0 && polarity == 0) || (grant_arbiter_2 == 0 && input_buffer_for_even_packets[48] == 0 && polarity == 0)) begin
				
						next_state = contention_at_either_input_or_pe_arbiters_for_input_even_buffer;
				
						end						
						
				else 
						next_state = state;
			
				
			end
			//****************************************	7
			contention_at_either_input_or_pe_arbiters_for_input_odd_buffer: begin
			
				if (polarity == 0) begin
						next_state = state;
						end
						
				else if (input_buffer_for_odd_packets[48] != 0 && grant_arbiter_1 == 1 && polarity == 1 && si) begin
						input_buffer_for_odd_packets[55:48] = input_buffer_for_odd_packets[55:48]>>1; // hop updated // Q. NEED to check if this is ok in moore
						next_state = transfer_to_odd_output_buffer;
						end
				
				else if (input_buffer_for_even_packets[48] == 0 && grant_arbiter_2 == 1 && polarity == 0 && si) begin
						
						next_state = transfer_to_pe_out_even_buffer;
						end
						
				else
				next_state = state;
			
				
			end
		endcase

	end	
		


//output logic block
	always @(state) begin

		case (state)
		
			idle: begin
					ri = 1;
					input_buffer_for_odd_packets = 0;
					input_buffer_for_even_packets = 0;					
			end
	//*******************************************************************************************************			
			odd_clock_injection_to_even_input_buffer: begin
					
					ri = 1;
					input_buffer_for_even_packets = di;
					output_1 = 0; // The outputs = 0 have to be taken as that the packet is not valid
					output_2 = 0;
					
			end
	//*******************************************************************************************************					
			contention_at_either_input_or_pe_arbiters_for_input_even_buffer: begin
					
					ri = 0;
					output_1 = 0;
					output_2 = 0;			
			end
	//*******************************************************************************************************					
			transfer_to_pe_out_even_buffer: begin
					
					ri = 1;
					output_1 = 0;
					output_2 = input_buffer_for_even_packets;
					input_buffer_for_odd_packets = di;
								
			end
	//*******************************************************************************************************					
			transfer_to_even_output_buffer: begin
					
					ri = 1;
					output_1 = input_buffer_for_even_packets;
					output_2 = 0;
					input_buffer_for_odd_packets = di;
					
								
			end
	//*******************************************************************************************************					
			transfer_to_odd_output_buffer: begin
					
					ri = 1;
					output_1 = input_buffer_for_odd_packets;
					output_2 = 0;
					input_buffer_for_even_packets = di;
								
			end
	//*******************************************************************************************************					
			transfer_to_pe_out_odd_buffer: begin
					
					ri = 1;
					output_1 = 0;
					output_2 = input_buffer_for_odd_packets;
					input_buffer_for_even_packets = di;
								
			end
	//*******************************************************************************************************					
			contention_at_either_input_or_pe_arbiters_for_input_odd_buffer: begin
					
					ri = 1;
					output_1 = 0;
					output_2 = 0;
								
			end	
	
		endcase
	
	end


endmodule
