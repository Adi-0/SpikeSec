# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles

async def reset_dut(dut):
    """rst 5 cycles."""
    dut.rst_n.value = 0
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 1)

async def run_challenge(dut, challenge, trim=0):
    """challenge and return 8-bit response."""
    dut.ui_in.value = challenge
    dut.uio_in.value = (trim << 1) & 0x1E  # bits [4:1]
    await ClockCycles(dut.clk, 1)

    # assert start (uio_in[0] = 1)
    dut.uio_in.value = ((trim << 1) & 0x1E) | 0x01
    await ClockCycles(dut.clk, 1)

    for _ in range(50):
        await ClockCycles(dut.clk, 1)
        if dut.uio_out.value & 0x01:
            break
    else:
        assert False, "timed out waiting for done"

    response = int(dut.uo_out.value)

    dut.uio_in.value = (trim << 1) & 0x1E
    await ClockCycles(dut.clk, 2)

    return response


@cocotb.test()
async def test_basic_operation(dut):
    """Verify PUF works"""
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    response = await run_challenge(dut, challenge=0xA5, trim=0)
    dut._log.info(f"challenge=0xA5, trim=0 -> response=0x{response:02X}")
    assert response != 0, "should be non-zero for non-zero challenge"


@cocotb.test()
async def test_reproducibility(dut):
    """Same challenge and trim (must produce same response)"""
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    r1 = await run_challenge(dut, challenge=0x5A, trim=3)
    r2 = await run_challenge(dut, challenge=0x5A, trim=3)

    dut._log.info(f"run 1: 0x{r1:02X}, run 2: 0x{r2:02X}")
    assert r1 == r2, f"reproducibility failed: {r1:#x} != {r2:#x}"


@cocotb.test()
async def test_uniqueness(dut):
    """Different challenges should produce different resp"""
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    challenges = [0xFF, 0x0F, 0xF0, 0xAA, 0x55, 0x01, 0x80, 0x42]
    responses = []
    for c in challenges:
        r = await run_challenge(dut, challenge=c, trim=0)
        responses.append(r)
        dut._log.info(f"challenge=0x{c:02X} -> response=0x{r:02X}")

    unique = len(set(responses))
    dut._log.info(f"unique responses: {unique}/{len(challenges)}")
    assert unique >= 4, f"uniqueness too low: only {unique} distinct responses"


@cocotb.test()
async def test_process_sensitivity(dut):
    """Different trim (process variation) should differ"""
    clock = Clock(dut.clk, 10, units="us")
    cocotb.start_soon(clock.start())
    await reset_dut(dut)

    challenge = 0xA5
    responses = []
    for trim in [0, 4, 8, 15]:
        r = await run_challenge(dut, challenge=challenge, trim=trim)
        responses.append(r)
        dut._log.info(f"trim={trim:2d} -> response=0x{r:02X}")

    unique = len(set(responses))
    dut._log.info(f"unique responses across trims: {unique}/4")
    assert unique >= 2, f"process sensitivity too low: only {unique} distinct responses"
