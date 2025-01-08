

module CU_DCDR(
   input br_eq, 
   input br_lt, 
   input br_ltu,
   input int_taken,
   input [6:0] opcode,   //-  ir[6:0]
   input func7,          //-  ir[30]
   input [2:0] func3,    //-  ir[14:12] 
   output logic [3:0] ALU_FUN,
   output logic [2:0] PC_SEL,
   output logic [1:0]srcA_SEL,
   output logic [2:0] srcB_SEL, 
   output logic [1:0] RF_SEL
);
   
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
        CSR    = 7'b1110011          // Added CSR opcode s
   } opcode_t;
   opcode_t OPCODE; //- define variable of new opcode type
    
   assign OPCODE = opcode_t'(opcode); //- Cast input enum 

   //- datatype for func3Symbols tied to values
   typedef enum logic [2:0] {
        //BRANCH labels
        BEQ = 3'b000,
        BNE = 3'b001,
        BLT = 3'b100,
        BGE = 3'b101,
        BLTU = 3'b110,
        BGEU = 3'b111
   } func3_t;    
   func3_t FUNC3; //- define variable of new opcode type
    
   assign FUNC3 = func3_t'(func3); //- Cast input enum 
       
   always_comb
   begin 
      //- schedule all values to avoid latch
      PC_SEL = 3'b000;  srcB_SEL = 3'b000;     RF_SEL = 2'b00; 
      srcA_SEL = 2'b00;   ALU_FUN  = 4'b0000;
		
		if (int_taken) 
		begin
		PC_SEL = 3'b100;
		end
		else 
		
		
      case(OPCODE)
         
         JALR: 
         begin
         PC_SEL = 3'b001;   // PC Select for JALR WHY
         //srcB_SEL = 3'b001; // I type immediate
         //srcA_SEL = 2'b00;  // rs1 
         RF_SEL = 2'b00;   // PC + 4
         end 
              
         AUIPC:
         begin
         ALU_FUN = 4'b0000;  // Add
         srcA_SEL = 2'b01;    // U - type instruction 
         srcB_SEL = 3'b011;   // PC + U-type immediate (this is the difference)  
         RF_SEL = 2'b11;     // Output of the ALU into the data into the register file
         PC_SEL = 3'b000;     // PC + 4 
         end
         
         BRANCH: 
         begin
         case(func3)
             BEQ:  if (br_eq == 1) PC_SEL = 3'b010;
             BNE:  if (br_eq == 0) PC_SEL = 3'b010;
             BLT:  if (br_lt == 1) PC_SEL = 3'b010; 
             BGE:  if (br_lt == 0) PC_SEL = 3'b010; 
             BLTU: if (br_ltu == 1) PC_SEL = 3'b010; 
             BGEU: if (br_ltu == 0) PC_SEL = 3'b010; 
             default:  PC_SEL = 3'b000;
          endcase
          end
         
         LUI:
         begin
            ALU_FUN = 4'b1001;  // lui-copy   
            srcA_SEL = 2'b01;    // U - type instruction  
            RF_SEL = 2'b11;     // Output of the ALU into the data into the register file
            PC_SEL = 3'b000;     // PC + 4 
         end
			
         JAL:                   // instr = JAL 
         begin                  // We don't use the ALU for J-type instructions? 
				RF_SEL = 2'b00; // PC + 4 
				PC_SEL = 3'b011; // PC_SEL = 3 for Jal instruction
		 end
			
         LOAD:                 // instr = LOAD 
         begin
            ALU_FUN = 4'b0000; 
            srcA_SEL = 2'b00;   // Loading in RS1 
            srcB_SEL = 3'b001;  // I-type instruction
            RF_SEL = 2'b10;    // Output of the ALU into the Data MUX
            PC_SEL = 3'b000;    // PC + 4
         end
			
         STORE:                // instr = STORE 
         begin
            ALU_FUN = 4'b0000; // UNSURE I think its 0000 since we need to add the offset 
            srcA_SEL = 2'b00;   // rs1
            srcB_SEL = 3'b010;  // S-Type Immediate value
            RF_SEL = 2'b11;     // Out of ALU into Data MUX
            PC_SEL = 3'b000;     // PC + 4 
         end
			
         OP_IMM:
         begin
              srcA_SEL = 2'b00;    // rs1 
              srcB_SEL = 3'b001;   // Not picking register, picking I-type 
              RF_SEL = 2'b11;     // Out of the ALU module
              PC_SEL = 3'b000; 
               
            case(FUNC3)
               3'b000: ALU_FUN = 4'b0000; // instr: ADD
               3'b001: ALU_FUN = 4'b0001;  // SLL
               3'b010: ALU_FUN = 4'b0010;  // SLT
               3'b011: ALU_FUN = 4'b0011;  // SLTU 
               3'b100: ALU_FUN = 4'b0100;  // XOR
               3'b101: 
                    if(func7 ==  1'b0) ALU_FUN = 4'b0101; // SRL
                    else ALU_FUN = 4'b1101; // SRA 
               3'b110: ALU_FUN = 4'b0110; // OR 
               3'b111: ALU_FUN = 4'b0111; //AND
               
            endcase // End of OP_RG3 case block
         end
               
                
         OP_RG3:
         begin
              srcA_SEL = 2'b00;    // rs1  
              srcB_SEL = 3'b000;   // rs2
              RF_SEL = 2'b11;     // Out of the ALU module
              PC_SEL = 3'b000;     
            case(FUNC3)
               3'b000: 
                    if(func7 == 1'b0) ALU_FUN = 4'b0000; // instr: ADD
                    else ALU_FUN = 4'b1000; // SUB
               3'b001: ALU_FUN = 4'b0001;  // SLL
               3'b010: ALU_FUN = 4'b0010;  // SLT
               3'b011: ALU_FUN = 4'b0011;  // SLTU
               3'b100: ALU_FUN = 4'b0100;  // XOR
               3'b101: 
                    if(func7 ==  1'b0) ALU_FUN = 4'b0101; // SRL
                    else ALU_FUN = 4'b1101; // SRA 
               3'b110: ALU_FUN = 4'b0110; // OR 
               3'b111: ALU_FUN = 4'b0111; //AND
               
            endcase // End of OP_RG3 case block
         end
         
         CSR:
         begin
            case(func3)
            3'b001:                  // CSRRW
            begin
                ALU_FUN = 4'b1001;   // LUI-COPY
                PC_SEL   = 3'b000;   // mtvec
                RF_SEL   = 2'b01;    // csr_RD
                srcA_SEL = 2'b00;    // rs1
            end     
                        
            3'b011:                  // CSRRC
            begin
                ALU_FUN = 4'b0111;   // AND
                srcA_SEL = 2'b10;    // ~rs1
                srcB_SEL = 3'b100;   // csr_RD
                RF_SEL   = 2'b01;    // csr_RD
            end
            
            3'b010:                  // CSRRS
            begin
                ALU_FUN = 4'b0110;   // OR
                srcA_SEL = 2'b00;    // ~rs1
                srcB_SEL = 3'b100;   // csr_RD
                RF_SEL   = 2'b01;    // csr_RD
            end
            
            3'b000:
            begin
            PC_SEL = 3'b101; 
            end
           endcase
         end
         
         default:
         begin
             PC_SEL = 3'b000; 
             srcB_SEL = 3'b000; 
             RF_SEL = 2'b00; 
             srcA_SEL = 2'b00; 
             ALU_FUN = 4'b0000;
         end
      endcase
   end
endmodule
