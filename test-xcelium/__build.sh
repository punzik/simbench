#!/usr/bin/env bash
set -e

. ../scripts/sim_vars.sh

rm -rf xcelium.d

## WARNING: defparam is not tested

xmvlog -sv -f $FFILE top.sv
xmelab -timescale 1ps/1ps -defparam top.CPU_COUNT=$CPU_COUNT top
