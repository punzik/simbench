#!/usr/bin/env bash
set -e

. ../scripts/sim_vars.sh

SOURCES=$(cat $FFILE | sed -ze 's/\n/ /g')

rm -rf xsim.dir
rm -rf webtalk*
rm -rf xvlog.* xelab.* xsim.*
rm -rf top.wdb

xvlog -work work --sv top.sv $SOURCES
xelab --O3 --generic_top "CPU_COUNT=$CPU_COUNT" -L work top
