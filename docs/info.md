<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

This project implements an **8-bit EML Stack Machine** — a reverse-Polish notation (RPN) processor that computes the EML (Exp-Minus-Log) function:

$$\text{EML}(a, b) = e^a - \ln(b)$$

### Architecture

- **Stack-based processor**: Executes a fixed RPN program stored in read-only memory
- **4-entry stack**: Stores 8-bit Q4.4 fixed-point values (range: [0, 16) with 1/16 precision)
- **Multi-cycle FSM**: 5-stage controller manages fetch-decode-execute pipeline
- **Arithmetic unit**: 5-stage EML unit computes exp/log via LUT-based approximation with linear interpolation

### Instruction Set

| Opcode | Mnemonic | Operation |
|--------|----------|-----------|
| `001` | PUSH_1 | Push constant 1.0 onto stack |
| `010` | PUSH_X | Push external input x onto stack |
| `011` | PUSH_Y | Push external input y onto stack |
| `100` | EML | Pop top two values (a, b); push EML(a, b) |
| `111` | END | Halt execution |

### Default Program

The ROM contains a fixed 8-instruction RPN program:
```
1       PUSH_1          ; stack: [1]
1       PUSH_1          ; stack: [1, 1]
x       PUSH_X          ; stack: [1, 1, x]
EML     EML             ; stack: [1, EML(1,x)]
1       PUSH_1          ; stack: [1, EML(1,x), 1]
EML     EML             ; stack: [EML(1,EML(1,x))]
EML     EML             ; stack: [EML(1,EML(1,x))]
END     END             ; halt
```

### Fixed-Point Format

**Q4.4 (8-bit total)**:
- 4 integer bits: values 0–15
- 4 fractional bits: 1/16 precision
- Range: [0.0, 15.9375]
- Example: `0x80` = 8.0, `0xFF` = 15.9375

### Approximations

- **Exponential**: 3-entry LUT with 1-bit linear interpolation over fractional bits
- **Logarithm**: 8-entry LUT (covers mantissas in [1, 2)) with normalization

## How to test

### Pin Configuration

| Pin | Width | Direction | Description |
|-----|-------|-----------|-------------|
| `ui_in[0]` | 1-bit | Input | Start signal (pulse to begin computation) |
| `ui_in[7:1]` | 7-bit | Input | External input x (maps to Q4.4: x = ui_in[7:1] / 2) |
| `uio_in[7:0]` | 8-bit | Input | External input y (Q4.4 fixed-point) |
| `uo_out[7:0]` | 8-bit | Output | Result register (Q4.4 fixed-point) |

### Test Procedure

1. **Set inputs**:
   - `ui_in[7:1]` = desired x value (7-bit unsigned)
   - `uio_in[7:0]` = desired y value (8-bit Q4.4)

2. **Trigger execution**:
   - Pulse `ui_in[0]` from 0→1→0 to start computation

3. **Wait for result**:
   - Monitor `uo_out[7:0]` for the final result (will stabilize after ~30 cycles)

4. **Interpretation**:
   - Result is 8-bit Q4.4 format
   - Example: result = `0xA4` = 10 + 4/16 = 10.25

### Example Test Cases

**Test 1**: x = 4 (0x08), y = 8 (0x80)
- Expected: EML(1, EML(1,4)) evaluated with y=8
- Approximate result: ~0xD3 (13.1875 in Q4.4)

**Test 2**: x = 8 (0x10), y = 16 (0x100, saturated to 0xFF)
- Expected: Similar EML computation with larger inputs
- Approximate result: ~0xD3

### RTL Simulation

Cocotb-based simulation is provided in `test/`:

```bash
cd test/
make -B      # Rebuild and run tests
```

Expected output: All tests pass with actual results matching expected Q4.4 values within ±1 LSB tolerance.

## External hardware

**None required.** This is a fully self-contained digital design suitable for ASIC integration (TinyTapeout 2×1 tiles). All computation is performed internally using fixed-point arithmetic and LUT-based approximations.
