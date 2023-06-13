#!/usr/bin/env bash

FFILE=../source/sources.f

iverilog -g2012 -o top -f $FFILE top.sv
