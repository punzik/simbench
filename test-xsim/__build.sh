#!/usr/bin/env bash
set -e

FFILE=../source/sources.f
SOURCES=$(cat $FFILE | sed -ze 's/\n/ /g')

rm -rf xsim.dir
rm -rf webtalk*
rm -rf xvlog.* xelab.* xsim.*
rm -rf top.wdb

xvlog -work work --sv top.sv $SOURCES
xelab --O3 -L work top
