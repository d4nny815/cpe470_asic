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
        DATA_BYTES = 1
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
        DATA_BYTES = 1
        try:
            rd = await with_timeout(
                self.axi_master.read(addr, DATA_BYTES),
                tmo_ns, "ns",
            )
        except SimTimeoutError as e:
            self.dut._log.error(str(e))
            raise

        print(f"DATA BUTES {rd.data}")
        word = int.from_bytes(rd.data, "big")
        return word


# * ============================================================================
# * Main Tests
# * ============================================================================

@cocotb.test()
async def test_prefetch_line(dut):
    verbose =  os.getenv("VERBOSE_CTB") == "1"
        
    tb = TB(dut)
    await tb.cycle_reset()

    for y in range(HEIGHT):
        # 1st line
        while bool(dut.timing.in_frame.value):
            await RisingEdge(dut.vga_clk)
        
        while not bool(dut.timing.in_frame.value):
            await RisingEdge(dut.vga_clk)

        # 2nd line
        for _ in range(WIDTH * 2):
            await RisingEdge(dut.vga_clk)

        assert bool(dut.framebuffer.vga_fetch_next.value), "NO WORKY"
        assert not bool(dut.timing.in_frame.value), "NO WORKY INFRAME"

        # starts prefetch start next mapped lines
        for x in range(WIDTH // 4):
            while not bool(dut.framebuffer.ps_start.value):
                await RisingEdge(dut.vga_clk)

            # assert main addr
            exp_addr = ((y + 1) * WIDTH + (x * 4)) % (FRAME_SIZE)
            dut_addr = int(dut.framebuffer.ps_addr.value)
            assert exp_addr == dut_addr, "[] NO WORKY ADDR"

            while not bool(dut.framebuffer.ps_done.value):
                await RisingEdge(dut.vga_clk)

            # assert line addr
            exp_addr = x * 4
            dut_addr = int(dut.framebuffer.lc_waddr.value)
            assert exp_addr == dut_addr, "[] NO WORKY LC ADDR"

            if bool(dut.timing.in_frame.value):
                exp_addr = (y + 1) * WIDTH + (x * 4)
                cur_dut_addr = int(dut.framebuffer.fb_vga_addr.value)
                assert cur_dut_addr < exp_addr, "[] PREFETCH TOO SLOW"

        if y == 3 and not verbose:
            return

@cocotb.test()
async def test_correct_addr(dut):
    verbose =  os.getenv("VERBOSE_CTB") == "1"
        
    tb = TB(dut)
    await tb.cycle_reset()

    first_time = True

    for y in range(HEIGHT):
        # 1st line
        for x in range(WIDTH * 2):
            # exp_y =

            exp_addr = y << 9 | (x // 2)
            if first_time:
                first_time = False
                continue
                
            dut_addr = int(dut.pixel_addr_gen.pixel_addr.value)
            assert exp_addr == dut_addr, f"dut addr is {dut_addr:x} exp is {exp_addr:x}"
            await FallingEdge(dut.vga_clk)
        

        for _ in range(HCNT_LINE - WIDTH * 2):
            assert not bool(dut.timing.in_frame.value), "NO WORKY INFRAME"
            await FallingEdge(dut.vga_clk)


        # 2nd line
        for x in range(WIDTH * 2):
            await FallingEdge(dut.vga_clk)

        for _ in range(HCNT_LINE - WIDTH * 2):
            assert not bool(dut.timing.in_frame.value), "NO WORKY INFRAME 2"
            await FallingEdge(dut.vga_clk)

        if y == 3 and not verbose:
            return
        
    for y in range(VCNT_LINE - HEIGHT * 2):
        for _ in range(HCNT_LINE):
            assert not bool(dut.timing.in_frame.value), "NO WORKY INFRAME 2"
            await FallingEdge(dut.vga_clk)

@cocotb.test()
async def test_correct_lut(dut):
    verbose =  os.getenv("VERBOSE_CTB") == "1"
        
    tb = TB(dut)
    await tb.cycle_reset()

    first_time = True

    # expected_indices = [i & 0xff for i in range(WIDTH)]
    # expected_indices[0] = 1

    # for x in range(WIDTH * 2):
    #     exp_line_addr = x // 2
    #     if first_time:
    #         first_time = False
    #         continue

    #     exp_ind = expected_indices[exp_line_addr]
    #     dut_ind = int(dut.framebuffer.lut_index.value)
    #     assert exp_ind == dut_ind, f"dut addr is {dut_ind:x} exp is {exp_ind:x}"
    #     await FallingEdge(dut.vga_clk)
    

    # for _ in range(HCNT_LINE - WIDTH * 2):
    #     assert not bool(dut.timing.in_frame.value), "NO WORKY INFRAME"
    #     await FallingEdge(dut.vga_clk)

    # expected_indices[0] = 0

    # # 2nd line
    # for x in range(WIDTH * 2):
    #     exp_line_addr = x // 2
    #     exp_ind = expected_indices[exp_line_addr]
    #     dut_ind = int(dut.framebuffer.lut_index.value)
    #     assert exp_ind == dut_ind, f"dut addr is {dut_ind:x} exp is {exp_ind:x}"
    #     await FallingEdge(dut.vga_clk)

    # # this is where din matter
    # dut.ps_din.value = 1

    # for _ in range(HCNT_LINE - WIDTH * 2):
    #     assert not bool(dut.timing.in_frame.value), "NO WORKY INFRAME 2"
    #     await FallingEdge(dut.vga_clk)

    # TODO change din

    for y in range(HEIGHT):

        # 1st line
        for x in range(WIDTH):
            if first_time:
                first_time = False
                continue

            exp_ind = int(dut.ps_din.value) << 4 | int(dut.ps_din.value) 
            dut_ind = int(dut.framebuffer.lut_index.value)
            assert exp_ind == dut_ind, f"dut addr is 0x{dut_ind:x} exp is 0x{exp_ind:x}"
            await FallingEdge(dut.vga_clk)
            await FallingEdge(dut.vga_clk)
        

        for _ in range(HCNT_LINE - WIDTH * 2):
            await FallingEdge(dut.vga_clk)
            assert not bool(dut.timing.in_frame.value), "NO WORKY INFRAME"

        dut.ps_din.value = (y + 1) & 0xf

        # 2nd line
        for x in range(WIDTH * 2):
            await FallingEdge(dut.vga_clk)

        for _ in range(HCNT_LINE - WIDTH * 2):
            await FallingEdge(dut.vga_clk)
            assert not bool(dut.timing.in_frame.value), "NO WORKY INFRAME 2"

        if y == 3 and not verbose:
            return
        
@cocotb.test()
async def test_fb_write_req(dut):
    tb = TB(dut)
    await tb.cycle_reset()


    FB_OFFSET   = 4
    GOLDEN_VAL  = 0xa5
    await tb.axi_write(AXI_FB_ADDR + FB_OFFSET, GOLDEN_VAL)

    # wait for a write request
    while not bool(dut.bridge.wr_req.value):
        await RisingEdge(dut.vga_clk)

    assert int(dut.wr_addr.value) == FB_ADDR + FB_OFFSET, "[FB_WRITE_REQ] DIDNT WRITE to framebuffer"
    assert int(dut.wr_data.value) == GOLDEN_VAL, "[FB_WRITE_REQ] DIDNT WRITE correct value"

    # ensure handling req
    await RisingEdge(dut.vga_clk)
    assert not bool(dut.bridge.wr_req.value), "[FB_WRITE_REQ] There is still a write request"
    assert int(dut.reg_wr_addr.value == FB_ADDR + FB_OFFSET), "[FB_WRITE_REQ] DIDNT Write Correct CR Value" 
    assert int(dut.reg_wr_data.value == GOLDEN_VAL), "[FB_WRITE_REQ] DIDNT Write Correct CR Value" 

    # wait for request to finish
    while not bool(dut.framebuffer.fb_valid.value):
        await RisingEdge(dut.vga_clk)


@cocotb.test()
async def test_csr_write_req(dut):
    tb = TB(dut)
    await tb.cycle_reset()

    # can write to cr
    GOLDEN_VAL = 0x5a
    await tb.axi_write(AXI_CSR_ADDR, GOLDEN_VAL)

    # wait for a write request
    while not bool(dut.bridge.wr_req.value):
        await RisingEdge(dut.vga_clk)

    assert int(dut.wr_addr.value) == CR_ADDR, "[CSR_WRITE_REQ] DIDNT WRITE to control register"
    assert int(dut.wr_data.value) == GOLDEN_VAL, "[CSR_WRITE_REQ] DIDNT WRITE correct value"

    await RisingEdge(dut.vga_clk)
    assert int(dut.reg_cr.value == GOLDEN_VAL), "[CSR_WRITE_REQ] DIDNT Write Correct CR Value" 

    # no other outstanding requests
    assert not bool(dut.bridge.wr_req.value), "[CSR_WRITE_REQ] There is still a write request"

    # cant write to sr
    BAD_VAL = 0x5a
    await tb.axi_write(AXI_CSR_ADDR+1, BAD_VAL)

    # wait for a write request
    for _ in range(10):
        assert not bool(dut.bridge.wr_req.value), "[CSR_WRITE_REQ] Trying to write to SR"
        await RisingEdge(dut.vga_clk)


@cocotb.test()
async def test_fill_write_req(dut):
    tb = TB(dut)
    await tb.cycle_reset()

    DEPTH = 18
    for i in range(DEPTH):
        await tb.axi_write(AXI_FB_ADDR + i, i)

    assert bool(dut.bridge.wr_full.value), "[FB_FILL_WRITE_REQ] FIFO Shoudl be full"

    # continue til no more requests
    while bool(dut.bridge.wr_req.value):
        await RisingEdge(dut.vga_clk)

    # finish last outstanding request
    while not bool(dut.framebuffer.fb_valid.value):
        await RisingEdge(dut.vga_clk)

@cocotb.test()
async def test_fb_read_req(dut):
    tb = TB(dut)
    await tb.cycle_reset()

    await tb.axi_read(AXI_FB_ADDR + 4)

    while bool(dut.bridge.rd_req.value):
        await RisingEdge(dut.vga_clk)

    for _ in range(10):
        await RisingEdge(dut.vga_clk)

    assert not bool(dut.bridge.rd_req.value), "[] brolken"

@cocotb.test()
async def test_csr_read_req(dut):
    tb = TB(dut)
    await tb.cycle_reset()

    # can read from cr
    GOLDEN_VAL = 0x5a
    await tb.axi_write(AXI_CSR_ADDR, GOLDEN_VAL)

    DUT_VAL = await tb.axi_read(AXI_CSR_ADDR)
    assert GOLDEN_VAL == DUT_VAL, f"BAD CR READ"

    GOLDEN_VAL = 0xff
    DUT_VAL = await tb.axi_read(AXI_CSR_ADDR+1)
    assert GOLDEN_VAL == DUT_VAL, f"BAD SR READ"

    # # cant write to sr
    # BAD_VAL = 0x5a
    # await tb.axi_write(AXI_CSR_ADDR+1, BAD_VAL)

    # # wait for a write request
    for _ in range(1):
    #     assert not bool(dut.bridge.wr_req.value), "[CSR_WRITE_REQ] Trying to write to SR"
        await RisingEdge(dut.vga_clk)


'''
TODO: 
tests to run
    read
        fb addr
        cr addr
        sr addr

    correct lut values to DAC
    
    maybe image from vga values
'''
