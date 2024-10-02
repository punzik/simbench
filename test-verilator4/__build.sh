#!/usr/bin/env bash
set -e

. ../scripts/sim_vars.sh

make clean
make OPT_FAST="-Os -march=native" VM_PARALLEL_BUILDS=0 PARAMS="-GCPU_COUNT=$CPU_COUNT" THREADS=$THREADS
