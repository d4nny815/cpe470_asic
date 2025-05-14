#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 <test_dir> [-b i|v] [-s i|v]

  <test_dir>    Name of the subdirectory under tests/

Options (after <test_dir>):
  -b i          Build only with Icarus, then launch surfer on the Icarus VCD
  -b v          Build only with Verilator, then launch surfer on the Verilator VCD
                (if -b is given, -s is ignored)
  -s i          Build both, then launch surfer on the Icarus VCD
  -s v          Build both, then launch surfer on the Verilator VCD

Behaviors:
  ./sim.sh
    → make itests && make tests          (crash if either fails)

  ./sim.sh <test_dir>
    → make tests/<test_dir> && ICARUS=1 make tests/<test_dir>
      (crash if either fails)

  ./sim.sh <test_dir> -b i|v
  ./sim.sh <test_dir> -b i|v -s i|v
    → only build the specified simulator, then launch surfer
      (crash if the build fails)

  ./sim.sh <test_dir> -s i|v
    → build the *other* simulator first (ignore its failure),
      then build the specified (crash if it fails),
      then launch surfer for the specified
EOF
  exit 1
}

# No arguments: build all regression tests
if [[ $# -eq 0 ]]; then
  make itests
  make tests
  exit 0
fi

test_dir=$1
shift

build_only=""
surf_only=""

while getopts ":b:s:" opt; do
  case "$opt" in
    b) build_only=$OPTARG ;;
    s) surf_only=$OPTARG ;;
    *) usage ;;
  esac
done

launch_surfer() {
  case "$1" in
    i)
      surfer "tests/${test_dir}/tb_icarus.vcd" \
             -s "tests/${test_dir}/icarus_cfg.ron"
      ;;
    v)
      surfer "tests/${test_dir}/tb_verilator.vcd" \
             -s "tests/${test_dir}/verilator_cfg.ron"
      ;;
    *)
      echo "Error: unknown simulator '$1'" >&2
      exit 1
      ;;
  esac
}

build_sim() {
  if [[ $1 == i ]]; then
    ICARUS=1 make "tests/${test_dir}"
  else
    make "tests/${test_dir}"
  fi
}

# -b has precedence over -s
if [[ -n $build_only ]]; then
  case "$build_only" in
    i|v) build_sim "$build_only" ;;
    *)   usage ;;
  esac
  # launch_surfer "$build_only"
  exit 0
fi

# -s only: build other first (ignore failure), then specified, then surfer
if [[ -n $surf_only ]]; then
  case "$surf_only" in
    i)
      if ! build_sim v; then
        echo "Verilator build failed, continuing..."
      fi
      build_sim i
      ;;
    v)
      if ! build_sim i; then
        echo "Icarus build failed, continuing..."
      fi
      build_sim v
      ;;
    *) usage ;;
  esac
  launch_surfer "$surf_only"
  exit 0
fi

# default: build both simulators for this test_dir, crash if either fails
make "tests/${test_dir}"
ICARUS=1 make "tests/${test_dir}"
