#!/bin/bash
# set -euo pipefail

# ! Courtesy of chat :)

usage() {
  echo "Usage: $0 <test_dir> [-s i|v]"
  echo "  <test_dir>    Name of the subdirectory under tests/"
  echo "  -s i          After building, launch surfer on the Icarus VCD"
  echo "  -s v          After building, launch surfer on the Verilator VCD"
  exit 1
}

# need at least one argument
if (( $# < 1 )); then
  make "tests"
  make "itests"
  exit 0
fi

test_dir=$1
shift

make "tests/${test_dir}"
ICARUS=1 make "tests/${test_dir}"

# optional: run surfer on the chosen waveform
if [[ $# -eq 2 && $1 == "-s" ]]; then
  case $2 in
    i)
      surfer "tests/${test_dir}/tb_icarus.vcd" \
             -s "tests/${test_dir}/icarus_cfg.ron"
      ;;
    v)
      surfer "tests/${test_dir}/tb_verilator.vcd" \
             -s "tests/${test_dir}/verilator_cfg.ron"
      ;;
    *)
      echo "Error: unknown mode '$2'"
      usage
      ;;
  esac
fi


# ./sim.sh <test_dir> -s i/v
# -s is optional for 

# make tests/<test_dir> && ICARUS=1 make tests/<test_dir>

# if -s i
# surfer tests/<test_dir>/tb_icarus.vcd -s tests/<test_dir>/icarus_cfg.ron 

# if -s v
# surfer tests/<test_dir>/tb_verilator.vcd -s tests/<test_dir>/verilator_cfg.ron 
