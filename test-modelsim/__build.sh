#!/usr/bin/env bash
set -e

FFILE=../source/sources.f

rm -rf testbench
vlog -sv -work testbench -vopt -f $FFILE top.sv
