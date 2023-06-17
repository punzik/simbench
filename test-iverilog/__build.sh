#!/usr/bin/env bash

. ../scripts/sim_vars.sh

iverilog -g2012 -o top -Ptop.CPU_COUNT=$CPU_COUNT -f $FFILE top.sv
