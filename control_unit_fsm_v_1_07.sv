 `timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//  Company:  Ratner Surf Designs
// Engineer: James Ratner
// 
// Create Date: 01/07/2020 09:12:54 PM
// Design Name: 
// Module Name: top_level
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Control Unit Template/Starter File for RISC-V OTTER
//
//     //- instantiation template 
//     CU_FSM my_fsm(
//        .intr     (xxxx),
//        .clk      (xxxx),
//        .RST      (xxxx),
//        .opcode   (xxxx),   // ir[6:0]
//        .PC_WE    (xxxx),
//        .RF_WE    (xxxx),
//        .memWE2   (xxxx),
//        .memRDEN1 (xxxx),
//        .memRDEN2 (xxxx),
//        .reset    (xxxx)   );
//   
// Dependencies: 
// 
// Revision  History:
// Revision 1.00 - File Created - 02-01-2020 (from other people's files)
//          1.01 - (02-08-2020) switched states to enum type
//          1.02 - (02-25-2020) made PS assignment blocking
//                              made rst output asynchronous
//          1.03 - (04-24-2020) added "init" state to FSM
//                              changed rst to reset
//          1.04 - (04-29-2020) removed typos to allow synthesis
//          1.05 - (10-14-2020) fixed instantiation comment (thanks AF)
//          1.06 - (12-10-2020) cleared most outputs, added commentes
//          1.07 - (12-27-2023) changed signal names 
// 
//////////////////////////////////////////////////////////////////////////////////

module CU_FSM(    
    input clk,
    input RST,
    input intr,
    input [6:0] opcode,     // ir[6:0]
    input [2:0] func3,      //  ir[14:12] 
    output logic PC_WE,
    output logic RF_WE,
    output logic memWE2,
    output logic memRDEN1,
    output logic memRDEN2,
    output logic reset,
    output logic mret_exec,
    output logic int_taken,
    output logic csr_WE
       
  );
    
    typedef  enum logic [2:0] {
       st_INIT,
	   st_FET,
       st_EX,
       st_WB,
       st_INTERRUPT                 // Added interrupt state
    }  state_type; 
    state_type  NS,PS; 
      
    //- datatypes for RISC-V opcode types
    typedef enum logic [6:0] {
        LUI    = 7'b0110111,
        AUIPC  = 7'b0010111,
        JAL    = 7'b1101111,
        JALR   = 7'b1100111,
        BRANCH = 7'b1100011,
        LOAD   = 7'b0000011,
        STORE  = 7'b0100011,
        OP_IMM = 7'b0010011,
        OP_RG3 = 7'b0110011,
        CSR    = 7'b1110011
    } opcode_t;
    
	opcode_t OPCODE;    //- symbolic names for instruction opcodes
     
	assign OPCODE = opcode_t'(opcode); //- Cast input as enum 
	 

	//- state registers (PS)
	always @ (posedge clk)  
        if (RST == 1)
            PS <= st_INIT;
        else
            PS <= NS;

    always_comb
    begin              
        //- schedule all outputs to avoid latch
        PC_WE = 1'b0;    RF_WE = 1'b0;    reset = 1'b0;  
		memWE2 = 1'b0;     memRDEN1 = 1'b0;    memRDEN2 = 1'b0;
		mret_exec = 1'b0; int_taken = 1'b0; csr_WE = 1'b0;  
                   
        case (PS)

            st_INIT: //waiting state  
            begin
                reset = 1'b1;                    
                NS = st_FET; 
            end

            st_FET: //waiting state  
            begin
                memRDEN1 = 1'b1;                    
                NS = st_EX; 
            end
              
            st_EX: //decode + execute
            begin
                PC_WE = 1'b1;
				case (OPCODE)
				
				    AUIPC:
				      begin
                          RF_WE = 1'b1; 
                          NS = st_FET;
				      end
				      
				    LOAD: 
                       begin
                          RF_WE = 1'b0;    // When loading, we need to write to a register 
                          memRDEN2 = 1'b1; // Need to be able to read from memory 
                          PC_WE = 1'b0;    // Not writing to PC
                          NS = st_WB;      // 
                          
                       end
                    
					STORE: 
                       begin
                          RF_WE = 1'b0;   // Storing into memory, not writing to register
                          memWE2 = 1'b1;  // Need to write to memory
                          memRDEN2 = 1'b0; // Not reading from memory
                          NS = st_FET;  
                       end
                    
					BRANCH: 
                       begin
                          NS = st_FET;  
                       end
					
					LUI: 
					   begin
                          RF_WE = 1'b1;			// Changed to on for Load Upper Immeditate
                          PC_WE = 1'b1;         // Writing to PC                  
					      NS = st_FET;
					   end
					  
					OP_IMM:  // addi 
					   begin 
					      RF_WE = 1'b1;	     // Writing to Register
					      memWE2 = 1'b0;     // Not writing to memory
					      memRDEN2 = 1'b0;    // Not accessing memory values 
					      NS = st_FET;        
					   end
					   					  
					OP_RG3:  // add 
					   begin 
					      RF_WE = 1'b1;	     // Writing to Register
					      memWE2 = 1'b0;     // Not writing to memory
					      memRDEN2 = 1'b0;    // Not accessing memory values 
					      NS = st_FET;        
					   end
					   
	                JAL: 
					   begin
					      PC_WE = 1'b1;    // Need to write value to PC
					      RF_WE = 1'b1;    // Need to write PC+4 to destination register from JAL instruction
					      NS = st_FET;
					   end
					   
					 JALR: 
					   begin
					      PC_WE = 1'b1;
					      RF_WE = 1'b1;
					      NS = st_FET;
					   end
					  
					CSR:
					   begin
                        case (func3)
                           3'b001:
                           begin                        // CSRRW
                            csr_WE = 1'b1;
                            RF_WE  = 1'b1;   
                           end   
                                     
                           3'b011:
                           begin                        // CSRRC
                            csr_WE = 1'b1;               
                            RF_WE  = 1'b1; 
                           end     
                                     
                           3'b010:   
                           begin                     // CSRRS
                            csr_WE = 1'b1;
                            RF_WE  = 1'b1;  
                           end 
                                        
                           3'b000:
                           begin                        // MRET
                            PC_WE     = 1'b1;
                            mret_exec = 1'b1;
                           end
                           default: RF_WE = 1'b0;
                          endcase
                        end
                    default:  
					   begin 
					      NS = st_FET;
					   end
                endcase
                
                if (OPCODE == LOAD) NS = st_WB;
                else if (intr)      NS = st_INTERRUPT;
                else                NS = st_FET;
                
            end
               
            st_WB:
            begin
             RF_WE = 1'b1; // Write back needs to write back to register 
             PC_WE = 1'b1; 
             memRDEN2 = 1'b0;

               if (intr == 0)
               begin
                   NS = st_FET;
               end
               else NS = st_INTERRUPT;
               
               
            end
            
            st_INTERRUPT:   // Added Interrupt State 
            begin
            int_taken = 1'b1;
            PC_WE = 1'b1; 
            NS = st_FET;
            end
 
            default: NS = st_FET;
           
        endcase //- case statement for FSM states
    end
endmodule
