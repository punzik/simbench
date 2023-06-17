#!/usr/bin/env bash

. ../scripts/sim_vars.sh

vsim -batch -voptargs=+acc=npr -do "run -all" -quiet +dlen=$BLOCK_SIZE -GCPU_COUNT=$CPU_COUNT -lib testbench top
