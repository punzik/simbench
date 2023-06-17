#!/usr/bin/env bash

## Default valies
CPU_COUNT=1024
BLOCK_SIZE=1
THREADS=1

BLD_SCRIPT="__build.sh"
RUN_SCRIPT="__run.sh"
TEST_DIR_PREFIX="test-"
LOG_PREFIX="####"

function sim_dir_valid()
{
    if [ -e "$1/$BLD_SCRIPT" ] && [ -e "$1/$RUN_SCRIPT" ]
    then
        return 0
    else
        return 1
    fi
}

function sim_list()
{
    for dir in "$TEST_DIR_PREFIX"*
    do
        if sim_dir_valid "$dir"
        then
            echo "${dir:5}"
        fi
    done
}

function print_help()
{
    echo "Usage: $0 [OPTION]... [SIM...]"
    echo "Run simulator benchmark. Calculates MD5 hash from a block data"
    echo "on an array of soft-cores PicoRV32."
    echo
    echo "Options:"
    echo "  -c [COUNT]    Soft CPU count in simulation. Default: 1024"
    echo "  -s [SIZE]     Data block size in bytes. Default: 1024 bytes"
    echo "  -t [COUNT]    Simulation threads count. Default: 1"
    echo "                (so far only for Verilator)"
    echo "  -l            List of available benchmarks"
    echo "  -h            This help"
    echo
    echo "The SIM parameter is the name of the simulator from the list of"
    echo "option -l. If the parameter is not specified, benchmarks for all"
    echo "simulators will be performed. Be careful, some simulators take "
    echo "a very long time to benchmark."
    echo
}

function check_arg(){
    if [[ $2 == -* ]]
    then
	echo "Option $1 requires an argument" >&2
	exit 1
    fi
}

function parse_param()
{
    while getopts ":c:s:t:lh" opt
    do
	case $opt in
	    c)
		check_arg "-c" "$OPTARG"
                CPU_COUNT=$OPTARG
		;;
	    s)
		check_arg "-s" "$OPTARG"
                BLOCK_SIZE=$OPTARG
		;;
	    t)
		check_arg "-t" "$OPTARG"
                THREADS=$OPTARG
		;;
	    l)
		sim_list
                exit 0
		;;
	    h)
		print_help
                exit 0
		;;
	    \?)
		echo "Invalid option: -$OPTARG" >&2
		print_help
		exit 1
		;;
	    :)
		echo "Option -$OPTARG requires an argument" >&2
		exit 1
		;;
	esac
    done
}

function log()
{
    echo -n "$LOG_PREFIX "
    echo "$@"
}

function run_benchmark()
{
    benchmark=$1
    dir=$TEST_DIR_PREFIX$benchmark

    if sim_dir_valid "$dir"
    then
        local t0 t1 ms

        if cd "$dir"
        then
            # Build
            log "Build $benchmark"
            t0=$(date +%s%N | cut -b1-13)

            if ! ./$BLD_SCRIPT "$CPU_COUNT" "$BLOCK_SIZE" "$THREADS"
            then
                cd ..
                log "Build $benchmark FAILED"
                return 1
            fi

            t1=$(date +%s%N | cut -b1-13)
            ms=$((t1 - t0))
            log "Build $benchmark time (ms): $ms"

            echo

            # Run
            log "Run $benchmark"
            t0=$(date +%s%N | cut -b1-13)

            if ! ./$RUN_SCRIPT "$CPU_COUNT" "$BLOCK_SIZE" "$THREADS"
            then
                cd ..
                log "RUN $benchmark FAILED"
                return 1
            fi

            t1=$(date +%s%N | cut -b1-13)
            ms=$((t1 - t0))
            log "Run $benchmark time (ms): $ms"

            cd ..
            return 0
        else
            log "Can't change dir to $dir"
            return 1
        fi
    else
        log "No run scripts found in $dir"
        return 1
    fi
}

parse_param "$@"
shift $((OPTIND - 1))

if [ $# -gt 0 ]
then
    benches="$*"
else
    for b in $(sim_list); do benches="$benches$b "; done
fi

log "Soft-cores count: $CPU_COUNT"
log "Block size: $BLOCK_SIZE"
log "Threads count: $THREADS"
log "Benchmarks: $benches"

for bench in $benches
do
    echo
    run_benchmark "$bench"
done
