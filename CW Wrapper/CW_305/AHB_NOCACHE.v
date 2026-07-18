`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/24/2023 11:07:35 AM
// Design Name: 
// Module Name: AHB_NOCACHE
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

//  --========================================================================--
//  Version and Release Control Information:
//
//  File Name           : AHB2MEM.v
//  File Revision       : 1.00
//
//  ----------------------------------------------------------------------------
//  Purpose             : Basic AHBLITE Internal Memory Default Size = 32KB
//                        
//  --========================================================================--

`define SIMULATION

module AHB2BRAM_DP
#(parameter MEMWIDTH = 128,					// SIZE = 32KB = 8k Words
  parameter MEMDEPTH = 15,
  parameter INIT_FILE = "code_data.hex")
	(
	//AHBLITE INTERFACE
		//Slave Select Signals
			input wire HCLK,
			input wire HRESETn,
		// INST MEM
			input wire ins_HSEL,
		//Address, Control & Write Data
			input wire ins_HREADY,
			input wire [31:0] ins_HADDR,
			input wire [1:0] ins_HTRANS,
			input wire ins_HWRITE,
			input wire [2:0] ins_HSIZE,
			
			input wire [31:0] ins_HWDATA,
		// Transfer Response & Read Data
			output reg ins_HREADYOUT,
			output wire [31:0] ins_HRDATA,
			
		// DATA MEM
			input wire dat_HSEL,
		//Address, Control & Write Data
			input wire dat_HREADY,
			input wire [31:0] dat_HADDR,
			input wire [1:0] dat_HTRANS,
			input wire dat_HWRITE,
			input wire [2:0] dat_HSIZE,
			
			input wire [31:0] dat_HWDATA,
		// Transfer Response & Read Data
			output reg dat_HREADYOUT,
			output wire [31:0] dat_HRDATA
);

// Registers to store Adress Phase Signals
 
  reg APhase_HSEL_A;
  reg APhase_HWRITE_A;
  reg [1:0] APhase_HTRANS_A;
  reg [31:0] APhase_HADDR_A;
  reg [2:0] APhase_HSIZE_A;
  wire			MEM_SEL_A;
  wire			MEM_WR_A;
  wire [21:0]	MEM_ADDR_A;
  wire [7:0]	PART0_A,PART1_A,PART2_A,PART3_A;
  wire [31:0]	write_data_A;
  
  reg APhase_HSEL_B;
  reg APhase_HWRITE_B;
  reg [1:0] APhase_HTRANS_B;
  reg [31:0] APhase_HADDR_B;
  reg [2:0] APhase_HSIZE_B;
  wire			MEM_SEL_B;
  wire			MEM_WR_B;
  wire [21:0]	MEM_ADDR_B;
  wire [7:0]	PART0_B,PART1_B,PART2_B,PART3_B;
  wire [31:0]	write_data_B;
  
  
  // WIRES TO MEMORY MODULE
wire	[31:0]		    mem_rdata;
wire	[31:0]		    mem_wdata;
wire	[21:0]		    mem_addr;
reg							mem_req;
wire							mem_write;
wire							mem_rdy;
wire [3:0] mem_wstrb                   ;

wire [3:0]                  mem_wstrb_B;
reg							mem_req_B;
wire						mem_rdy_B;

//// Memory Array  
//  reg [31:0] Mem_DP	[0:(2**(MEMWIDTH-2)-1)];
  
//  integer i;
//  initial
//  begin			
//	$readmemh(INIT_FILE, Mem_DP);
//  end

// Main process to sample signals
always @(posedge HCLK, negedge HRESETn)
begin
    // RESET
    if(!HRESETn)
    begin
		ins_HREADYOUT  	<= 1'b1;
		
		APhase_HSEL_A   <= 1'b0;
        APhase_HWRITE_A <= 1'b0;
        APhase_HTRANS_A <= 2'b00;
		APhase_HADDR_A  <= 32'h0;
		APhase_HSIZE_A  <= 3'b000;	
		//mem_req         <= 1'b0;
    end
    // IF READY, SAMPLE INPUT
    else 
    begin
        if (ins_HREADY)
        begin
			APhase_HSEL_A   <= ins_HSEL;
			APhase_HWRITE_A <= ins_HWRITE;
			APhase_HTRANS_A <= ins_HTRANS;
			APhase_HADDR_A  <= ins_HADDR;
			APhase_HSIZE_A  <= ins_HSIZE;	
        end 
           
//        // Cache data input logic
//        if(ins_HSEL & (ins_HTRANS == 2))
//        begin
//            DataPhase       <=  1'b1;
//        end
//        else
//        begin
//            DataPhase       <=  1'b0;
//        end
            
//        // Read correct data during AHB data phase
//        if (DataPhase)
//        begin
//            APhase_HWDATA_A   <=  ins_HWDATA;
//        end
            
        // Process to handle READY output
        if (mem_rdy)
        begin
            ins_HREADYOUT <= 1'b1;
            //mem_req       <= 1'b0;
        end
        else if (ins_HSEL & (ins_HTRANS == 2))
        begin
            ins_HREADYOUT <= 1'b0; 
            //mem_req       <= 1'b1;
        end
    end
end


always @(posedge HCLK, negedge HRESETn)
begin
    // RESET
    if(!HRESETn)
    begin
		dat_HREADYOUT  	<= 1'b1;
		
		APhase_HSEL_B   <= 1'b0;
        APhase_HWRITE_B <= 1'b0;
        APhase_HTRANS_B <= 2'b00;
		APhase_HADDR_B  <= 32'h0;
		APhase_HSIZE_B  <= 3'b000;	
		//mem_req         <= 1'b0;
    end
    // IF READY, SAMPLE INPUT
    else 
    begin
        if (dat_HREADY)
        begin
			APhase_HSEL_B   <= dat_HSEL;
			APhase_HWRITE_B <= dat_HWRITE;
			APhase_HTRANS_B <= dat_HTRANS;
			APhase_HADDR_B  <= dat_HADDR;
			APhase_HSIZE_B  <= dat_HSIZE;	
        end 
           
//        // Cache data input logic
//        if(ins_HSEL & (ins_HTRANS == 2))
//        begin
//            DataPhase       <=  1'b1;
//        end
//        else
//        begin
//            DataPhase       <=  1'b0;
//        end
            
//        // Read correct data during AHB data phase
//        if (DataPhase)
//        begin
//            APhase_HWDATA_A   <=  ins_HWDATA;
//        end
            
        // Process to handle READY output
        if (mem_rdy_B)
        begin
            dat_HREADYOUT <= 1'b1;
            //mem_req       <= 1'b0;
        end
        else if (dat_HSEL & (dat_HTRANS == 2))
        begin
            dat_HREADYOUT <= 1'b0; 
            //mem_req       <= 1'b1;
        end
    end
end




//// Sample the Address Phase   
//  always @(posedge HCLK or negedge HRESETn)
//  begin
//	 if(!HRESETn)
//	 begin
//		ins_HREADYOUT  	<= 1'b1;
		
//		APhase_HSEL_A   <= 1'b0;
//        APhase_HWRITE_A <= 1'b0;
//        APhase_HTRANS_A <= 2'b00;
//		APhase_HADDR_A  <= 32'h0;
//		APhase_HSIZE_A  <= 3'b000;		
//	 end
//    else 
//	begin
//		//ins_HREADYOUT	  <= (ins_HSEL & ins_HTRANS[1] & ins_HWRITE) ? ~ins_HREADYOUT : 1'b1;
//		ins_HREADYOUT	  <= (ins_HSEL & ins_HTRANS[1] & ins_HWRITE) ? mem_rdy : 1'b1; //1'b1;
		
//		//if(HREADY)
//		//begin
//			APhase_HSEL_A   <= ins_HSEL;
//			APhase_HWRITE_A <= ins_HWRITE;
//			APhase_HTRANS_A <= ins_HTRANS;
//			APhase_HADDR_A  <= ins_HADDR;
//			APhase_HSIZE_A  <= ins_HSIZE;				
//		//end
//	end
//  end

//	// Sample the Address Phase   
//  always @(posedge HCLK or negedge HRESETn)
//  begin
//	 if(!HRESETn)
//	 begin
//		dat_HREADYOUT	<= 1'b1;
		
//		APhase_HSEL_B   <= 1'b0;
//        APhase_HWRITE_B <= 1'b0;
//        APhase_HTRANS_B <= 2'b00;
//		APhase_HADDR_B  <= 32'h0;
//		APhase_HSIZE_B  <= 3'b000;		
//	 end
//    else 
//	begin
//		//dat_HREADYOUT  <= (dat_HSEL & dat_HTRANS[1] & dat_HWRITE) ? ~dat_HREADYOUT : 1'b1;
//		dat_HREADYOUT  <= (dat_HSEL & dat_HTRANS[1] & dat_HWRITE) ? mem_rdy : 1'b1;  //1'b1;
		
//		//if(HREADY)
//		//begin
//			APhase_HSEL_B   <= dat_HSEL;
//			APhase_HWRITE_B <= dat_HWRITE;
//			APhase_HTRANS_B <= dat_HTRANS;
//			APhase_HADDR_B  <= dat_HADDR;
//			APhase_HSIZE_B  <= dat_HSIZE;				
//		//end
//	end
//  end
  ///////////////////////////////////////
  ////////////////////// SIDE A
  ////////////////////////////////////// 
// Decode the bytes lanes depending on HSIZE & HADDR[1:0]
  wire tx_byte_A = ~APhase_HSIZE_A[1] & ~APhase_HSIZE_A[0];
  wire tx_half_A = ~APhase_HSIZE_A[1] &  APhase_HSIZE_A[0];
  wire tx_word_A =  APhase_HSIZE_A[1];
  
  wire byte_at_00_A = tx_byte_A & ~APhase_HADDR_A[1] & ~APhase_HADDR_A[0];
  wire byte_at_01_A = tx_byte_A & ~APhase_HADDR_A[1] &  APhase_HADDR_A[0];
  wire byte_at_10_A = tx_byte_A &  APhase_HADDR_A[1] & ~APhase_HADDR_A[0];
  wire byte_at_11_A = tx_byte_A &  APhase_HADDR_A[1] &  APhase_HADDR_A[0];
  
  wire half_at_00_A = tx_half_A & ~APhase_HADDR_A[1];
  wire half_at_10_A = tx_half_A &  APhase_HADDR_A[1];
  
  wire word_at_00_A = tx_word_A;
  
  wire byte0_A = word_at_00_A | half_at_00_A | byte_at_00_A;
  wire byte1_A = word_at_00_A | half_at_00_A | byte_at_01_A;
  wire byte2_A = word_at_00_A | half_at_10_A | byte_at_10_A;
  wire byte3_A = word_at_00_A | half_at_10_A | byte_at_11_A;

// Writing to the memory

  assign MEM_SEL_A  = (ins_HSEL & ins_HTRANS[1]) | (APhase_HSEL_A & APhase_HTRANS_A[1]);
  assign MEM_WR_A   = APhase_HWRITE_A;  
  assign MEM_ADDR_A = APhase_HADDR_A[23:2]; // MEM_WR_A ? APhase_HADDR_A[23:2] : ins_HADDR[23:2];
  
  assign PART0_A = byte0_A ? ins_HWDATA[7:0]   : ins_HRDATA[7:0];
  assign PART1_A = byte1_A ? ins_HWDATA[15:8]  : ins_HRDATA[15:8];
  assign PART2_A = byte2_A ? ins_HWDATA[23:16] : ins_HRDATA[23:16];
  assign PART3_A = byte3_A ? ins_HWDATA[31:24] : ins_HRDATA[31:24];
  
  assign write_data_A = {PART3_A,PART2_A,PART1_A,PART0_A};
  
  ///////////////////////////////////////
  ////////////////////// SIDE B
  //////////////////////////////////////
  wire tx_byte_B = ~APhase_HSIZE_B[1] & ~APhase_HSIZE_B[0];
  wire tx_half_B = ~APhase_HSIZE_B[1] &  APhase_HSIZE_B[0];
  wire tx_word_B =  APhase_HSIZE_B[1];
  
  wire byte_Bt_00_B = tx_byte_B & ~APhase_HADDR_B[1] & ~APhase_HADDR_B[0];
  wire byte_Bt_01_B = tx_byte_B & ~APhase_HADDR_B[1] &  APhase_HADDR_B[0];
  wire byte_Bt_10_B = tx_byte_B &  APhase_HADDR_B[1] & ~APhase_HADDR_B[0];
  wire byte_Bt_11_B = tx_byte_B &  APhase_HADDR_B[1] &  APhase_HADDR_B[0];
  
  wire half_Bt_00_B = tx_half_B & ~APhase_HADDR_B[1];
  wire half_Bt_10_B = tx_half_B &  APhase_HADDR_B[1];
  
  wire word_Bt_00_B = tx_word_B;
  
  wire byte0_B = word_Bt_00_B | half_Bt_00_B | byte_Bt_00_B;
  wire byte1_B = word_Bt_00_B | half_Bt_00_B | byte_Bt_01_B;
  wire byte2_B = word_Bt_00_B | half_Bt_10_B | byte_Bt_10_B;
  wire byte3_B = word_Bt_00_B | half_Bt_10_B | byte_Bt_11_B;

// Writing to the memory

  assign MEM_SEL_B  = (dat_HSEL & dat_HTRANS[1]) | (APhase_HSEL_B & APhase_HTRANS_B[1]);
  assign MEM_WR_B   = APhase_HWRITE_B;  
  assign MEM_ADDR_B = APhase_HADDR_B[23:2];// MEM_WR_B ? APhase_HADDR_B[23:2] : dat_HADDR[23:2];
  //assign MEM_ADDR_B = MEM_WR_B ? APhase_HADDR_B[31:2] : dat_HADDR[31:2];
  
  assign PART0_B = byte0_B ? dat_HWDATA[7:0]   : dat_HRDATA[7:0];
  assign PART1_B = byte1_B ? dat_HWDATA[15:8]  : dat_HRDATA[15:8];
  assign PART2_B = byte2_B ? dat_HWDATA[23:16] : dat_HRDATA[23:16];
  assign PART3_B = byte3_B ? dat_HWDATA[31:24] : dat_HRDATA[31:24];
  
  assign write_data_B = {PART3_B,PART2_B,PART1_B,PART0_B};
  

 
assign mem_wstrb = (MEM_WR_A)? {byte3_A,byte2_A,byte1_A,byte0_A}: 4'b0;
assign mem_wstrb_B = (MEM_WR_B)? {byte3_B,byte2_B,byte1_B,byte0_B}: 4'b0;
//assign mem_wstrb = (MEM_WR_A)? {byte3_A,byte2_A,byte1_A,byte0_A}:(MEM_WR_B)? {byte3_B,byte2_B,byte1_B,byte0_B}:4'b0;
assign mem_write = (MEM_SEL_A)? MEM_WR_A : MEM_WR_B;
//assign ins_HRDATA = mem_rdata;
//assign dat_HRDATA = mem_rdata;
assign mem_addr = (MEM_SEL_A)? MEM_ADDR_A : MEM_ADDR_B;
//assign mem_req = (MEM_SEL_A)? 1'b1: 1'b0; // MEM_SEL_A;


reg cache_req_reg;
//assign mem_req = (ins_HSEL & (ins_HTRANS ==2) ? 1 : (mem_rdy ? 0 : cache_req_reg)) ;

always @(posedge HCLK, negedge HRESETn)
begin
    if(!HRESETn)
        cache_req_reg <= 0;
    else
        cache_req_reg <= mem_req;
end


always @(posedge HCLK, negedge HRESETn)
    if(!HRESETn)
        mem_req       <= 1'b0;
    else if (mem_rdy)
        mem_req       <= 1'b0;
    else if (ins_HSEL & (ins_HTRANS == 2))
        mem_req       <= 1'b1;
        
        
        
always @(posedge HCLK, negedge HRESETn)
    if(!HRESETn)
        mem_req_B       <= 1'b0;
    else if (mem_rdy_B)
        mem_req_B       <= 1'b0;
    else if (dat_HSEL & (dat_HTRANS == 2))
        mem_req_B       <= 1'b1;






 mem_wrapper #(
				.INSTRUCTION(1),
				.MEM_ADDR_BITS(MEMDEPTH)
			)
			mem_wrapper_inst
(

    .clk(HCLK),
    .reset(HRESETn),
    .req(mem_req),
	.wen(mem_wstrb),
	.write(MEM_WR_A),
	.addr(MEM_ADDR_A),
	.wdata(write_data_A),
	.ready(mem_rdy),
	.rdata(ins_HRDATA)
    );
    
    
 mem_wrapper_tapeout #(
				.INSTRUCTION(0),
				.MEM_ADDR_BITS(MEMDEPTH)
			)
			mem_wrapper_data
(

    .clk(HCLK),
    .reset(HRESETn),
    .req(mem_req_B),
	.wen(mem_wstrb_B),
	.write(MEM_WR_B),
	.addr(MEM_ADDR_B),
	.wdata(write_data_B),
	.ready(mem_rdy_B),
	.rdata(dat_HRDATA)
    );
  
// bram_memory
//		#(
//			.MEM_DATA_BITS(MEMWIDTH),
//			.MEM_ADDR_BITS(MEMDEPTH),
//			.INSTRUCTION(INIT_FILE)
//		)
//ram
//		(
//			.clk(HCLK),
//			.mem_req(mem_req),
//			.mem_write(mem_write),
//			.mem_addr(mem_addr),
//			.mem_wdata(mem_wdata),
//			.mem_rdata(mem_rdata)
//		);
  
//  `ifdef SIMULATION
//    always @(posedge HCLK)
//    begin
//        if (MEM_SEL_A) 
//		begin
//          if (MEM_WR_A) 
//		  begin
//            Mem_DP[MEM_ADDR_A] <= write_data_A;
//          end
//          else
//          begin
//            ins_HRDATA <= Mem_DP[MEM_ADDR_A];
//          end
//        end

//        if (MEM_SEL_B) 
//		begin
//          if (MEM_WR_B) 
//		  begin
//            Mem_DP[MEM_ADDR_B] <= write_data_B;
//          end
//          else
//          begin
//            dat_HRDATA <= Mem_DP[MEM_ADDR_B];
//          end
//        end
//    end    
//  `endif
//  ////////////////////////////
//  // XILINX/ALTERA implementation
//  ////////////////////////////

//  `ifndef SIMULATION
//    always @(posedge HCLK)
//    begin
//      if (MEM_SEL_A) 
//	  begin
//        if (MEM_WR_A) 
//		begin
//          Mem_DP[MEM_ADDR_A] <= write_data_A;
//        end
//        else
//        begin
//          ins_HRDATA <= Mem_DP[MEM_ADDR_A];
//        end
//      end
//    end

//    always @(posedge HCLK)
//    begin
//      if (MEM_SEL_B) 
//	  begin
//        if (MEM_WR_B) 
//		begin
//          Mem_DP[MEM_ADDR_B] <= write_data_B;
//        end
//        else
//        begin
//          dat_HRDATA <= Mem_DP[MEM_ADDR_B];
//        end
//      end
//    end
//  `endif

endmodule 

