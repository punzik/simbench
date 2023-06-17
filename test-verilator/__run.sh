#!/usr/bin/env bash

. ../scripts/sim_vars.sh

./testbench/testbench +dlen=$BLOCK_SIZE
