#!/usr/bin/env bash

. ../scripts/sim_vars.sh

vvp -n ./top +dlen=$BLOCK_SIZE
