# Notna Nano G1 (NNG1)

## Overview

The **Notna Nano G1 (NNG1)** is a compact experimental RISC-V microcontroller designed as an open-source ASIC project for the Tiny Tapeout / IHP SG13G2 platform.

NNG1 combines a small 32-bit RISC-V CPU with on-chip SRAM, a boot ROM, a UART bootloader, GPIO, communication peripherals, timers, PWM, watchdog functionality, interrupt control, and QSPI flash support.

The main goal of NNG1 is to create a small, programmable microcontroller that can eventually be manufactured as a real ASIC.

## CPU

NNG1 contains a custom RTL implementation of a 32-bit RISC-V-style CPU.

The CPU currently supports a large subset of the RV32I instruction set, including:

* Integer arithmetic
* Immediate operations
* Logical operations
* Shifts
* Comparisons
* Conditional branches
* Jumps
* Loads
* Stores
* Memory-mapped I/O

The CPU does not currently implement the RISC-V privileged architecture, floating-point extensions, compressed instructions, multiply/divide extensions, or a complete interrupt/trap architecture.

## Memory

NNG1 uses the following memory regions:

```text
0x00000000  Boot ROM
0x10000000  8 KiB SRAM
0x20000000  GPIO
0x20001000  UART
0x20002000  SPI
0x20003000  I2C
0x20004000  PWM
0x20005000  TIMER
0x20006000  WATCHDOG
0x20007000  QSPI
0x20008000  IRQ Controller
```

The current RTL includes an 8 KiB SRAM implementation and an IHP SG13G2 SRAM integration hook for the eventual ASIC implementation.

## Boot Process

NNG1 contains an integrated ROM bootloader.

There are two intended boot modes.

### Normal boot

When the BOOT pin is low, NNG1 starts from the boot ROM and can boot firmware from an external QSPI flash device.

```text
Reset
  |
  v
Boot ROM
  |
  v
QSPI Flash
  |
  v
Firmware
  |
  v
SRAM / CPU
```

### UART boot

When the BOOT pin is high, NNG1 enters the UART bootloader.

A host computer can send a firmware image over UART. The bootloader receives the image, verifies it, places it into SRAM, and starts execution.

The UART boot path is intended for development and programming without requiring a dedicated hardware debugger.

## UART Bootloader Image

The UART bootloader uses an image containing:

```text
NNG1 magic
Firmware length
Firmware data
CRC32
```

The firmware is loaded into SRAM and execution starts from:

```text
0x10000000
```

The current testbench successfully verifies the UART bootloader image-loading process.

## Pinout

UART and QSPI use dedicated pins and are not multiplexed with I2C or SPI.

### Dedicated UART pins

```text
ui_in[0] = UART_RX
uo_out[0] = UART_TX
```

### Boot pin

```text
ui_in[1] = BOOT
```

Boot selection:

```text
BOOT = 0   Normal / QSPI boot
BOOT = 1   UART bootloader
```

### Dedicated QSPI pins

```text
uio[0] = QSPI_IO0
uio[1] = QSPI_IO1
uio[2] = QSPI_IO2
uio[3] = QSPI_IO3
uio[4] = QSPI_CS_N
uio[5] = QSPI_SCK
```

The remaining GPIO-capable pins are used for general-purpose I/O.

## Peripherals

NNG1 currently includes:

### GPIO

General-purpose digital input/output with output-enable control.

### UART

UART communication and UART bootloader support.

### SPI

Synchronous SPI master peripheral.

### I2C

I2C master peripheral.

### PWM

Multiple PWM channels with configurable duty cycle and period.

### Timers

Hardware timers with configurable compare values and enable control.

### Watchdog

Configurable watchdog timer with enable and kick functionality.

### Interrupt Controller

Basic interrupt enable and pending registers.

### QSPI

QSPI flash interface for external non-volatile memory and boot support.

## Clock and Reset

NNG1 contains a reset synchronizer and clock-control logic in RTL.

The current clock implementation is technology-independent RTL. The final ASIC implementation will use the appropriate IHP SG13G2 clock and standard-cell infrastructure.

## Programming

During development, firmware can be loaded through the integrated UART bootloader.

A host computer can communicate with NNG1 using a USB-to-UART interface.

The intended programming flow is:

```text
PC
 |
 | USB
 v
USB-UART adapter
 |
 | UART
 v
NNG1 UART_RX
```

with the dedicated `BOOT` pin asserted during reset to enter the bootloader.

External QSPI flash can be used for normal standalone boot.

## Verification

The RTL has been tested using Icarus Verilog.

The full system test verifies the CPU-to-bus-to-peripheral path for:

* GPIO
* UART
* SPI
* I2C
* PWM
* TIMER
* WATCHDOG
* IRQ controller
* QSPI

The dedicated-pin test also verifies the dedicated UART TX and BOOT pins.

The UART bootloader test verifies that a firmware image can be received and loaded successfully.

Current successful tests include:

```text
NNG1 FULL CPU -> BUS -> PERIPHERAL TEST PASSED
PASS UART bootloader image load
NNG1 UART BOOT TEST PASSED
```

## How to Test

Install Icarus Verilog and run:

```bash
cd ~/Downloads/nng1
make clean
make test
```

The simulation executable is:

```text
nng1
```

The testbench generates VCD waveform files that can be inspected with a waveform viewer such as GTKWave.

## External Hardware

A final packaged NNG1 ASIC will require appropriate external power, clock/reset handling, and an external QSPI flash device when QSPI boot is used.

During development, a USB-to-UART adapter can be used to program the chip through the UART bootloader.

## ASIC Status

NNG1 is an experimental open-source RTL design intended for ASIC fabrication.

The following steps are still required before final silicon fabrication:

* Technology-specific synthesis
* SRAM macro integration
* Floorplanning
* Placement and routing
* Static timing analysis
* Power analysis
* DRC
* LVS
* Gate-level verification
* Final GDS generation
* Foundry / shuttle submission

The current RTL simulation does not by itself guarantee successful silicon operation.

## Project Goal

The long-term goal of NNG1 is to turn the design into a real, small, open-source RISC-V microcontroller fabricated using an open semiconductor process.

The project is intended for experimentation, education, and open hardware development.
