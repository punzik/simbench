#!/usr/bin/env bash
set -e

rm -rf xcelium.d

xmvlog -sv -f ../source/sources.f top.sv
xmelab -timescale 1ps/1ps top
