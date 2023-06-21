#!/usr/bin/env bash
set -e

. ../scripts/sim_vars.sh

rm -rf csrc simv.daidir simv

vcs -full64 -lca -sverilog -notice -nc -timescale=1ns/1ps -f $FFILE -pvalue+top.CPU_COUNT=$CPU_COUNT -l build.log top.sv
