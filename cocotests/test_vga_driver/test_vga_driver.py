import random
import cocotb
from cocotb.clock     import Clock
from cocotb.triggers  import RisingEdge, FallingEdge
# import axi

ADDR_BITS = 32
DATA_BITS = 32

async def start_clocks(dut,
                       axi_period_ns=10,     # 100 MHz
                       vga_period_ns=40):    # 25 MHz (typical 640×480 pixel clk)
    cocotb.start_soon(Clock(dut.axi_clk, axi_period_ns, units="ns").start())
    cocotb.start_soon(Clock(dut.vga_clk, vga_period_ns, units="ns").start())

async def reset_dut(dut, cycles=5):
    dut.axi_reset_n.value = 0
    dut.vga_reset_n.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.axi_clk)
        await RisingEdge(dut.vga_clk)

    dut.vga_reset_n.value = 1
    dut.axi_reset_n.value = 1
    await RisingEdge(dut.axi_clk)
    await RisingEdge(dut.vga_clk)

@cocotb.test()
async def test_main(dut):
    await start_clocks(dut)
    await reset_dut(dut)

    for _ in range(10):
        await RisingEdge(dut.vga_clk)


# @cocotb.test()
# async def test_vga_sync_activity(dut):
#     await start_clocks(dut)
#     await reset_dut(dut)

#     seen_hs = seen_vs = False
#     for _ in range(800 * 525):
#         await RisingEdge(dut.vga_clk)
#         if not dut.vga_hsync.value:
#             seen_hs = True
#         if not dut.vga_vsync.value:
#             seen_vs = True
#         if seen_hs and seen_vs:
#             break

#     assert seen_hs, "HSYNC never toggled high"
#     assert seen_vs, "VSYNC never toggled high"
#     dut._log.info("HSYNC and VSYNC activity observed.")