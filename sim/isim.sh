#!/usr/bin/env bash
#
# iSim (True North Silicon, https://tn-si.com) -- a native analyse/elaborate
# entry point beside ghdl.sh's own. Mirrors ghdl.sh's shape (cd to this
# script's directory, an env-var override per tool, a `build/` scratch dir)
# but does NOT reach ghdl.sh's own target (a full neorv32_tb run): no entry
# in the Datum-Technology-Corporation/isim tree has a proven working run of
# the full testbench against iSim yet, only `neorv32_top` core elaboration --
# see that repository's test_piles/integration/README.md and
# INTEGRATION_ROADMAP_NEORV32.md for exactly where that frontier is. Offering
# a `--run` here that has not been proven working would be the silent-wrong-
# by-omission shape that project's own CLAUDE.md rules refuse.
#
# Analyses upstream's OWN rtl/file_list_core.f (not ghdl.sh's find-everything
# glob) -- the same file list ghdl.sh's `find ../rtl/core ../sim -name
# '*.vhd'` approximates for the full testbench, but authoritative and ordered
# for the core alone, which is as far as this script's own `--elab` reaches.
#
# iSim's `-f` command-file reader does not shell-expand `$NEORV32_HOME` the
# way a real shell (or ghdl.sh's own script) would -- a real, filed iSim CLI
# gap, not a neorv32 quirk. So NEORV32_HOME is substituted into a translated
# copy of the manifest before it is handed to isim-vcom -f.
#
# Usage: ./isim.sh [--elab]
#   (no args)  analyse rtl/file_list_core.f only
#   --elab     analyse, then elaborate neorv32_top (-sir)

set -e

cd "$(dirname "$0")"
ISIM_VCOM="${ISIM_VCOM:-isim-vcom}"
ISIM_ELAB="${ISIM_ELAB:-isim-elab}"
TOP="${TOP:-neorv32_top}"

export NEORV32_HOME
NEORV32_HOME="$(cd .. && pwd)"

mkdir -p build
sed "s|\$NEORV32_HOME|$NEORV32_HOME|g" ../rtl/file_list_core.f \
	> build/isim_file_list_core.f

echo "+ $ISIM_VCOM -work build/isim_work -lib work -f build/isim_file_list_core.f"
"$ISIM_VCOM" -work build/isim_work -lib work -f build/isim_file_list_core.f

if [ "$1" = "--elab" ]; then
	echo "+ $ISIM_ELAB -work build/isim_work -lib work -top $TOP -sir"
	"$ISIM_ELAB" -work build/isim_work -lib work -top "$TOP" -sir
fi
