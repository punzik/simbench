#!/usr/bin/env bash
set -e

make clean
make OPT_FAST="-Os -march=native" VM_PARALLEL_BUILDS=0
