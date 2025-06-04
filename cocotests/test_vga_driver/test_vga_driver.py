import os
import random
import cocotb
from cocotb.clock     import Clock
from cocotb.triggers  import RisingEdge, FallingEdge, with_timeout
from cocotb.handle  import Force
from cocotbext.axi import AxiLiteBus, AxiLiteMaster
from cocotb.result   import SimTimeoutError

WIDTH      = 640 // 2
HEIGHT     = 480 // 2
HCNT_LINE  = 800
VCNT_LINE  = 525
FRAME_SIZE = (WIDTH) * (HEIGHT)
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

        cocotb.start_soon(Clock(dut.axi_clk, 7, units="ns").start())
        cocotb.start_soon(Clock(dut.vga_clk, 40, units="ns").start())
        cocotb.start_soon(Clock(dut.CLK_200MHz, 5, units="ns").start())

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
        self.dut.ps_din.value      = 0xa

        for _ in range(3):
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

        # word = int.from_bytes(rd.data, "little")
        # return word
        return 0


# * ============================================================================
# * Main Tests
# * ============================================================================

@cocotb.test()
async def test_next_pixel(dut):
    verbose =  os.getenv("VERBOSE_CTB") == "1"
        
    tb = TB(dut)
    await tb.cycle_reset()

    change_din = False

    for y in range(VCNT_LINE):
        change_din = True
        
        if (y == 3 and not verbose):
            print("Verbose off")
            return
        
        for x in range(HCNT_LINE):

            if bool(dut.timing.in_frame.value):
                v_addr = ((y // 2) & HEIGHT)
                h_addr = (((x + 2) // 2) & WIDTH)
                exp_addr = v_addr << 8 | h_addr
                dut_addr = int(dut.pixel_addr.value)
                
                # assert dut_addr == exp_addr, (
                    # f"Mismatch @ v={y}  h={x} y={y // 2}  x={x // 2}\n"
                    # f"v {v_addr} h {h_addr} exp {exp_addr}, got {dut_addr}\n"
                # )

            elif change_din: 
                tb.dut.ps_din.value = y & 0xf
                change_din = False

            await FallingEdge(dut.vga_clk)

    exp_addr = 0

    for y in range(2):
        for x in range(HCNT_LINE):
            in_frame = bool(dut.timing.in_frame.value)

            if in_frame:
                exp_addr += 1
                dut_addr = int(dut.pixel_addr.value)
                # assert dut_addr == exp_addr, (
                #     f"Mismatch @ line {y} col {x}: "
                #     f"exp {exp_addr}, got {dut_addr}"
                # )

            await FallingEdge(dut.vga_clk)


@cocotb.test()
async def test_fb_write_req(dut):
    tb = TB(dut)
    await tb.cycle_reset()

    await tb.axi_write(AXI_FB_ADDR + 4, 0xa5)

    # while dut.bridge.wr_fifo_empty.value:
    while not bool(dut.bridge.wr_req.value):
        await RisingEdge(dut.vga_clk)

    assert int(dut.wr_addr.value) == FB_ADDR + 4, "DIDNT WRITE to framebuffer"
    assert int(dut.wr_data.value) == 0xa5, "DIDNT WRITE correct value"

    while not bool(dut.framebuffer.fb_valid.value):
        await RisingEdge(dut.vga_clk)
    
    while bool(dut.bridge.wr_req.value):
        await RisingEdge(dut.vga_clk)



@cocotb.test()
async def test_csr_write_req(dut):
    tb = TB(dut)
    await tb.cycle_reset()

    await tb.axi_write(AXI_CSR_ADDR, 0x5a)

    while dut.bridge.wr_fifo_empty.value:
        await RisingEdge(dut.vga_clk)

    assert int(dut.wr_addr.value) == CR_ADDR, "DIDNT WRITE to control register"
    assert int(dut.wr_data.value) == 0x5a, "DIDNT WRITE correct value"

    while not bool(dut.bridge.wr_req.value):
        await RisingEdge(dut.vga_clk)

    while bool(dut.bridge.wr_req.value):
        await RisingEdge(dut.vga_clk)

@cocotb.test()
async def test_fill_write_req(dut):
    tb = TB(dut)
    await tb.cycle_reset()

    DEPTH = 18
    for i in range(DEPTH):
        await tb.axi_write(AXI_FB_ADDR + (i * 4), i)

    assert dut.bridge.wr_full.value == 1, "FIFO Shoudl be full"

    while bool(dut.bridge.wr_req.value):
        await RisingEdge(dut.vga_clk)

    while not bool(dut.framebuffer.fb_valid.value):
        await RisingEdge(dut.vga_clk)

# TODO: read requests
@cocotb.test()
async def test_fb_read_req(dut):
    tb = TB(dut)
    await tb.cycle_reset()

    await tb.axi_read(AXI_FB_ADDR + 4)

    for _ in range(10):
        await RisingEdge(dut.vga_clk)
