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
        $(RTL_DIR)/ip/async_fifo

COCOTB_TOPLEVEL     := vga_driver
TOPLEVEL := $(COCOTB_TOPLEVEL)
COCOTB_TEST_MODULES := test_vga_driver
MODULE := $(COCOTB_TEST_MODULES)

# Turn on waveforms
WAVES := 1

export COCOTB_MAX_SIM_TIME = 300ns

# Call CocoTB's makefile
include $(shell cocotb-config --makefiles)/Makefile.sim