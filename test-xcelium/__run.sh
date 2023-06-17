#!/usr/bin/env bash

. ../scripts/sim_vars.sh

xmsim -status top +dlen=$BLOCK_SIZE
