#!/usr/bin/env bash

. ../scripts/sim_vars.sh

vvp -N ./top +dlen=$BLOCK_SIZE
