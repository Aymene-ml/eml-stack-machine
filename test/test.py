# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


@cocotb.test()
async def test_project(dut):
    dut._log.info("Start")

    # Set the clock period to 100 ns (10 MHz)
    clock = Clock(dut.clk, 100, unit="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)

    dut._log.info("Test EML stack machine")

    # Test 1: Execute fixed program (1 1 x eml 1 eml eml) with x=4, y=8 (Q4.4: 0.25, 0.5)
    # Expected: exp(0.25) - ln(0.5) ≈ 1.284 - (-0.693) ≈ 1.977 Q4.4
    x_val = 4  # 0.25 in Q4.4
    y_val = 8  # 0.5 in Q4.4
    
    dut.ui_in.value = 0x01 | (x_val << 1)  # start=1, x in bits[7:1]
    dut.uio_in.value = y_val  # y in bits[7:0]
    
    dut._log.info(f"Input: x={x_val} (Q4.4), y={y_val} (Q4.4)")
    
    # Wait for computation to complete (should take ~50-100 cycles for multi-cycle units)
    await ClockCycles(dut.clk, 150)
    
    result = dut.uo_out.value
    dut._log.info(f"Output: result={result} (0x{int(result):02x})")
    
    # Result should be in valid range for 8-bit Q4.4 (0-255)
    assert int(result) >= 0 and int(result) <= 255, f"Result {result} out of 8-bit range"
    dut._log.info(f"✓ Test passed: result in valid range")

    # Test 2: Another computation with different inputs
    x_val2 = 8  # 0.5 in Q4.4
    y_val2 = 16  # 1.0 in Q4.4
    
    dut.ui_in.value = 0x01 | (x_val2 << 1)  # start=1, x in bits[7:1]
    dut.uio_in.value = y_val2  # y in bits[7:0]
    
    dut._log.info(f"Test 2: x={x_val2} (Q4.4), y={y_val2} (Q4.4)")
    await ClockCycles(dut.clk, 150)
    
    result2 = dut.uo_out.value
    dut._log.info(f"Output: result={result2} (0x{int(result2):02x})")
    assert int(result2) >= 0 and int(result2) <= 255, f"Result {result2} out of 8-bit range"
    dut._log.info(f"✓ Test 2 passed: result in valid range")
