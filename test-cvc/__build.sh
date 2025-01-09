#!/usr/bin/env bash
set -e

. ../scripts/sim_vars.sh

rm -rf ./top

# CVC do not have $urandom function
cp ../source/testbench.sv ./
patch testbench.sv testbench.patch

# CVC bug with nonblocking assignment to part of vector
cp ../source/picorv32_tcm.sv ./
patch picorv32_tcm.sv picorv32_tcm.patch

# CVC does not support setting parameter via command line
cp ./top.sv ./top-mod.sv
sed -i -e "s/CPU_COUNT = 1024/CPU_COUNT = $CPU_COUNT/" top-mod.sv

sources=$(cat $FFILE | grep -v "testbench.sv\|picorv32_tcm.sv")

sv2v --top=top -w simbench-all.v top-mod.sv testbench.sv picorv32_tcm.sv $sources
patch simbench-all.v simbench-all.patch

cvc64 -o top -O -pipe +large +nospecify simbench-all.v
