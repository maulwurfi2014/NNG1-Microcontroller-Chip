# SPDX-License-Identifier: MIT

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


@cocotb.test()
async def test_project(dut):
    dut._log.info("NNG1 Tiny Tapeout smoke test started")

    # NNG1 runs at 10 MHz -> 100 ns clock period
    clock = Clock(dut.clk, 100, unit="ns")
    cocotb.start_soon(clock.start())

    # ------------------------------------------------------------
    # Initial conditions
    # ------------------------------------------------------------
    dut.ena.value = 1

    # ui_in:
    #   bit 0 = UART_RX
    #   bit 1 = BOOT
    #   bit 7:2 = GPIO inputs
    #
    # BOOT = 0 -> QSPI boot
    dut.ui_in.value = 0

    # QSPI IO inputs
    dut.uio_in.value = 0

    # Reset
    dut.rst_n.value = 0

    await ClockCycles(dut.clk, 10)

    # ------------------------------------------------------------
    # Basic reset/output test
    # ------------------------------------------------------------
    # UART_TX is uo_out[0].
    # UART idle is HIGH.
    uo = int(dut.uo_out.value)

    assert (uo & 0x01) == 0x01, (
        f"NNG1 UART_TX should be HIGH in idle/reset, "
        f"got uo_out={dut.uo_out.value}"
    )

    # uo_out[7:1] = GPIO outputs.
    # GPIO outputs are reset to LOW.
    assert (uo & 0xFE) == 0, (
        f"NNG1 GPIO outputs should be LOW after reset, "
        f"got uo_out={dut.uo_out.value}"
    )

    dut._log.info("PASS reset outputs")

    # ------------------------------------------------------------
    # QSPI boot-mode pin test
    # ------------------------------------------------------------
    # BOOT=0 selects the hardware QSPI bootloader.
    #
    # During QSPI boot:
    #   uio_out[4] = QSPI_CS_N
    #
    # CS_N is LOW while the bootloader is accessing flash.
    uio = int(dut.uio_out.value)

    assert (uio & 0x10) == 0, (
        f"NNG1 QSPI CS_N should be LOW during QSPI boot, "
        f"got uio_out={dut.uio_out.value}"
    )

    # QSPI SCK starts LOW.
    assert (uio & 0x20) == 0, (
        f"NNG1 QSPI SCK should start LOW, "
        f"got uio_out={dut.uio_out.value}"
    )

    # CS_N and SCK are always driven by the wrapper.
    uio_oe = int(dut.uio_oe.value)

    assert (uio_oe & 0x30) == 0x30, (
        f"NNG1 QSPI CS_N/SCK output-enable incorrect, "
        f"got uio_oe={dut.uio_oe.value}"
    )

    dut._log.info("PASS QSPI boot pins")

    # ------------------------------------------------------------
    # GPIO input activity
    # ------------------------------------------------------------
    # GPIO inputs are:
    #   ui_in[7:2]
    #
    # They are accepted while the QSPI bootloader is active.
    dut.ui_in.value = 0b11111100
    await ClockCycles(dut.clk, 5)

    dut.ui_in.value = 0b10101000
    await ClockCycles(dut.clk, 5)

    dut.ui_in.value = 0b01010100
    await ClockCycles(dut.clk, 5)

    dut._log.info("PASS GPIO input activity")

    # ------------------------------------------------------------
    # QSPI input activity
    # ------------------------------------------------------------
    dut.uio_in.value = 0b00001111
    await ClockCycles(dut.clk, 5)

    dut.uio_in.value = 0b00000000
    await ClockCycles(dut.clk, 5)

    dut._log.info("PASS QSPI input activity")

    # ------------------------------------------------------------
    # BOOT pin test
    # ------------------------------------------------------------
    # While reset is asserted, switch to UART boot mode.
    #
    # BOOT=1 -> UART bootloader
    #
    # Keep UART_RX HIGH (idle) so that the UART input is valid.
    dut.ui_in.value = 0b00000011

    # Re-enter reset so the bootloader samples BOOT=1.
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)

    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 2)

    dut._log.info("PASS UART boot mode selection")

    # ------------------------------------------------------------
    # Final sanity check
    # ------------------------------------------------------------
    # Reset once more in QSPI mode.
    dut.ui_in.value = 0b00000000
    dut.uio_in.value = 0
    dut.rst_n.value = 0

    await ClockCycles(dut.clk, 5)

    uo = int(dut.uo_out.value)

    assert (uo & 0x01) == 0x01, (
        f"NNG1 final UART_TX idle state incorrect, "
        f"got uo_out={dut.uo_out.value}"
    )

    assert (uo & 0xFE) == 0, (
        f"NNG1 final GPIO reset state incorrect, "
        f"got uo_out={dut.uo_out.value}"
    )

    dut._log.info("PASS final reset")

    dut._log.info("NNG1 Tiny Tapeout smoke test PASSED")
