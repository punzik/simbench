#!/usr/bin/env bash

if [ -n "$1" ]; then
    dlen_arg="-testplusarg dlen=$1"
else
    dlen_arg=""
fi

xsim top $dlen_arg --runall
