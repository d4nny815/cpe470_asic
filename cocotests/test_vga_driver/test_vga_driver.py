import random
import cocotb
from cocotb.clock     import Clock
from cocotb.triggers  import RisingEdge, FallingEdge, with_timeout
from cocotb.handle  import Force
from cocotbext.axi import AxiLiteBus, AxiLiteMaster
from cocotb.result   import SimTimeoutError

FRAME_SIZE = 640 * 480
AXI_BASE_ADDR = 0x11000000
FB_ADDR_OFFSET = 0
CSR_ADDR_OFFSET = FRAME_SIZE
AXI_FB_ADDR = AXI_BASE_ADDR + FB_ADDR_OFFSET
AXI_CSR_ADDR = AXI_BASE_ADDR + CSR_ADDR_OFFSET

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

        for _ in range(5):
            await RisingEdge(self.dut.axi_clk)
            await RisingEdge(self.dut.vga_clk)

        self.dut.vga_reset_n.value = 1
        self.dut.axi_reset_n.value = 1
        
        while not self.dut.bridge_init_done.value:
            await RisingEdge(self.dut.vga_clk)

        await RisingEdge(self.dut.axi_clk)
        await RisingEdge(self.dut.vga_clk)

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

@cocotb.test()
async def test_fb_write_req(dut):
    tb = TB(dut)
    await tb.cycle_reset()

    await tb.axi_write(AXI_FB_ADDR, 0xa5)

    while not dut.status.axi_comms.wr_req:
        await RisingEdge(self.dut.vga_clk)

    assert wr_addr == AXI_FB_ADDR, "DIDNT WRITE to framebuffer"


@cocotb.test()
async def test_csr_write_req(dut):
    tb = TB(dut)
    await tb.cycle_reset()

    await tb.axi_write(AXI_CSR_ADDR, 0xa5)

@cocotb.test()
async def test_fill_write_req(dut):
    pass

# @cocotb.test()
# async def test_csr_write_req(dut):
#     pass


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