#!/usr/bin/env bash
set -e

rm -rf testbench
vlog -sv -work testbench -vopt -f ../source/sources.f top.sv
