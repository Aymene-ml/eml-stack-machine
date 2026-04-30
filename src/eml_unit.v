`default_nettype none

// Multi-cycle EML unit:
// START -> COMPUTE_EXP -> COMPUTE_LOG -> SUB -> DONE
module eml_unit (
    input  wire        clk,
    input  wire        rst,
    input  wire        start,
    input  wire [7:0]  a,
    input  wire [7:0]  b,
    output reg  [7:0]  out,
    output reg         ready
);
  localparam EU_IDLE = 3'd0;
  localparam EU_EXP  = 3'd1;
  localparam EU_LOG  = 3'd2;
  localparam EU_SUB  = 3'd3;
  localparam EU_DONE = 3'd4;

  localparam signed [8:0] LN2_Q4_4 = 9'sd45;

  reg [2:0] state;

  reg [7:0]  a_r;
  reg [7:0]  b_r;

  reg signed [8:0]  exp_val;
  reg signed [8:0]  ln_val;

  reg [3:0] exp_frac;
  reg signed [8:0]  exp_base;
  reg signed [9:0]  exp_diff;
  reg signed [12:0] interp_acc;
  reg [2:0] exp_phase;

  reg [2:0] msb_pos;
  reg signed [4:0] e2;
  reg [7:0]  mant;
  reg [2:0] mant_idx;
  reg signed [8:0] ln_mant;

  wire [2:0] msb_b;
  wire [7:0]  norm_b;
  wire signed [8:0] e2_term;

  assign msb_b = msb_index(b_r);
  assign norm_b = norm_q4_4(b_r);
  assign e2_term = $signed({5'd0, msb_b}) - 8'sd4;

  function [2:0] msb_index;
    input [7:0] v;
    begin
      casez (v)
        8'b1???????: msb_index = 3'd7;
        8'b01??????: msb_index = 3'd6;
        8'b001?????: msb_index = 3'd5;
        8'b0001????: msb_index = 3'd4;
        8'b00001???: msb_index = 3'd3;
        8'b000001??: msb_index = 3'd2;
        8'b0000001?: msb_index = 3'd1;
        default:    msb_index = 3'd0;
      endcase
    end
  endfunction

  function [7:0] norm_q4_4;
    input [7:0] v;
    reg [2:0] p;
    begin
      p = msb_index(v);
      if (p >= 3'd4) begin
        norm_q4_4 = v >> (p - 3'd4);
      end else begin
        norm_q4_4 = v << (3'd4 - p);
      end
    end
  endfunction

  function [8:0] exp_lut;
    input [2:0] idx;
    begin
      case (idx)
        3'd0: exp_lut = 9'd16;  // e^0 = 1.0 in Q4.4
        3'd1: exp_lut = 9'd43;  // e^1 = 2.7 in Q4.4
        3'd2: exp_lut = 9'd117; // e^2 saturated
        default: exp_lut = 9'd127;
      endcase
    end
  endfunction

  function signed [8:0] ln_mant_lut;
    input [2:0] idx;
    begin
      case (idx)
        3'd0: ln_mant_lut = 9'sd0;   // ln(1.0)
        3'd1: ln_mant_lut = 9'sd2;   // ln(1.125)
        3'd2: ln_mant_lut = 9'sd4;   // ln(1.25)
        3'd3: ln_mant_lut = 9'sd6;   // ln(1.375)
        3'd4: ln_mant_lut = 9'sd8;   // ln(1.5)
        3'd5: ln_mant_lut = 9'sd9;   // ln(1.625)
        3'd6: ln_mant_lut = 9'sd11;  // ln(1.75)
        3'd7: ln_mant_lut = 9'sd12;  // ln(1.875)
      endcase
    end
  endfunction

  always @(posedge clk) begin
    if (rst) begin
      state <= EU_IDLE;
      out <= 8'h00;
      ready <= 1'b0;
      a_r <= 8'h00;
      b_r <= 8'h01;
      exp_val <= 9'sd0;
      ln_val <= 9'sd0;
      exp_frac <= 4'd0;
      exp_base <= 9'sd0;
      exp_diff <= 10'sd0;
      interp_acc <= 13'sd0;
      exp_phase <= 3'd0;
      msb_pos <= 3'd0;
      e2 <= 5'sd0;
      mant <= 8'd0;
      mant_idx <= 3'd0;
      ln_mant <= 9'sd0;
    end else begin
      ready <= 1'b0;

      case (state)
        EU_IDLE: begin
          if (start) begin
            a_r <= a;
            b_r <= (b == 8'd0) ? 8'd1 : b;
            exp_phase <= 3'd0;
            state <= EU_EXP;
          end
        end

        EU_EXP: begin
          if (a_r[7]) begin
            exp_val <= 9'sd16; // clamp for negative input (1.0 in Q4.4)
            state <= EU_LOG;
          end else if (a_r[6:4] >= 3'd2) begin
            exp_val <= 9'sd127; // saturated
            state <= EU_LOG;
          end else begin
            // Simple fixed-point interpolation (3 phases).
            if (exp_phase == 3'd0) begin
              exp_base <= $signed(exp_lut(a_r[6:4]));
              exp_diff <= $signed({1'b0, exp_lut(a_r[6:4] + 3'd1)}) -
                          $signed({1'b0, exp_lut(a_r[6:4])});
              interp_acc <= 13'sd0;
              exp_phase <= 3'd1;
            end else if (exp_phase == 3'd1) begin
              interp_acc <= $signed({{{2{exp_diff[9]}}, exp_diff}}) + (a_r[0] ? $signed({{{3{exp_diff[9]}}, exp_diff}}) : 13'sd0);
              exp_phase <= 3'd2;
            end else begin
              exp_val <= exp_base + $signed(interp_acc[12:4]);
              state <= EU_LOG;
            end
          end
        end

        EU_LOG: begin
          msb_pos <= msb_b;
          e2 <= e2_term[4:0];
          mant <= norm_b;
          mant_idx <= norm_b[6:4];
          ln_mant <= ln_mant_lut(norm_b[6:4]);
          ln_val <= ln_mant_lut(norm_b[6:4]) +
                    (e2_term * LN2_Q4_4);
          state <= EU_SUB;
        end

        EU_SUB: begin
          out <= exp_val[7:0] - ln_val[7:0];
          state <= EU_DONE;
        end

        EU_DONE: begin
          ready <= 1'b1;
          state <= EU_IDLE;
        end

        default: begin
          state <= EU_IDLE;
        end
      endcase
    end
  end
endmodule
