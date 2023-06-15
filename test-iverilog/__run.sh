#!/usr/bin/env bash

if [ -n "$1" ]; then
    dlen_arg="+dlen=$1"
else
    dlen_arg=""
fi

vvp -n ./top $dlen_arg
