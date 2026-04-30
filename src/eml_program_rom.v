`default_nettype none

// Program ROM (RPN): 1 1 x eml 1 eml eml
module eml_program_rom (
    input  wire [4:0] addr,
    output reg  [2:0] instr
);
  always @(*) begin
    case (addr)
      5'd0: instr = 3'b001; // PUSH_1
      5'd1: instr = 3'b001; // PUSH_1
      5'd2: instr = 3'b010; // PUSH_X
      5'd3: instr = 3'b100; // EML
      5'd4: instr = 3'b001; // PUSH_1
      5'd5: instr = 3'b100; // EML
      5'd6: instr = 3'b100; // EML
      5'd7: instr = 3'b111; // END
      default: instr = 3'b111;
    endcase
  end
endmodule
