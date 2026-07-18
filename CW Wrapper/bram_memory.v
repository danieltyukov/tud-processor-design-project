module bram_memory
			#(
				parameter MEM_DATA_BITS = 128,
				parameter MEM_ADDR_BITS = 12,
				parameter INSTRUCTION = 0
			)
			(
				input						clk,
				input						mem_req,
				input						mem_write,
				input [MEM_ADDR_BITS-1:0]	mem_addr,
				input [MEM_DATA_BITS-1:0]	mem_wdata,
				
				output reg [MEM_DATA_BITS-1:0]	mem_rdata
			);

// Memory Array initialization
reg     [MEM_DATA_BITS:0]       memory[0:(2**(MEM_ADDR_BITS)-1)];
//wire we;
integer i;

initial  
begin
if (INSTRUCTION)
//   $readmemh("code128.dat", memory);
      $readmemh("C:/Users/abdul/Downloads/temp/code128.dat", memory);
//      $readmemh("C:/Users/abdul/Downloads/temp/code128_tt.dat", memory);
//      $readmemh("C:/Users/abdul/Downloads/temp/code128_ise.dat", memory);
//   $readmemh("C:/Users/abdul/projects/Software/conversion_scripts/code128_1.dat", memory);
//   $readmemh("C:/Users/abdul/Dropbox/Softcore_codes/conversion_scripts/code128.dat", memory);
//   $readmemh("C:/Users/abdul/projects/Software/conversion_scripts/code128.dat", memory);
 //   $readmemh("C:/Users/abdul/projects/Software/conversion_scripts/code128_rsa_2.dat", memory);
else
//	$readmemh("data128.dat", memory);
	$readmemh("C:/Users/abdul/Downloads/temp/data128.dat", memory);
//	$readmemh("C:/Users/abdul/Downloads/temp/data128_tt.dat", memory);
//	$readmemh("C:/Users/abdul/Downloads/temp/data128_ise.dat", memory);
//    $readmemh("C:/Users/abdul/projects/Software/conversion_scripts/data128_1.dat", memory);
//	$readmemh("C:/Users/abdul/Dropbox/Softcore_codes/conversion_scripts/data128.dat", memory);
//	$readmemh("C:/Users/abdul/projects/Software/conversion_scripts/data128.dat", memory);
//	$readmemh("C:/Users/abdul/projects/Software/conversion_scripts/data128_rsa_2.dat", memory);
//  for (i=0; i<(2**(MEM_ADDR_BITS)); i = i + 1)
//    memory[i] <= {MEM_DATA_BITS{1'b0}};	
end
//*/

// MAIN MEMORY INSTANTIATION
// we = mem_req & mem_write; 
always @(posedge clk)
begin
    if(mem_write)
    begin
       mem_rdata 			<= mem_wdata;
       memory[mem_addr] 	<= mem_wdata;		
    end
    else
    begin
        mem_rdata 			<= memory[mem_addr];
    end    
end

endmodule
