#!/usr/bin/env bash

vsim -batch -voptargs=+acc=npr -do "run -all" -quiet -lib testbench top
