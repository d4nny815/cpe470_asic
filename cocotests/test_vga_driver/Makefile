TOPLEVEL_LANG ?= verilog	
SIM ?= icarus	

ROOT_DIR      := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/../..)
RTL_DIR       := $(ROOT_DIR)/rtl

VERILOG_SOURCES := $(shell find $(RTL_DIR) -type f \
                       \( -name '*.v' -o -name '*.sv' -o -name '*.svh' \) \
                       | sort | tr '\n' ' ')

VERILOG_INCLUDE_DIRS := \
        $(RTL_DIR) \
        $(RTL_DIR)/common \
		$(RTL_DIR)/axi_bridge \
        $(RTL_DIR)/pixel_LUT \
        $(RTL_DIR)/framebuffer \
        $(RTL_DIR)/ip/async_fifo \
        $(RTL_DIR)/ip/EF_SRAM_CTRL

COCOTB_TOPLEVEL     := vga_driver
TOPLEVEL := $(COCOTB_TOPLEVEL)
COCOTB_TEST_MODULES := test_vga_driver
MODULE := $(COCOTB_TEST_MODULES)

# Turn on waveforms
WAVES := 1

include $(shell cocotb-config --makefiles)/Makefile.sim