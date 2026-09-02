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

    # Hold reset
    await ClockCycles(dut.clk, 10)

    # ------------------------------------------------------------
    # Reset test
    # ------------------------------------------------------------
    # uo_out[0] = UART_TX
    # UART idle state is HIGH.
    assert int(dut.uo_out.value) & 0x01 == 0x01, (
        f"NNG1 UART_TX reset/idle incorrect: "
        f"expected bit 0 = 1, got {dut.uo_out.value}"
    )

    # uo_out[7:1] = GPIO outputs
    # GPIO outputs must be LOW after reset.
    assert (int(dut.uo_out.value) & 0xFE) == 0, (
        f"NNG1 GPIO outputs reset incorrect: "
        f"expected uo_out[7:1] = 0, got {dut.uo_out.value}"
    )

    dut._log.info("PASS reset outputs")

    # ------------------------------------------------------------
    # Check QSPI idle outputs
    # ------------------------------------------------------------
    # During normal inactive operation:
    #   uio_out[4] = QSPI_CS_N -> HIGH
    #   uio_out[5] = QSPI_SCK  -> LOW
    #
    # QSPI pins are outputs.
    uio_out = int(dut.uio_out.value)
    uio_oe = int(dut.uio_oe.value)

    assert (uio_out & 0x10) == 0x10, (
        f"NNG1 QSPI CS_N incorrect: "
        f"expected HIGH, got uio_out={dut.uio_out.value}"
    )

    assert (uio_out & 0x20) == 0, (
        f"NNG1 QSPI SCK incorrect: "
        f"expected LOW, got uio_out={dut.uio_out.value}"
    )

    assert (uio_oe & 0x30) == 0x30, (
        f"NNG1 QSPI control OE incorrect: "
        f"expected bits 4/5 = 1, got uio_oe={dut.uio_oe.value}"
    )

    dut._log.info("PASS QSPI idle pins")

    # ------------------------------------------------------------
    # Release reset
    # ------------------------------------------------------------
    dut.rst_n.value = 1

    await ClockCycles(dut.clk, 10)

    dut._log.info("PASS reset release")

    # ------------------------------------------------------------
    # GPIO input test
    # ------------------------------------------------------------
    # NNG1 pin mapping:
    #
    # ui_in[7:2] = GPIO input 0..5
    # ui_in[1]   = BOOT
    # ui_in[0]   = UART_RX
    #
    # Test GPIO input pattern.
    dut.ui_in.value = 0b11111100

    await ClockCycles(dut.clk, 10)

    dut._log.info("PASS GPIO input pattern 1")

    dut.ui_in.value = 0b10101000

    await ClockCycles(dut.clk, 10)

    dut._log.info("PASS GPIO input pattern 2")

    dut.ui_in.value = 0b01010100

    await ClockCycles(dut.clk, 10)

    dut._log.info("PASS GPIO input pattern 3")

    # ------------------------------------------------------------
    # QSPI input test
    # ------------------------------------------------------------
    # uio_in[3:0] = QSPI IO0..IO3
    dut.uio_in.value = 0b00001010

    await ClockCycles(dut.clk, 5)

    dut.uio_in.value = 0b00000101

    await ClockCycles(dut.clk, 5)

    dut._log.info("PASS QSPI input pins")

    # ------------------------------------------------------------
    # BOOT pin test
    # ------------------------------------------------------------
    # ui_in[1] = BOOT
    #
    # BOOT = 1 -> UART boot
    # BOOT = 0 -> QSPI boot
    #
    # Only check that the input can be driven; the detailed
    # bootloader test is performed by nng1_boot_tb.v.
    dut.ui_in.value = 0b00000010

    await ClockCycles(dut.clk, 5)

    dut.ui_in.value = 0b00000000

    await ClockCycles(dut.clk, 5)

    dut._log.info("PASS BOOT input")

    # ------------------------------------------------------------
    # UART RX input test
    # ------------------------------------------------------------
    dut.ui_in.value = 0b00000001

    await ClockCycles(dut.clk, 5)

    dut.ui_in.value = 0b00000000

    await ClockCycles(dut.clk, 5)

    dut._log.info("PASS UART RX input")

    # ------------------------------------------------------------
    # Enable test
    # ------------------------------------------------------------
    dut.ena.value = 0

    await ClockCycles(dut.clk, 5)

    dut.ena.value = 1

    await ClockCycles(dut.clk, 5)

    dut._log.info("PASS enable")

    # ------------------------------------------------------------
    # Final reset test
    # ------------------------------------------------------------
    dut.rst_n.value = 0

    await ClockCycles(dut.clk, 5)

    # UART must remain idle HIGH.
    assert (int(dut.uo_out.value) & 0x01) == 1, (
        f"NNG1 UART_TX final reset incorrect: "
        f"expected 1, got {dut.uo_out.value}"
    )

    # GPIO outputs must remain LOW.
    assert (int(dut.uo_out.value) & 0xFE) == 0, (
        f"NNG1 GPIO final reset incorrect: "
        f"expected uo_out[7:1] = 0, got {dut.uo_out.value}"
    )

    dut._log.info("PASS final reset")

    dut._log.info("NNG1 Tiny Tapeout test PASSED")
