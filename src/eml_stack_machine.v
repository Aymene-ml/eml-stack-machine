`default_nettype none

// -----------------------------------------------------------------------------
// eml_stack_machine
//
// Single-instruction stack processor for EML(a,b)=exp(a)-ln(b), executing
// an RPN program from ROM.
//
// Controller FSM:
//   IDLE -> FETCH  on start
//   FETCH -> DECODE
//   DECODE -> FETCH  for PUSH ops
//   DECODE -> EXECUTE for EML
//   DECODE -> DONE for END
//   EXECUTE -> FETCH when eml_unit ready
//   DONE -> IDLE when start returns low
// -----------------------------------------------------------------------------
module eml_stack_machine (
    input  wire        clk,
    input  wire        rst,
    input  wire        start,
    input  wire [7:0]  x,
    input  wire [7:0]  y,
    output reg  [7:0]  result,
    output reg         done
);
  localparam OPC_PUSH_1 = 3'b001;
  localparam OPC_PUSH_X = 3'b010;
  localparam OPC_PUSH_Y = 3'b011;
  localparam OPC_EML    = 3'b100;
  localparam OPC_END    = 3'b111;

  localparam ST_IDLE    = 3'd0;
  localparam ST_FETCH   = 3'd1;
  localparam ST_DECODE  = 3'd2;
  localparam ST_EXECUTE = 3'd3;
  localparam ST_DONE    = 3'd4;

  localparam PROG_LEN   = 5'd8;

  reg [2:0] state;
  reg [4:0] pc;
  reg [2:0] instr;

  reg        stack_push;
  reg        stack_pop2;
  reg        stack_clear;
  reg [7:0]  stack_push_data;

  wire [7:0]  stack_top;
  wire [7:0]  stack_second;
  wire [3:0]  stack_count;

  reg [7:0]  eml_a;
  reg [7:0]  eml_b;
  reg        eml_start;
  wire [7:0]  eml_out;
  wire        eml_ready;

  wire [2:0] instr_wire;

  eml_stack #(
      .WIDTH(8),
      .DEPTH(4)
  ) u_stack (
      .clk(clk),
      .rst(rst),
      .clear(stack_clear),
      .push(stack_push),
      .pop2(stack_pop2),
      .push_data(stack_push_data),
      .top(stack_top),
      .second(stack_second),
      .count(stack_count)
  );

  eml_program_rom u_rom (
      .addr(pc),
      .instr(instr_wire)
  );

  eml_unit u_eml (
      .clk(clk),
      .rst(rst),
      .start(eml_start),
      .a(eml_a),
      .b(eml_b),
      .out(eml_out),
      .ready(eml_ready)
  );

  always @(posedge clk) begin
    if (rst) begin
      state <= ST_IDLE;
      pc <= 5'd0;
      instr <= OPC_END;
      result <= 8'h00;
      done <= 1'b0;
      stack_push <= 1'b0;
      stack_pop2 <= 1'b0;
      stack_clear <= 1'b1;
      stack_push_data <= 8'h00;
      eml_a <= 8'h00;
      eml_b <= 8'h00;
      eml_start <= 1'b0;
    end else begin
      stack_push <= 1'b0;
      stack_pop2 <= 1'b0;
      stack_clear <= 1'b0;
      eml_start <= 1'b0;

      case (state)
        ST_IDLE: begin
          done <= 1'b0;
          if (start) begin
            pc <= 5'd0;
            stack_clear <= 1'b1;
            result <= 8'h00;
            state <= ST_FETCH;
          end
        end

        ST_FETCH: begin
          if (pc >= PROG_LEN) begin
            result <= stack_top;
            done <= 1'b1;
            state <= ST_DONE;
          end else begin
            instr <= instr_wire;
            state <= ST_DECODE;
          end
        end

        ST_DECODE: begin
          case (instr)
            OPC_PUSH_1: begin
              stack_push_data <= 8'h10; // Q4.4 value 1.0
              stack_push <= 1'b1;
              pc <= pc + 5'd1;
              state <= ST_FETCH;
            end

            OPC_PUSH_X: begin
              stack_push_data <= x;
              stack_push <= 1'b1;
              pc <= pc + 5'd1;
              state <= ST_FETCH;
            end

            OPC_PUSH_Y: begin
              stack_push_data <= y;
              stack_push <= 1'b1;
              pc <= pc + 5'd1;
              state <= ST_FETCH;
            end

            OPC_EML: begin
              if (stack_count >= 2) begin
                // Pop order is b then a, so top is b and second is a.
                eml_a <= stack_second;
                eml_b <= stack_top;
                stack_pop2 <= 1'b1;
                eml_start <= 1'b1;
                state <= ST_EXECUTE;
              end else begin
                result <= 8'h00;
                done <= 1'b1;
                state <= ST_DONE;
              end
            end

            OPC_END: begin
              result <= stack_top;
              done <= 1'b1;
              state <= ST_DONE;
            end

            default: begin
              result <= stack_top;
              done <= 1'b1;
              state <= ST_DONE;
            end
          endcase
        end

        ST_EXECUTE: begin
          if (eml_ready) begin
            stack_push_data <= eml_out;
            stack_push <= 1'b1;
            pc <= pc + 5'd1;
            state <= ST_FETCH;
          end
        end

        ST_DONE: begin
          done <= 1'b1;
          if (!start) begin
            state <= ST_IDLE;
          end
        end

        default: begin
          state <= ST_IDLE;
        end
      endcase
    end
  end
endmodule
