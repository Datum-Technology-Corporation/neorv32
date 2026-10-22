#!/usr/bin/env bash
#
# iSim (True North Silicon, https://tn-si.com) -- a native entry point beside
# ghdl.sh's own. Mirrors ghdl.sh's shape (cd to this script's directory, an
# env-var override per tool, a `build/` scratch dir) and, since iSim lowers
# every 9-state structural driver of this testbench, reaches ghdl.sh's own
# target too: `--run` simulates the full `neorv32_tb` the way ghdl.sh does.
#
# Three modes:
#   (no args)  analyse upstream's OWN rtl/file_list_core.f (the core alone,
#              authoritative and ordered) into the `neorv32` library
#   --elab     analyse as above, then elaborate neorv32_top (-sir)
#   --run      analyse EVERY .vhd under ../rtl/core and ../sim -- ghdl.sh's
#              own `find` set, the testbench and its models included --
#              elaborate neorv32_tb and RUN it.  The run writes the same
#              files ghdl.sh's run writes next to this script:
#              neorv32.tracer0.log / neorv32.tracer1.log (the two CPU
#              instruction traces) and tb.uart0_rx.log / tb.uart1_rx.log;
#              the transcript goes to isim.log (tee'd, like ghdl.log).
#
# Where --run differs from ghdl.sh, said plainly: iSim has no --stop-time
# option (a filed CLI gap), so the run is bounded by WALL-CLOCK seconds,
# ISIM_WALL (default 14400), through `timeout`.  ghdl.sh stops at 10 ms of
# simulated time; the default IMEM image is in its idle loop long before
# then and the testbench's 14 [TB:JTAG] steps finish at 157120 ns.  A run
# that hits the wall exits 124.  What the wall costs: iSim does not flush
# open TEXTIO files when it is ended by a signal, so each tracer log keeps
# only its written-out 4096-byte blocks -- CPU 0's runs far past ghdl.sh's
# 310164 lines in a long enough wall, but CPU 1's (which goes quiet at
# `wfi') stops at 74 of its 100 lines.  Measured against ghdl.sh's own logs
# on 2026-10-21: the 14 JTAG steps, CPU 0's first 310164 lines and CPU 1's
# first 74 are byte-identical (about 2.5 h of wall on a loaded host).
#
# iSim's `-f` command-file reader does not shell-expand `$NEORV32_HOME` the
# way a real shell (or ghdl.sh's own script) would -- a real, filed iSim CLI
# gap, not a neorv32 quirk. So NEORV32_HOME is substituted into a translated
# copy of the manifest before it is handed to isim-vcom -f.
#
# The logical library is `neorv32`, as in ghdl.sh (`--work=neorv32`): every
# RTL file says `library neorv32;`. iSim refuses a library clause naming a
# library with nothing behind it, as dsim and GHDL do, so analysing into
# `work` does not work.
#
# Usage: ./isim.sh [--elab | --run]

set -e

cd "$(dirname "$0")"
ISIM_VCOM="${ISIM_VCOM:-isim-vcom}"
ISIM_ELAB="${ISIM_ELAB:-isim-elab}"
ISIM="${ISIM:-isim}"
ISIM_WALL="${ISIM_WALL:-14400}"

export NEORV32_HOME
NEORV32_HOME="$(cd .. && pwd)"

mkdir -p build

if [ "$1" = "--run" ]; then
	# ghdl.sh's own source set: everything under rtl/core and sim
	find ../rtl/core ../sim -type f -name '*.vhd' | sort > build/isim_file_list_tb.f
	echo "+ $ISIM_VCOM -work build/isim_work -lib neorv32 -f build/isim_file_list_tb.f"
	"$ISIM_VCOM" -work build/isim_work -lib neorv32 -f build/isim_file_list_tb.f
	echo "+ $ISIM_ELAB -work build/isim_work -lib neorv32 -top neorv32_tb -sir"
	"$ISIM_ELAB" -work build/isim_work -lib neorv32 -top neorv32_tb -sir
	echo "+ timeout $ISIM_WALL $ISIM -work build/isim_work -lib neorv32 -top neorv32_tb   (wall-clock bound, not --stop-time)"
	set +e
	timeout "$ISIM_WALL" "$ISIM" -work build/isim_work -lib neorv32 -top neorv32_tb 2>&1 | tee isim.log
	rc=${PIPESTATUS[0]}
	[ "$rc" = 124 ] && echo "isim.sh: run stopped at the ISIM_WALL=$ISIM_WALL s wall-clock bound"
	exit "$rc"
fi

sed "s|\$NEORV32_HOME|$NEORV32_HOME|g" ../rtl/file_list_core.f \
	> build/isim_file_list_core.f

echo "+ $ISIM_VCOM -work build/isim_work -lib neorv32 -f build/isim_file_list_core.f"
"$ISIM_VCOM" -work build/isim_work -lib neorv32 -f build/isim_file_list_core.f

if [ "$1" = "--elab" ]; then
	TOP="${TOP:-neorv32_top}"
	echo "+ $ISIM_ELAB -work build/isim_work -lib neorv32 -top $TOP -sir"
	"$ISIM_ELAB" -work build/isim_work -lib neorv32 -top "$TOP" -sir
fi
