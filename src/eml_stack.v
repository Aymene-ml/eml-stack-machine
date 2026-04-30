`default_nettype none

module eml_stack #(
    parameter WIDTH = 8,
    parameter DEPTH = 4
) (
    input  wire             clk,
    input  wire             rst,
    input  wire             clear,
    input  wire             push,
    input  wire             pop2,
    input  wire [WIDTH-1:0] push_data,
    output wire [WIDTH-1:0] top,
    output wire [WIDTH-1:0] second,
    output wire [3:0]       count
);
  reg [WIDTH-1:0] mem [0:DEPTH-1];
  reg [3:0] sp;

  integer i;
  always @(posedge clk) begin
    if (rst || clear) begin
      sp <= 4'd0;
      for (i = 0; i < DEPTH; i = i + 1) begin
        mem[i] <= {WIDTH{1'b0}};
      end
    end else begin
      if (pop2 && (sp >= 2)) begin
        sp <= sp - 4'd2;
      end
      if (push && (sp < DEPTH)) begin
        mem[sp[2:0]] <= push_data;
        sp <= sp + 4'd1;
      end
    end
  end

  assign top = (sp != 0) ? mem[sp-1] : {WIDTH{1'b0}};
  assign second = (sp >= 2) ? mem[sp-2] : {WIDTH{1'b0}};
  assign count = sp;
endmodule
