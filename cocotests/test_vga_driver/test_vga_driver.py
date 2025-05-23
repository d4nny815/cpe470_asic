import os
import random
import cocotb
from cocotb.clock     import Clock
from cocotb.triggers  import RisingEdge, FallingEdge, with_timeout
from cocotb.handle  import Force
from cocotbext.axi import AxiLiteBus, AxiLiteMaster
from cocotb.result   import SimTimeoutError

FRAME_SIZE = 640 * 480
FB_ADDR_OFFSET = 0
CSR_ADDR_OFFSET = FRAME_SIZE
AXI_BASE_ADDR = 0x11000000
AXI_FB_ADDR = AXI_BASE_ADDR + FB_ADDR_OFFSET
AXI_CSR_ADDR = AXI_BASE_ADDR + CSR_ADDR_OFFSET

FB_ADDR = FB_ADDR_OFFSET
CR_ADDR = CSR_ADDR_OFFSET
SR_ADDR = CR_ADDR + 1

class TB:
    def __init__(self, dut):
        self.dut = dut

        cocotb.start_soon(Clock(dut.axi_clk, 10, units="ns").start())
        cocotb.start_soon(Clock(dut.vga_clk, 40, units="ns").start())

        bus = AxiLiteBus.from_prefix(dut, "s_axi")

        self.axi_master = AxiLiteMaster(
                bus,
                dut.axi_clk,
                dut.axi_reset_n,        # active-LOW
                reset_active_level=False
        )

    async def cycle_reset(self):
        self.dut.axi_reset_n.value = 0
        self.dut.vga_reset_n.value = 0

        for _ in range(2):
            await RisingEdge(self.dut.axi_clk)
            await RisingEdge(self.dut.vga_clk)

        self.dut.vga_reset_n.value = 1
        self.dut.axi_reset_n.value = 1
        
        while not self.dut.bridge_init_done.value:
            await FallingEdge(self.dut.vga_clk)

    async def axi_write(self, addr, val, tmo_ns=1000):
        DATA_BYTES = 4
        payload    = val.to_bytes(DATA_BYTES, "little")
        
        try:
            await with_timeout(
                self.axi_master.write(addr, payload),
                tmo_ns, "ns",
            )
        except SimTimeoutError:
            dut = self.dut
            dut._log.error(
                f"AWVALID={int(dut.s_axi_awvalid.value)} "
                f"AWREADY={int(dut.s_axi_awready.value)} | "
                f"WVALID={int(dut.s_axi_wvalid.value)} "
                f"WREADY={int(dut.s_axi_wready.value)} | "
                f"BVALID={int(dut.s_axi_bvalid.value)} "
                f"BREADY={int(dut.s_axi_bready.value)}"
            )
            raise

    async def axi_read(self, addr, tmo_ns=1000) -> int:
        DATA_BYTES = 4
        try:
            rd = await with_timeout(
                self.axi_master.read(addr, DATA_BYTES),
                tmo_ns, "ns",
            )
        except SimTimeoutError as e:
            self.dut._log.error(str(e))
            raise

        word = int.from_bytes(rd.data, "little")
        return word


@cocotb.test()
async def test_fb_write_req(dut):
    tb = TB(dut)
    await tb.cycle_reset()

    await tb.axi_write(AXI_FB_ADDR, 0xa5)

    while dut.bridge.wr_fifo_empty.value:
        await RisingEdge(dut.vga_clk)

    assert int(dut.wr_addr.value) == FB_ADDR, "DIDNT WRITE to framebuffer"
    assert int(dut.wr_data.value) == 0xa5, "DIDNT WRITE correct value"

@cocotb.test()
async def test_csr_write_req(dut):
    tb = TB(dut)
    await tb.cycle_reset()

    await tb.axi_write(AXI_CSR_ADDR, 0x5a)

    while dut.bridge.wr_fifo_empty.value:
        await RisingEdge(dut.vga_clk)

    assert int(dut.wr_addr.value) == CR_ADDR, "DIDNT WRITE to control register"
    assert int(dut.wr_data.value) == 0x5a, "DIDNT WRITE correct value"

@cocotb.test()
async def test_fill_write_req(dut):
    tb = TB(dut)
    await tb.cycle_reset()

    DEPTH = 16
    for _ in range(DEPTH):
        await tb.axi_write(AXI_FB_ADDR, 0xff)


    assert dut.bridge.wr_full.value == 1, "FIFO Shoudl be full"

# TODO: read requests
# @cocotb.test()
# async def test_fb_read_req(dut):
#     tb = TB(dut)
#     await tb.cycle_reset()

#     await tb.axi_read(AXI_FB_ADDR)

#     for _ in range(3):
#         await RisingEdge(dut.vga_clk)

@cocotb.test()
async def test_next_pixel(dut):
    if os.getenv("VERBOSE_CTB") != "1":
        dut._log.info("Skipping test_next_pixel (set VERBOSE_CTB=1 to run)")
        return
    
    tb = TB(dut)
    await tb.cycle_reset()

    WIDTH      = 640
    HEIGHT     = 480
    HCNT_LINE  = 800
    VCNT_LINE  = 525

    exp_addr = 0

    for y in range(HEIGHT):
        for x in range(HCNT_LINE):
            in_frame = bool(dut.timing.in_frame.value)

            if in_frame:
                exp_addr += 1
                dut_addr = int(dut.pixel_addr.value)
                assert dut_addr == exp_addr, (
                    f"Mismatch @ line {y} col {x}: "
                    f"exp {exp_addr}, got {dut_addr}"
                )

            await FallingEdge(dut.vga_clk)


@cocotb.test()
async def test_vga_sync_activity(dut):
    if os.getenv("VERBOSE_CTB") != "1":
        dut._log.info("Skipping test_next_pixel (set VERBOSE_CTB=1 to run)")
        return
    await start_clocks(dut)
    await reset_dut(dut)

    seen_hs = seen_vs = False
    for _ in range(800 * 525):
        await RisingEdge(dut.vga_clk)
        if not dut.vga_hsync.value:
            seen_hs = True
        if not dut.vga_vsync.value:
            seen_vs = True
        if seen_hs and seen_vs:
            break

    assert seen_hs, "HSYNC never toggled high"
    assert seen_vs, "VSYNC never toggled high"
    dut._log.info("HSYNC and VSYNC activity observed.")