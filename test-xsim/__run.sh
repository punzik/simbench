#!/usr/bin/env bash

. ../scripts/sim_vars.sh

xsim top -testplusarg dlen=$BLOCK_SIZE --runall
