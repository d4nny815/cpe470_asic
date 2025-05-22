INC_DIR := ./include

RTL_SRCS 	:= $(shell find rtl -name '*.sv' -or -name '*.v')
TB_SRCS 	:= $(shell find tests -name '*.sv' -or -name '*.v')

INCLUDE_DIRS := $(sort $(dir $(shell find . -name '*.svh')))
RTL_DIRS	 := $(sort $(dir $(RTL_SRCS)))
TB_DIRS			:= $(sort $(dir $(TB_SRCS)))

ALL_INC_DIRS := $(INCLUDE_DIRS) $(RTL_DIRS) $(TB_DIRS)
LINT_INCLUDES := $(foreach dir, $(ALL_INC_DIRS), -I$(realpath $(dir))) -I$(PDKPATH) 

TEST_DIR = ./tests
TEST_SUBDIRS = $(shell cd $(TEST_DIR) && ls -d */ | grep -v "__pycache__" )
TESTS = $(TEST_SUBDIRS:/=)

# Main Linter and Simulatior is Verilator
LINTER := verilator
LINT_OPTS += --lint-only --timing $(LINT_INCLUDES)

SIMULATOR := verilator
SIMULATOR_ARGS := --binary --timing --trace --trace-structs \
	--assert --timescale 1ns --quiet  
SIMULATOR_BINARY := ./obj_dir/V*
SIMULATOR_SRCS := *.sv

# Optional use of Icarus as Linter and Simulator
ifdef ICARUS
LINTER    := iverilog
LINT_OPTS := -Wall -g2012 
SIMULATOR := iverilog
SIMULATOR_ARGS := -g2012
SIMULATOR_BINARY := a.out
SIMULATOR_SRCS := $(foreach src, $(RTL_SRCS) $(IP_SRCS) $(TB_SRCS), $(realpath $(src))) *.sv
SIM_TOP := `$(shell pwd)/scripts/top.sh -s`
endif
# Gate Level Verification
ifdef GL
SIMULATOR := iverilog
LINT_INCLUDES := -I$(PDKPATH) -I$(realpath gl)
SIMULATOR_ARGS := -g2012 -DFUNCTIONAL -DUSE_POWER_PINS 
SIMULATOR_BINARY := a.out
SIMULATOR_SRCS = $(realpath gl)/* *.sv
endif


# Text formatting for tests
BOLD = `tput bold`
GREEN = `tput setaf 2`
ORANG = `tput setaf 214`
RED = `tput setaf 1`
RESET = `tput sgr0`

TEST_GREEN := $(shell tput setaf 2)
TEST_ORANGE := $(shell tput setaf 214)
TEST_RED := $(shell tput setaf 1)
TEST_RESET := $(shell tput sgr0)

all: lint_all tests

lint: lint_all
.PHONY: lint_all

ifdef ICARUS
lint_all:
	@printf "\n$(GREEN)$(BOLD) ----- Linting RTL Modules ----- $(RESET)\n"
	@for src in $(RTL_SRCS); do \
	  if grep -qE '^[[:space:]]*package' $$src; then \
	    printf "  [pkg]  $$src ... "; \
	    if iverilog $(LINT_OPTS) $(LINT_INCLUDES) $$src > /dev/null 2>&1; then \
	      printf "$(GREEN)PASSED$(RESET)\n"; \
	    else \
	      printf "\n"; \
	    fi; \
	    continue; \
	  fi; \
	  # otherwise grab the first `module NAME` \
	  mod=$$(grep -m1 -oE '^[[:space:]]*module[[:space:]]+([[:alnum:]_]+)' $$src \
	          | awk '{print $$2}'); \
	  if [ -z "$$mod" ]; then \
	    printf "  [!?] $$src (no module found!) ... "; \
	    iverilog $(LINT_OPTS) $(LINT_INCLUDES) $$src > /dev/null 2>&1 && \
	      printf "$(GREEN)PASSED$(RESET)\n" || \
	      { printf "$(RED)FAILED$(RESET)\n"; iverilog $(LINT_OPTS) $(LINT_INCLUDES) $$src; }; \
	    continue; \
	  fi; \
	  printf "  [mod] $$src (top=$$mod) ... "; \
	  if iverilog $(LINT_OPTS) $(LINT_INCLUDES) -s $$mod $$src > /dev/null 2>&1; then \
	    printf "$(GREEN)PASSED$(RESET)\n"; \
	  else \
	    printf "$(RED)FAILED$(RESET)\n"; \
	    iverilog $(LINT_OPTS) $(LINT_INCLUDES) -s $$mod $$src; \
	  fi; \
	done

	@printf "\n$(GREEN)$(BOLD) ----- Linting TB Modules ----- $(RESET)\n"
	@for src in $(TB_SRCS); do \
	  if grep -qE '^[[:space:]]*package' $$src; then \
	    printf "  [pkg]  $$src ... "; \
	    if iverilog $(LINT_OPTS) $(LINT_INCLUDES) $$src > /dev/null 2>&1; then \
	      printf "$(GREEN)PASSED$(RESET)\n"; \
	    else \
	      printf "$(RED)FAILED$(RESET)\n"; \
	      iverilog $(LINT_OPTS) $(LINT_INCLUDES) $$src; \
	    fi; \
	    continue; \
	  fi; \
	  mod=$$(grep -m1 -oE '^[[:space:]]*module[[:space:]]+([[:alnum:]_]+)' $$src \
	          | awk '{print $$2}'); \
	  printf "  [mod] $$src (top=$$mod) ... "; \
	  if iverilog $(LINT_OPTS) $(LINT_INCLUDES) -s $$mod $$src > /dev/null 2>&1; then \
	    printf "$(GREEN)PASSED$(RESET)\n"; \
	  else \
	    printf "$(RED)FAILED$(RESET)\n"; \
	    iverilog $(LINT_OPTS) $(LINT_INCLUDES) -s $$mod $$src; \
	  fi; \
	done
else
lint_all: 
	@printf "\n$(GREEN)$(BOLD) ----- Linting RTL Modules ----- $(RESET)\n"
	@for src in $(RTL_SRCS); do \
		top_module=$$(basename $$src .sv); \
		top_module=$$(basename $$top_module .v); \
		printf "Linting $$src . . . "; \
		# printf "\n\t\t$(LINTER) $(LINT_OPTS)"; \
		if $(LINTER) $(LINT_OPTS) --top-module $$top_module $$src > /dev/null 2>&1; then \
			printf "$(GREEN)PASSED$(RESET)\n"; \
		else \
			printf "$(RED)FAILED$(RESET)\n"; \
			$(LINTER) $(LINT_OPTS) --top-module $$top_module $$src; \
		fi; \
	done
	@printf "\n$(GREEN)$(BOLD) ----- Linting TB Modules ----- $(RESET)\n"
	@for src in $(TB_SRCS); do \
		top_module=$$(basename $$src .sv); \
		top_module=$$(basename $$top_module .v); \
		printf "Linting $$src . . . "; \
		if $(LINTER) $(LINT_OPTS) --top-module $$top_module $$src > /dev/null 2>&1; then \
			printf "$(GREEN)PASSED$(RESET)\n"; \
		else \
			printf "$(RED)FAILED$(RESET)\n"; \
			$(LINTER) $(LINT_OPTS) --top-module $$top_module $$src; \
		fi; \
	done

endif

.PHONY: lint_top
lint_top:
	@printf "\n$(GREEN)$(BOLD) ----- Linting $(TOP_MODULE) ----- $(RESET)\n"
	@printf "Linting Top Level Module: $(TOP_FILE)\n";
	$(LINTER) $(LINT_OPTS) --top-module $(TOP_MODULE) $(TOP_FILE)


tests: $(TESTS) 

tests/%: FORCE
	make -s $(subst /,, $(basename $*))

itests: 
	@ICARUS=1 make tests

gl_tests:
	@mkdir -p gl
	@cp runs/recent/final/pnl/* gl/
	@cat scripts/gatelevel.vh gl/*.v > gl/temp
	@mv -f gl/temp gl/*.v
	@rm -f gl/temp
	@GL=1 make tests

.PHONY: $(TESTS)
$(TESTS): 
	@printf "\n$(GREEN)$(BOLD) ----- Running Test: $@ ----- $(RESET)\n"
	@printf "\n$(BOLD) Building with $(SIMULATOR)... $(RESET)\n"

# Build With Simulator
	@cd $(TEST_DIR)/$@;\
		$(SIMULATOR) $(SIMULATOR_ARGS) $(SIMULATOR_SRCS) $(LINT_INCLUDES) $(SIM_TOP) > build.log
	
	@printf "\n$(BOLD) Running... $(RESET)\n"

# Run Binary and Check for Error in Result
	@if cd $(TEST_DIR)/$@;\
		./$(SIMULATOR_BINARY) > results.log \
		&& !( cat results.log | grep -qi error ) \
		then \
			printf "$(GREEN)PASSED $@$(RESET)\n"; \
		else \
			printf "$(RED)FAILED $@$(RESET)\n"; \
			cat results.log; \
		fi; \

COCOTEST_DIR = ./cocotests
COCOTEST_SUBDIRS = $(shell cd $(COCOTEST_DIR) && ls -d */ | grep -v "__pycache__" )
COCOTESTS = $(COCOTEST_SUBDIRS:/=)
.PHONY: cocotests
cocotests:
	@$(foreach test,  $(COCOTESTS), make -sC $(COCOTEST_DIR)/$(test);)

OPENLANE_CONF ?= config.*
openlane:
	@`which openlane` --flow Classic $(OPENLANE_CONF)
	@cd runs && rm -f recent && ln -sf `ls | tail -n 1` recent

%.json %.yaml: FORCE
	@echo $@
	OPENLANE_CONF=$@ make openlane

FORCE: ;

openroad:
	scripts/openroad_launch.sh | openroad

.PHONY: clean
clean:
	rm -f `find tests -iname "*.vcd"`
	rm -f `find tests -iname "a.out"`
	rm -f `find tests -iname "*.log"`
	rm -rf `find tests -iname "obj_dir"`

.PHONY: VERILOG_SOURCES
VERILOG_SOURCES: 
	@echo $(realpath $(RTL_SRCS))