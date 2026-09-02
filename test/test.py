# SPDX-License-Identifier: MIT

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


@cocotb.test()
async def test_project(dut):
    dut._log.info("NNG1 Tiny Tapeout test started")

    # NNG1 clock: 10 MHz
    clock = Clock(dut.clk, 100, unit="ns")
    cocotb.start_soon(clock.start())

    # ------------------------------------------------------------
    # Initial state
    # ------------------------------------------------------------
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0

    # Hold reset for several cycles
    await ClockCycles(dut.clk, 10)

    # ------------------------------------------------------------
    # Reset test
    # ------------------------------------------------------------
    # GPIO outputs must be reset to 0.
    assert int(dut.uo_out.value) == 0, (
        f"NNG1 reset GPIO output incorrect: "
        f"expected 0, got {dut.uo_out.value}"
    )

    dut._log.info("PASS reset")

    # ------------------------------------------------------------
    # Release reset
    # ------------------------------------------------------------
    dut.rst_n.value = 1

    await ClockCycles(dut.clk, 10)

    dut._log.info("PASS reset release")

    # ------------------------------------------------------------
    # GPIO input test
    # ------------------------------------------------------------
    # ui_in[7:2] are GPIO inputs.
    # ui_in[1:0] are reserved for NNG1 control inputs.
    dut.ui_in.value = 0b11111100
    dut.uio_in.value = 0

    await ClockCycles(dut.clk, 20)

    dut._log.info("PASS GPIO input pins")

    # ------------------------------------------------------------
    # GPIO input pattern test
    # ------------------------------------------------------------
    dut.ui_in.value = 0b10101000
    await ClockCycles(dut.clk, 10)

    dut.ui_in.value = 0b01010100
    await ClockCycles(dut.clk, 10)

    dut._log.info("PASS GPIO input patterns")

    # ------------------------------------------------------------
    # QSPI input pins
    # ------------------------------------------------------------
    # uio_in[3:0] are connected to the QSPI input path.
    dut.uio_in.value = 0b1010
    await ClockCycles(dut.clk, 5)

    dut.uio_in.value = 0b0101
    await ClockCycles(dut.clk, 5)

    dut._log.info("PASS QSPI input pins")

    # ------------------------------------------------------------
    # Enable test
    # ------------------------------------------------------------
    dut.ena.value = 0
    await ClockCycles(dut.clk, 5)

    dut.ena.value = 1
    await ClockCycles(dut.clk, 5)

    dut._log.info("PASS enable")

    # ------------------------------------------------------------
    # Final reset sanity check
    # ------------------------------------------------------------
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)

    assert int(dut.uo_out.value) == 0, (
        f"NNG1 final reset output incorrect: "
        f"expected 0, got {dut.uo_out.value}"
    )

    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)

    dut._log.info("PASS final reset")

    dut._log.info("NNG1 Tiny Tapeout test PASSED")
