#!/usr/bin/env bash
set -e

. ../scripts/sim_vars.sh

rm -rf testbench
vlog -sv -work testbench -vopt $param -f $FFILE top.sv
