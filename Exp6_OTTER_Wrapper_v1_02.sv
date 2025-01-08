`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:   Ratner Surf Designs
// Engineer:  James Ratner 
// 
// Create Date: 03/30/2021 02:46:31 PM
// Design Name: 
// Module Name: OTTER_Wrapper_Testall
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Otter Wrapper: interfaces RISC-V OTTER to basys3 board for 
//              Experiment 6. 
//
// Dependencies: 
// 
// Revision:
// Revision 1.00 - (03-30-2021): created
//          1.01 - (05-14-2021): changed clock divide by 2
//          1.02 - (05-19-2021): changed clock divide by 2 again
//            
//////////////////////////////////////////////////////////////////////////////////

 module OTTER_Wrapper(
   input clk, 
   input [4:0] buttons,
   input [15:0] switches,
   output logic [15:0] leds,
   output logic [7:0] segs,
   output logic [3:0] an    );
       
   //- INPUT PORT IDS ---------------------------------------------------------
   localparam SWITCHES_PORT_ADDR = 32'h11008000;  // 0x1100_8000
   localparam BUTTONS_PORT_ADDR  = 32'h11008004;  // 0x1100_8004
              
   //- OUTPUT PORT IDS --------------------------------------------------------
   localparam LEDS_PORT_ADDR     = 32'h1100C000;  // 0x1100_C000
   localparam COUNT_ADDR         = 32'h1100C00C;  // 0x1100_C00C
	
   //- Signals for connecting OTTER_MCU to OTTER_wrapper 
   logic s_interrupt;  
   logic s_reset;              
   logic s_clk;            // divided clock
   logic ss_clk;           // a more divided clock

   logic [31:0] IOBUS_out;
   logic [31:0] IOBUS_in;
   logic [31:0] IOBUS_addr;
   logic IOBUS_wr;
    
   //- register for dev board output devices ---------------------------------
   logic [7:0]  r_segs;   //  register for segments (cathodes)
   logic [15:0] r_leds;   //  register for LEDs
   logic [3:0]  r_an;     //  register for display enables (anodes)
   logic [13:0] r_count;  //  register for the count value
   
   logic debounced_button; // Output of debounce module
   logic one_shot_pulse;   // Output of one-shot module
   logic neg_pulse_out; 

   
  //- Assign one-shot pulse to interrupt
   assign s_interrupt = one_shot_pulse; // Interrupt triggered by one-shot pulse
   assign s_reset = buttons[3];         // Reset tied to button[3]

  //- Instantiate RISC-V OTTER MCU 
  OTTER_MCU  my_otter(
      .RST         (s_reset),
      .intr        (s_interrupt),
      .clk         (s_clk),
      .iobus_in    (IOBUS_in),
      .iobus_out   (IOBUS_out), 
      .iobus_addr  (IOBUS_addr), 
      .iobus_wr    (IOBUS_wr)   );
      
   
   //- Divide clk by 2 
   always @(posedge clk) 
   begin
      if (s_clk == 0)  s_clk <= 1;
      else  s_clk <= 0;
   end
   
   //- Debounce module instantiation
   DBounce #(.n(8)) my_debounce (
      .clk    (s_clk),          // Slow clock
      .sig_in (buttons[4]),      // Button input to debounce
      .DB_out (debounced_button) // Debounced output
      );
      
   one_shot_bdir #(.n(8)) one_shot_module (
      .clk    (s_clk),                // Slow Clock
      .sig_in (debounced_button),      // Input from the debounce
      .pos_pulse_out (one_shot_pulse), // Single pulse output for rising edge
      .neg_pulse_out ()            // Unused negative pulse output
      );
   
   //- Drive dev board output devices with registers 
   always_ff @ (posedge ss_clk)
   begin
      if (IOBUS_wr == 1)
      begin
         case(IOBUS_addr)
            LEDS_PORT_ADDR:   
               r_leds <= IOBUS_out[15:0];    
			   COUNT_ADDR:   
               r_count <= IOBUS_out[13:0];
          endcase
       end
    end
   
    //- MUX to route input devices to I/O Bus
	//-   IOBUS_addr is the select signal to the MUX
   always_comb
   begin
      IOBUS_in=32'b0;
      case(IOBUS_addr)
         SWITCHES_PORT_ADDR: 
		    IOBUS_in[15:0] = switches;
         BUTTONS_PORT_ADDR: 
		    IOBUS_in[4:0] =  buttons;
         default: IOBUS_in=32'b0;
      endcase
   end 
	
   //- assign registered outputs to actual outputs 
   assign leds = r_leds; 
endmodule

