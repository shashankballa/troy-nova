DEV=-D
NTT=""
LOG_FNAME="conv2d"
WORK_DIR=`pwd`
LOG_DIR=$WORK_DIR/logs

mkdir -p $LOG_DIR

if [[ $* == *"-cpu"* ]]; then
    DEV="-H"
fi

LOG_FNAME="${LOG_FNAME}${DEV}"

if [[ $* == *"-ntt"* ]]; then
    NTT="-ntt"
fi

LOG_FNAME="${LOG_FNAME}${NTT}"

if [[ "$*" == *"-l="* ]]; then
    LOGNUM=$(echo $* | grep -o -P '(?<=-l=)\d+' | head -1)
    LOG_FNAME="$LOGNUM-$LOG_FNAME"
fi

LOG_FNAME="${LOG_FNAME}.log"
    
if [[ $* == *"-help"* ]]; then
    ./build/test/bench_conv2d -h
else
    ./build/test/bench_conv2d $DEV $NTT -bs 1 -ih 56 -iw 56 -ic 16 -kh 3 -kw 3 -oc 64 -q "60,49" -N 4096 -rt 37 -usp 1 > $LOG_DIR/$LOG_FNAME
fi