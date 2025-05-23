# CPE 470 ASIC Project

## Camille Leute and Danny Gutierrez

https://github.com/efabless/EF_PSRAM_CTRL/tree/main 
https://www.logic-fruit.com/blog/digital-interfaces/axi-full-axi-lite-interfaces/ 

# TODO
- make testbench
  - axi bridge
  - axi bridge with FAKE axi transactions

- start making top module

- check pixel addr generator
- check control unit


<!-- ORDER TO CHECK VERIF & SYNTH -->
# Verification Plan

<!-- HAS TO WORK WITH BOTH ICARUS AND VERILATOR -->
# Design Plan
  - Make Top Level
    - VGA Timing
      - Check Timing Paths
    - VGA timing controls 
      - control unit
    - CSR Registers
    - Pixel Color LUT
    - Small Frame Buffer -> get LUT INDEX
      - only lower 4 bits to index
    - DAC
      - Macro
      - ensure timing
    - Axi Bridge
      - with proper axi transactions
  - Total Integration Tests