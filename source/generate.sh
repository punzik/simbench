#!/usr/bin/env bash
set -e

../scripts/register-gen.scm io.reg > io_reg.v
../scripts/register-gen.scm -c io.reg > io_reg.h
../scripts/register-gen.scm -t io.reg > io_reg.txt
../scripts/picorv32-bus-mux-gen.scm -s 0+0x10000 -s 0x10000+0x10000 -s 0x01000000+0x1000 -m bus_mux > bus_mux.v
../scripts/picorv32-bus-mux-gen.scm -s 0+0x10000 -s 0x10000+0x10000 -s 0x01000000+0x1000 -m bus_mux -f > bus_mux.sby
