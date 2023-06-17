if [ $# -lt 3 ]
then
    echo "Usage: $0 <CPU_COUNT> <BLOCK_SIZE> <THREADS_COUNT"
    exit -1
fi

CPU_COUNT=$1
BLOCK_SIZE=$2
THREADS=$3

FFILE=../source/sources.f
