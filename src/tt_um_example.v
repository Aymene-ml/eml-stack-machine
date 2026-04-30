/*
 * Copyright (c) 2026
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// TinyTapeout wrapper (8-bit EML):
// - ui_in[7:1] = x (8-bit input)
// - ui_in[0] = start
// - uio_in[7:0] = y (8-bit input)
// - uo_out[7:0] = result (8-bit output)
// - uio_oe = 0 (uio used as inputs)
module tt_um_eml_stack_machine (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);
  wire [7:0] core_result;
  wire core_done;

  eml_stack_machine u_core (
      .clk(clk),
      .rst(~rst_n),
      .start(ui_in[0]),
      .x(ui_in),
      .y(uio_in),
      .result(core_result),
      .done(core_done)
  );

  assign uo_out  = core_result;
  assign uio_out = 8'h00;
  assign uio_oe  = 8'h00;

  wire _unused = &{ena, core_done, 1'b0};
endmodule
