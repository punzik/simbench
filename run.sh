#!/usr/bin/env bash

BUILD=__build.sh
RUN=__run.sh

if [ "$1" == "all" ]
then
    tests=$(ls -1d test-*)
elif [ -n "$1" ]
then
    tests="$@"
else
    echo "Usage: $0 <TEST_DIRECTORY | all>"
    exit -1
fi

## Log header
echo >> results.txt
echo "---------- Simulator's benchmark -----------" >> results.txt
echo $(date) >> results.txt
echo >> results.txt

## Run tests
for test_dir in $tests
do
    if [ ! -d "$test_dir" ]
    then
        echo "Directory $test_dir is not exists"
        exit -1
    fi

    if [ -e $test_dir/$BUILD -a -e $test_dir/$RUN ]
    then
        echo "#### Run benchmark in $test_dir"

        cd $test_dir

        ./$BUILD
        if [ $? -eq 0 ]
        then
            start_ms=$(date +%s%N | cut -b1-13)

            ./$RUN
            if [ $? -eq 0 ]
            then
                stop_ms=$(date +%s%N | cut -b1-13)
                ms=$(expr $stop_ms - $start_ms)
                echo "#### $test_dir: $ms milliseconds"
            else
                ms="RUN FAIL"
                echo "#### $test_dir: run fail"
            fi
        else
            ms="BUILD FAIL"
            echo "#### $test_dir: build fail"
        fi

        echo ""
        cd ..

        echo "$test_dir: $ms" >> results.txt
    else
        echo "Skip $test_dir directory"
    fi
done
