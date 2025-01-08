`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
//  
// Create Date: 11/01/2024 06:18:23 PM
// Design Name: 
// Module Name: exp5_top_module
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

  module OTTER_MCU(
    input RST,
    input intr,
    input [31:0] iobus_in,
    input clk,
    output iobus_wr,
    output [31:0] iobus_out,
    output [31:0] iobus_addr
    );
    
    wire reset;
    wire [31:0] mux_output;
    wire [31:0] pc;
    wire [31:0] ir;
    wire [31:0] j_type;
    wire [31:0] b_type;
    wire [31:0] i_type;
    wire [31:0] jalr_addr;
    wire [31:0] branch_addr;
    wire [31:0] jal_addr;
    wire PC_WE;
    wire [2:0]  PC_SEL;
    wire [31:0] u_type_imm;
    wire [31:0] s_type_imm;
   
    wire [3:0] ALU_FUN;
    wire [1:0] srcA_SEL;
    wire [2:0] srcB_SEL;
    wire [1:0] RF_SEL;
    wire RF_WE;
    wire memWE2;
    wire memRDEN1;
    wire memRDEN2;
    
    wire [31:0] rs1;
    wire [31:0] rs2;
    wire [31:0] alu_result;
    wire [31:0] ALU_srcA;
    wire [31:0] ALU_srcB;
    wire [31:0] w_data;
    wire [31:0] CSR_REG;   
    wire [31:0] DOUT2;
    
    wire br_eq;
    wire br_lt;
    wire br_ltu;
    
    wire mret_exec;
    wire int_taken;
    wire csr_WE;
    wire [31:0] mepc;
    wire [31:0] mtvec;
    wire csr_mstatus;
    // Assign Statements for BRANCH COND GEN
    assign br_eq = (rs1 == rs2);
    assign br_lt = ($signed(rs1) < $signed(rs2));
    assign br_ltu = (rs1 < rs2);
   
    
    // Assign Statements for IMMED_GEN
    assign j_type = {{12{ir[31]}}, ir[19:12], ir[20], ir[30:21], 1'b0};
    assign s_type_imm = {{21{ir[31]}}, ir[30:25], ir[11:7]};
    assign u_type_imm =  {ir[31:12], 12'd0}; 
    assign b_type = {{20{ir[31]}}, ir[7], ir[30:25], ir[11:8], 1'b0};
    assign i_type = {{21{ir[31]}}, ir[30:25], ir[24:20]};
    
    // Assign Statement for BRANCH ADDR GEN
    assign jalr_addr = rs1 + i_type; 
    assign jal_addr  = pc + j_type;
    assign branch_addr = pc + b_type;  
    
 
mux_8t1_nb  #(.n(32)) my_8t1_mux  (
   .SEL   (PC_SEL), 
   .D0    (pc+4), 
   .D1    (jalr_addr), 
   .D2    (branch_addr), 
   .D3    (jal_addr),
   .D4    (mtvec),
   .D5    (mepc),
   .D6    (32'b0),
   .D7    (32'b0),
   .D_OUT (mux_output) );  

  // Register Instantiation (PC)
reg_nb #(.n(32)) MY_REG (
  .data_in  (mux_output), 
  .ld       (PC_WE), 
  .clk      (clk), 
  .clr      (reset), 
  .data_out (pc) );  

 // Memory Instantiation
Memory OTTER_MEMORY (
    .MEM_CLK   (clk),
    .MEM_RDEN1 (memRDEN1), 
    .MEM_RDEN2 (memRDEN2), 
    .MEM_WE2   (memWE2),
    .MEM_ADDR1 (pc[15:2]),
    .MEM_ADDR2 (alu_result),
    .MEM_DIN2  (rs2),  
    .MEM_SIZE  (ir[13:12]),
    .MEM_SIGN  (ir[14]),
    .IO_IN     (iobus_in),
    .IO_WR     (iobus_wr),
    .MEM_DOUT1 (ir),
    .MEM_DOUT2 (DOUT2)  );
     
     assign fsm_intr = intr & csr_mstatus;
CU_FSM my_fsm(
    .intr     (fsm_intr),
    .clk      (clk),
    .RST      (RST),
    .opcode   (ir[6:0]),   //ir[6:0]
    .PC_WE    (PC_WE),
    .RF_WE    (RF_WE),
    .memWE2   (memWE2),
    .memRDEN1 (memRDEN1),
    .memRDEN2 (memRDEN2),
    .reset    (reset),
    .csr_WE   (csr_WE),
    .func3     (ir[14:12]),
    .int_taken (int_taken),
    .mret_exec   (mret_exec));

CU_DCDR my_cu_dcdr(
   .br_eq     (br_eq), 
   .br_lt     (br_lt), 
   .br_ltu    (br_ltu),
   .opcode    (ir[6:0]),    
   .func7     (ir[30]),    
   .func3     (ir[14:12]),    
   .ALU_FUN   (ALU_FUN),
   .PC_SEL    (PC_SEL),
   .srcA_SEL  (srcA_SEL),
   .srcB_SEL  (srcB_SEL), 
   .RF_SEL    (RF_SEL),
   .int_taken (int_taken)   );
   
   
RegFile my_regfile (
    .w_data (w_data),
    .clk    (clk),  
    .en     (RF_WE),
    .adr1   (ir[19:15]),
    .adr2   (ir[24:20]),
    .w_adr  (ir[11:7]),
    .rs1    (rs1), 
    .rs2    (rs2)  );
 
 // 4-1 MUX for Reg File 
mux_4t1_nb #(.n(32)) regfile_w_data_mux (
    .SEL   (RF_SEL),      
    .D0    (pc+4),         
    .D1    (CSR_REG),           
    .D2    (DOUT2),            
    .D3    (alu_result),       
    .D_OUT (w_data)        
);
 


ALU_top_module uut (
    .op_1(ALU_srcA),          // Connect operand1 to ALU input op_1
    .op_2(ALU_srcB),           // Connect operand2 to ALU input op_2
    .alu_fun(ALU_FUN),        // Connect alu_function to ALU input alu_fun
    .result(alu_result)       // Connect ALU result to output alu_result
);
    
    
// ALU multiplexor for srcA
mux_4t1_nb #(.n(32)) ALU_srcA_mux (
    .SEL   (srcA_SEL),           // 1-bit selector for ALU_srcA
    .D0    (rs1),                // Option 0: Register value rs1
    .D1    (u_type_imm),   // Option 1: Program counter
    .D2    (~rs1),
    .D3    (32'b0),
    .D_OUT (ALU_srcA)            // Output: ALU operand A
    
);


  mux_8t1_nb  #(.n(32)) my_8t1_ALU_MUX  (
         .SEL   (srcB_SEL),     // 2-bit selector
         .D0    (rs2),
         .D1    (i_type),
         .D2    (s_type_imm),
         .D3    (pc),
         .D4    (CSR_REG),
         .D5    (32'b0),
         .D6    (32'b0),
         .D7    (32'b0),
         .D_OUT (ALU_srcB) );  
      
CSR  my_csr (
    .CLK        (clk),
    .RST        (RST),
    .MRET_EXEC  (mret_exec),
    .INT_TAKEN  (int_taken),
    .ADDR       (ir[31:20]),
    .PC         (pc+4),
    .WD         (alu_result),
    .WR_EN      (csr_WE),
    .RD         (CSR_REG),
    .CSR_MEPC   (mepc),
    .CSR_MTVEC  (mtvec),
    .CSR_MSTATUS_MIE (csr_mstatus)    );
     
     
 assign iobus_out = rs2;
 assign iobus_addr = alu_result; 
 
 
endmodule


