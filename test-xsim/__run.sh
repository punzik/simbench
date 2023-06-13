#!/usr/bin/env bash

#vsim -c -batch -voptargs=+acc=npr -do "run -all" -quiet -lib testbench top
xsim top --runall
