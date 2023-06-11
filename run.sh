#!/usr/bin/env bash
set -e

BUILD=__build.sh
RUN=__run.sh

if [ -n "$1" ]
then
    tests=$1
else
    tests=$(ls -1d test-*)
fi

echo >> results.txt
echo "---------- Simulator's benchmark -----------" >> results.txt
echo $(date) >> results.txt
echo >> results.txt

for test_dir in $tests
do
    if [ ! -d "$test_dir" ]
    then
        echo "Directory $test_dit is not exists. Break"
        exit -1
    fi

    if [ -e $test_dir/$BUILD -a -e $test_dir/$RUN ]
    then
        echo "#### Run benchmark in $test_dir"

        cd $test_dir
        ./$BUILD
        start_ms=$(date +%s%N | cut -b1-13)
        ./$RUN
        stop_ms=$(date +%s%N | cut -b1-13)
        cd ..

        ms=$(expr $stop_ms - $start_ms)
        echo "#### $test_dir: $ms milliseconds"
        echo
        echo "$test_dir: $ms" >> results.txt
    else
        echo "Skip $test_dir directory"
    fi
done
