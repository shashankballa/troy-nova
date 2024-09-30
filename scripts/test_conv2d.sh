DEV=-D
NTT=""
LOG_FNAME="sqnet-conv2d"
WORK_DIR=`pwd`
LOGS_DIR=$WORK_DIR/logs

mkdir -p $LOGS_DIR

if [[ $* == *"-cpu"* ]]; then
    DEV="-H"
    LOG_FNAME="${LOG_FNAME}-cpu"
else
    LOG_FNAME="${LOG_FNAME}-gpu"
fi

if [[ $* == *"-ntt"* ]]; then
    NTT="--ntt"
    LOG_FNAME="${LOG_FNAME}-seconnds_2"
else
    LOG_FNAME="${LOG_FNAME}-cheetah"
fi

LOG_FNAME="${LOG_FNAME}.log"

if [[ "$*" == *"-l="* ]]; then
    LOGNUM=$(echo $* | grep -o -P '(?<=-l=)\d+' | head -1)
    LOG_FNAME="$LOGNUM-$LOG_FNAME"
fi
echo -e "Log filename set to $LOG_FNAME"

if [[ "$*" == *"-logdir="* ]]; then
    LOGS_DIR=$(echo $* | grep -o -P '(?<=-logdir=)[^ ]+' | head -1)
fi
echo -e "Log directory set to $LOGS_DIR"
    
if [[ $* == *"-help"* ]]; then
    ./build/test/bench_conv2d -h
else
    ./build/test/bench_conv2d -q $LOGQ -N $POLYDEG -rt $SSBITLEN -usp $USP $DEV $NTT -bs 1 -ih 227 -iw 227 -ic 3 -kh 3 -kw 3 -oc 64 > $LOGS_DIR/$LOG_FNAME
    ./build/test/bench_conv2d -q $LOGQ -N $POLYDEG -rt $SSBITLEN -usp $USP $DEV $NTT -bs 1 -ih 56 -iw 56 -ic 64 -kh 1 -kw 1 -oc 16 >> $LOGS_DIR/$LOG_FNAME
    ./build/test/bench_conv2d -q $LOGQ -N $POLYDEG -rt $SSBITLEN -usp $USP $DEV $NTT -bs 1 -ih 56 -iw 56 -ic 16 -kh 1 -kw 1 -oc 64 >> $LOGS_DIR/$LOG_FNAME
    ./build/test/bench_conv2d -q $LOGQ -N $POLYDEG -rt $SSBITLEN -usp $USP $DEV $NTT -bs 1 -ih 56 -iw 56 -ic 16 -kh 3 -kw 3 -oc 64 >> $LOGS_DIR/$LOG_FNAME
    ./build/test/bench_conv2d -q $LOGQ -N $POLYDEG -rt $SSBITLEN -usp $USP $DEV $NTT -bs 1 -ih 56 -iw 56 -ic 128 -kh 1 -kw 1 -oc 16 >> $LOGS_DIR/$LOG_FNAME
    ./build/test/bench_conv2d -q $LOGQ -N $POLYDEG -rt $SSBITLEN -usp $USP $DEV $NTT -bs 1 -ih 56 -iw 56 -ic 16 -kh 1 -kw 1 -oc 64 >> $LOGS_DIR/$LOG_FNAME
    ./build/test/bench_conv2d -q $LOGQ -N $POLYDEG -rt $SSBITLEN -usp $USP $DEV $NTT -bs 1 -ih 56 -iw 56 -ic 16 -kh 3 -kw 3 -oc 64 >> $LOGS_DIR/$LOG_FNAME
    ./build/test/bench_conv2d -q $LOGQ -N $POLYDEG -rt $SSBITLEN -usp $USP $DEV $NTT -bs 1 -ih 27 -iw 27 -ic 128 -kh 1 -kw 1 -oc 32 >> $LOGS_DIR/$LOG_FNAME
    ./build/test/bench_conv2d -q $LOGQ -N $POLYDEG -rt $SSBITLEN -usp $USP $DEV $NTT -bs 1 -ih 27 -iw 27 -ic 32 -kh 1 -kw 1 -oc 128 >> $LOGS_DIR/$LOG_FNAME
    ./build/test/bench_conv2d -q $LOGQ -N $POLYDEG -rt $SSBITLEN -usp $USP $DEV $NTT -bs 1 -ih 27 -iw 27 -ic 32 -kh 3 -kw 3 -oc 128 >> $LOGS_DIR/$LOG_FNAME
    ./build/test/bench_conv2d -q $LOGQ -N $POLYDEG -rt $SSBITLEN -usp $USP $DEV $NTT -bs 1 -ih 27 -iw 27 -ic 256 -kh 1 -kw 1 -oc 32 >> $LOGS_DIR/$LOG_FNAME
    ./build/test/bench_conv2d -q $LOGQ -N $POLYDEG -rt $SSBITLEN -usp $USP $DEV $NTT -bs 1 -ih 27 -iw 27 -ic 32 -kh 1 -kw 1 -oc 128 >> $LOGS_DIR/$LOG_FNAME
    ./build/test/bench_conv2d -q $LOGQ -N $POLYDEG -rt $SSBITLEN -usp $USP $DEV $NTT -bs 1 -ih 27 -iw 27 -ic 32 -kh 3 -kw 3 -oc 128 >> $LOGS_DIR/$LOG_FNAME
    ./build/test/bench_conv2d -q $LOGQ -N $POLYDEG -rt $SSBITLEN -usp $USP $DEV $NTT -bs 1 -ih 13 -iw 13 -ic 256 -kh 1 -kw 1 -oc 48 >> $LOGS_DIR/$LOG_FNAME
    ./build/test/bench_conv2d -q $LOGQ -N $POLYDEG -rt $SSBITLEN -usp $USP $DEV $NTT -bs 1 -ih 13 -iw 13 -ic 48 -kh 1 -kw 1 -oc 192 >> $LOGS_DIR/$LOG_FNAME
    ./build/test/bench_conv2d -q $LOGQ -N $POLYDEG -rt $SSBITLEN -usp $USP $DEV $NTT -bs 1 -ih 13 -iw 13 -ic 48 -kh 3 -kw 3 -oc 192 >> $LOGS_DIR/$LOG_FNAME
    ./build/test/bench_conv2d -q $LOGQ -N $POLYDEG -rt $SSBITLEN -usp $USP $DEV $NTT -bs 1 -ih 13 -iw 13 -ic 384 -kh 1 -kw 1 -oc 48 >> $LOGS_DIR/$LOG_FNAME
    ./build/test/bench_conv2d -q $LOGQ -N $POLYDEG -rt $SSBITLEN -usp $USP $DEV $NTT -bs 1 -ih 13 -iw 13 -ic 48 -kh 1 -kw 1 -oc 192 >> $LOGS_DIR/$LOG_FNAME
    ./build/test/bench_conv2d -q $LOGQ -N $POLYDEG -rt $SSBITLEN -usp $USP $DEV $NTT -bs 1 -ih 13 -iw 13 -ic 48 -kh 3 -kw 3 -oc 192 >> $LOGS_DIR/$LOG_FNAME
    ./build/test/bench_conv2d -q $LOGQ -N $POLYDEG -rt $SSBITLEN -usp $USP $DEV $NTT -bs 1 -ih 13 -iw 13 -ic 384 -kh 1 -kw 1 -oc 64 >> $LOGS_DIR/$LOG_FNAME
    ./build/test/bench_conv2d -q $LOGQ -N $POLYDEG -rt $SSBITLEN -usp $USP $DEV $NTT -bs 1 -ih 13 -iw 13 -ic 64 -kh 1 -kw 1 -oc 256 >> $LOGS_DIR/$LOG_FNAME
    ./build/test/bench_conv2d -q $LOGQ -N $POLYDEG -rt $SSBITLEN -usp $USP $DEV $NTT -bs 1 -ih 13 -iw 13 -ic 64 -kh 3 -kw 3 -oc 256 >> $LOGS_DIR/$LOG_FNAME
    ./build/test/bench_conv2d -q $LOGQ -N $POLYDEG -rt $SSBITLEN -usp $USP $DEV $NTT -bs 1 -ih 13 -iw 13 -ic 512 -kh 1 -kw 1 -oc 64 >> $LOGS_DIR/$LOG_FNAME
    ./build/test/bench_conv2d -q $LOGQ -N $POLYDEG -rt $SSBITLEN -usp $USP $DEV $NTT -bs 1 -ih 13 -iw 13 -ic 64 -kh 1 -kw 1 -oc 256 >> $LOGS_DIR/$LOG_FNAME
    ./build/test/bench_conv2d -q $LOGQ -N $POLYDEG -rt $SSBITLEN -usp $USP $DEV $NTT -bs 1 -ih 13 -iw 13 -ic 64 -kh 3 -kw 3 -oc 256 >> $LOGS_DIR/$LOG_FNAME
    ./build/test/bench_conv2d -q $LOGQ -N $POLYDEG -rt $SSBITLEN -usp $USP $DEV $NTT -bs 1 -ih 13 -iw 13 -ic 512 -kh 1 -kw 1 -oc 1000 >> $LOGS_DIR/$LOG_FNAME
fi

echo -e "Done! Log file saved at $LOGS_DIR/$LOG_FNAME"