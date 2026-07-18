`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/24/2023 11:48:40 AM
// Design Name: 
// Module Name: mem_wrapper
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module mem_wrapper_tapeout
			#(
				parameter INSTRUCTION = 0,
				parameter MEM_ADDR_BITS = 11
			) 
(

    input clk,
    input reset,
    input req,
    input write,
	input [3:0] wen,
	input [21:0] addr,
	input [31:0] wdata,
	output reg [31:0] rdata,
	output wire        ready

    );
    
localparam	IDLE = 0, WRITE = 1, READ = 2, HIT = 3;					
localparam	STATE_BITS = 2; 
localparam	MAX_DELAY = 4'd5; 	

	wire mem_valid;
	wire mem_instr;
	reg  mem_ready;
	reg  mem_write;
	reg  mem_write_reg;
	reg [127:0] mem_wdata;
	wire [127:0] mem_rdata;
    
    reg  [127:0] mem_reg;
	reg  [MEM_ADDR_BITS-1:0] addr_write;
	reg  [MEM_ADDR_BITS-1:0] addr_read;
	reg  [21:0] mem_rdata_reg;
	reg [MEM_ADDR_BITS-1:0] mem_addr;
	
	reg         dirty_bit;
	reg [31:0]  wdata_reg;
	
	wire [MEM_ADDR_BITS-1:0] addr_tmp;
	
	wire [MEM_ADDR_BITS-1:0] addr_debug = addr[MEM_ADDR_BITS-1+2:2];
	reg [3:0]  cnt;
    reg	[STATE_BITS-1:0]		state, next_state;
    
    reg req_reg;
    
    reg ce_en;
assign ready = (state == HIT);
/////////////////////////////////////////////////////////////////////////////////////
// FSM
/////////////////////////////////////////////////////////////////////////////////////   
  always @(posedge clk, negedge reset)
  begin
		if (!reset)
		begin
			state <= IDLE;
			//ready <= 1'b0;
		end
		else
		begin
			state <= next_state;		
			//ready <= (state == HIT);
		end
  end	
	
	    always @*
  begin
	case (state)
		IDLE	: 	if (req)		
						//next_state = HIT;
						next_state = (write)? WRITE : READ; 
					else 
					   next_state = IDLE;
	
		WRITE	:	if (mem_ready)				next_state = HIT;	
					else						next_state = WRITE;	
		READ	: 	if (mem_ready) 				next_state = HIT; 
					else 						next_state = READ;	
		HIT		: next_state = IDLE; 
	endcase
  end
	


assign addr_tmp = addr_write;
	
	always @(posedge clk or negedge reset)
	   if (!reset) begin
	        addr_write <= {MEM_ADDR_BITS{1'b0}};
//	        addr_read  <= 11'b00;
	   end
	   else if (cnt == MAX_DELAY && ((state == WRITE) |(state == READ)))
	       addr_write <= addr[MEM_ADDR_BITS-1+2:2];
//	   else if (cnt == 4'b1111 && (state == READ)) 
//	       addr_write <= addr[13:2];
	       
	       
	always @(posedge clk) begin
	  	   cnt <= 4'b00;
	  if (req && ~ready)
	       cnt <= cnt + 1'b1;
	  end 
	
	always @(posedge clk) begin
	     mem_ready <= 1'b0;
	   if (req && (state == IDLE) && (addr[13:2] == addr_tmp) )
	     mem_ready <= 1'b1;
	   else if (cnt == MAX_DELAY)
         mem_ready <= 1'b1;
       end  
       
  	always @(posedge clk or negedge reset) 
  	   if(!reset)
	     wdata_reg <= 32'b0;
	   else if (req && (state == IDLE))
	     wdata_reg <= wdata; 
	     
	always @(posedge clk or negedge reset)
	 if(!reset)rdata <= 32'h0;
	else if(state == READ) begin
		rdata <= (addr[1:0]== 2'b11)? mem_reg[31:0] : (addr[1:0]== 2'b10)?
		mem_reg[63:32]:(addr[1:0]== 2'b01)? mem_reg[95:64]:(addr[1:0]== 2'b00)?mem_reg[127:96]:32'hffffffff;
	end            
    //assign mem_write = (wen[0] | wen[1] | wen[2]  | wen[3]) && valid &&  ready;
	always @(posedge clk or negedge reset)
	   if (!reset) begin
	       mem_reg <= 128'b00;
	    end
	else if (((state == READ) || (state == WRITE)) && ~mem_ready)
	       mem_reg <= mem_rdata;
	//end
	 else if ((state == WRITE)) begin
		if (wen[0] && addr[1:0]== 2'b11) mem_reg[  7:  0] <= wdata_reg[ 7: 0];
		if (wen[1] && addr[1:0]== 2'b11) mem_reg[ 15:  8] <= wdata_reg[15: 8];
		if (wen[2] && addr[1:0]== 2'b11) mem_reg[ 23: 16] <= wdata_reg[23:16];
		if (wen[3] && addr[1:0]== 2'b11) mem_reg[ 31: 24] <= wdata_reg[31:24];
		if (wen[0] && addr[1:0]== 2'b10) mem_reg[ 39: 32] <= wdata_reg[ 7: 0];
		if (wen[1] && addr[1:0]== 2'b10) mem_reg[ 47: 40] <= wdata_reg[15: 8];
		if (wen[2] && addr[1:0]== 2'b10) mem_reg[ 55: 48] <= wdata_reg[23:16];
		if (wen[3] && addr[1:0]== 2'b10) mem_reg[ 63: 56] <= wdata_reg[31:24];
		if (wen[0] && addr[1:0]== 2'b01) mem_reg[ 71: 64] <= wdata_reg[ 7: 0];
		if (wen[1] && addr[1:0]== 2'b01) mem_reg[ 79: 72] <= wdata_reg[15: 8];
		if (wen[2] && addr[1:0]== 2'b01) mem_reg[ 87: 80] <= wdata_reg[23:16];
		if (wen[3] && addr[1:0]== 2'b01) mem_reg[ 95: 88] <= wdata_reg[31:24];
		if (wen[0] && addr[1:0]== 2'b00) mem_reg[103: 96] <= wdata_reg[ 7: 0];
		if (wen[1] && addr[1:0]== 2'b00) mem_reg[111:104] <= wdata_reg[15: 8];
		if (wen[2] && addr[1:0]== 2'b00) mem_reg[119:112] <= wdata_reg[23:16];
		if (wen[3] && addr[1:0]== 2'b00) mem_reg[127:120] <= wdata_reg[31:24];
		//if (!mem_write) mem_wdata[127:0] <= 128'h00;
	end

	
	
	always @(negedge clk or negedge reset)
	   if (!reset) begin
	       mem_wdata <= 128'b00;
	    end
	    else if ((state == HIT) && dirty_bit)
	       mem_wdata <= mem_reg;
    
     //assign mem_addr = (mem_write)? addr_write : addr[MEM_ADDR_BITS-1+2:2];
     
     always @(negedge clk or negedge reset) 
     if(!reset)
           mem_addr <= 'h0;
	     else if((state == IDLE) && req && (addr[MEM_ADDR_BITS-1+2:2] != addr_tmp) && dirty_bit)
	       mem_addr <= addr_write;
	    else //if ((state == IDLE) && req )
	       mem_addr <= addr[MEM_ADDR_BITS-1+2:2];


     always @(negedge clk) begin
	       mem_write <= 1'b0;
	     if((state == IDLE) && req && (addr[MEM_ADDR_BITS-1+2:2] != addr_tmp) && dirty_bit)
	       mem_write <= 1'b1;
     end 
     
     always @(negedge clk or negedge reset)
	   if (!reset) 
	       dirty_bit <= 1'b0;
	   else if (state == WRITE)
	       dirty_bit <= 1'b1;
	  // else if ((state == IDLE) && req )
	   else if((state == IDLE) && req && (addr[MEM_ADDR_BITS-1+2:2] != addr_tmp) && dirty_bit)
	       dirty_bit <= 1'b0;
     
     always @(negedge clk or negedge reset)
       if (!reset)
        ce_en <= 1'b1;
     else if((state == IDLE) && req && (addr[MEM_ADDR_BITS-1+2:2] != addr_tmp))
        ce_en <= 1'b0;
     else if  (req_reg && ce_en)
        ce_en <= 1'b0;
     else
     ce_en <= 1'b1;
     
   always @(negedge clk or negedge reset)
	   if (!reset) 
	       req_reg <= 1'b0;
	   else if((state == IDLE) && req && (addr[MEM_ADDR_BITS-1+2:2] != addr_tmp) && dirty_bit)
	       req_reg <= 1'b1;
	   else if( ((state == READ) || (state == WRITE)) && ce_en)
	       req_reg <= 1'b0;
     
//     TS1N40LPA2048X128M4F inst_mem (
//			.PD(1'b0), .CLK(clk), .CEB(ce_en), .WEB(~mem_write),
//                        .A(mem_addr), .D(mem_wdata), 
//                        .RTSEL(2'b0), .WTSEL(2'b0), 
//                        .Q(mem_rdata)
//                        );
     bram_memory
			#(
				.MEM_DATA_BITS(128),
				.MEM_ADDR_BITS(MEM_ADDR_BITS),
				.INSTRUCTION(INSTRUCTION)
			) inst_mem
			(
				.clk(clk),
				.mem_req(1'b0),
				.mem_write(mem_write),
				.mem_addr(mem_addr),
				.mem_wdata(mem_wdata),
				.mem_rdata(mem_rdata)
			);
    
    
endmodule
