#!/usr/bin/env bash

if [ -n "$1" ]; then
    dlen_arg="+dlen=$1"
else
    dlen_arg=""
fi

vsim -batch -voptargs=+acc=npr -do "run -all" -quiet $dlen_arg -lib testbench top
