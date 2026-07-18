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
module AHB2CW
(
	//AHBLITE INTERFACE
		//Slave Select Signals
			input wire HSEL,
		//Global Signal
			input wire HCLK,
			input wire HRESETn,
		//Address, Control & Write Data
			input wire HREADY,
			input wire [31:0] HADDR,
			input wire [1:0] HTRANS,
			input wire HWRITE,
			input wire [2:0] HSIZE,
			
			input wire [31:0] HWDATA,
		// Transfer Response & Read Data
			output wire HREADYOUT,
			output reg [31:0] HRDATA,
			
			input wire        [127:0]                   crypto_key,
			input  wire       [127:0]                   crypto_pt,		
			output  wire      [127:0]                  crypto_ct,
			input    wire                              crypto_start,
			output  wire                                crypto_done,
			output wire                                 crypto_trigger
);
  
	reg                             	start;
	reg									done;
	reg                                trigger;
	reg        [127:0]                   key;
	reg        [127:0]                   pt;		
	reg       [127:0]                    ct;
   
// Registers to store Adress Phase Signals
  reg APhase_HSEL;
  reg APhase_HWRITE;
  reg [1:0] APhase_HTRANS;
  reg [31:0] APhase_HADDR;
  reg [2:0] APhase_HSIZE;

    
  assign HREADYOUT = 1'b1; // Always ready
    assign crypto_ct = ct;
    assign crypto_done = done;
    assign crypto_trigger = trigger;


  
// Sample the Address Phase   
  always @(posedge HCLK or negedge HRESETn)
  begin
	 if(!HRESETn)
	 begin
		APhase_HSEL <= 1'b0;
      APhase_HWRITE <= 1'b0;
      APhase_HTRANS <= 2'b00;
		APhase_HADDR <= 32'h0;
		APhase_HSIZE <= 3'b000;
	 end
    else if(HREADY)
    begin
      APhase_HSEL <= HSEL;
      APhase_HWRITE <= HWRITE;
      APhase_HTRANS <= HTRANS;
		APhase_HADDR <= HADDR;
		APhase_HSIZE <= HSIZE;
    end
  end


/// REGISTERS ADDRESSING
///// 0 - START REG
///// 1 - DONE REG
///// 2,3,4,5 - KEY REG
///// 6,7,8,9 - PT REG
///// A,B,C,D - CT REG

  always @(posedge HCLK, negedge HRESETn)
  begin	
	if (!HRESETn)
	begin
		start <= 0;
		done <= 0;
		trigger <= 0;
		key <= {128{1'b0}};
		pt <= {128{1'b0}};
		ct <= {128{1'b0}};
	end
	else
	begin
		start <= crypto_start;
		key <= crypto_key;
		pt <= crypto_pt;
		
		if(APhase_HSEL & APhase_HWRITE & APhase_HTRANS[1])
		begin
		    if (APhase_HADDR[5:2] == 4'b1110)
		      trigger <= HWDATA;
			else 
			if (APhase_HADDR[5:2] == 4'b0001)
			begin
				done <=  HWDATA;
			end
			else
			begin
				case(APhase_HADDR[5:2])
					4'b1010: ct[31:0] <=  HWDATA;
					4'b1011: ct[63:32] <=  HWDATA;
					4'b1100: ct[95:64] <=  HWDATA;
					4'b1101: ct[127:96] <=  HWDATA;
				endcase 				
			end
		end
	end
  end

// Reading from memory 
	always @*
	begin
		case(APhase_HADDR[5:2])
		4'b0000: HRDATA = start;
		4'b0001: HRDATA = done;
		4'b0010: HRDATA = key[31:0];
		4'b0011: HRDATA = key[63:32];
		4'b0100: HRDATA = key[95:64];
		4'b0101: HRDATA = key[127:96];
		4'b0110: HRDATA = pt[31:0];
		4'b0111: HRDATA = pt[63:32];
		4'b1000: HRDATA = pt[95:64];
		4'b1001: HRDATA = pt[127:96];
		4'b1010: HRDATA = ct[31:0];
		4'b1011: HRDATA = ct[63:32];
		4'b1100: HRDATA = ct[95:64];
		4'b1101: HRDATA = ct[127:96];
		4'b1110: HRDATA = trigger;
		default: HRDATA = 32'hC0FFEE;
		endcase
	end
  	
endmodule
