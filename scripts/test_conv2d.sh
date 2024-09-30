DEV=-D
NTT=""
LOG_FNAME="sqnet-conv2d"
WORK_DIR=`pwd`
LOG_DIR=$WORK_DIR/logs

mkdir -p $LOG_DIR

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

if [[ "$*" == *"-logdir="* ]]; then
    LOG_DIR=$(echo $* | grep -o -P '(?<=-logdir=)[^ ]+' | head -1)
fi
    
if [[ $* == *"-help"* ]]; then
    ./build/test/bench_conv2d -h
else
    ./build/test/bench_conv2d -q $LOGQ -N $POLYDEG -rt $SSBITLEN -usp $USP $DEV $NTT -bs 1 -ih 227 -iw 227 -ic 3 -kh 3 -kw 3 -oc 64 > $LOG_DIR/$LOG_FNAME
    ./build/test/bench_conv2d -q $LOGQ -N $POLYDEG -rt $SSBITLEN -usp $USP $DEV $NTT -bs 1 -ih 56 -iw 56 -ic 64 -kh 1 -kw 1 -oc 16 >> $LOG_DIR/$LOG_FNAME
    ./build/test/bench_conv2d -q $LOGQ -N $POLYDEG -rt $SSBITLEN -usp $USP $DEV $NTT -bs 1 -ih 56 -iw 56 -ic 16 -kh 1 -kw 1 -oc 64 >> $LOG_DIR/$LOG_FNAME
    ./build/test/bench_conv2d -q $LOGQ -N $POLYDEG -rt $SSBITLEN -usp $USP $DEV $NTT -bs 1 -ih 56 -iw 56 -ic 16 -kh 3 -kw 3 -oc 64 >> $LOG_DIR/$LOG_FNAME
    ./build/test/bench_conv2d -q $LOGQ -N $POLYDEG -rt $SSBITLEN -usp $USP $DEV $NTT -bs 1 -ih 56 -iw 56 -ic 128 -kh 1 -kw 1 -oc 16 >> $LOG_DIR/$LOG_FNAME
    ./build/test/bench_conv2d -q $LOGQ -N $POLYDEG -rt $SSBITLEN -usp $USP $DEV $NTT -bs 1 -ih 56 -iw 56 -ic 16 -kh 1 -kw 1 -oc 64 >> $LOG_DIR/$LOG_FNAME
    ./build/test/bench_conv2d -q $LOGQ -N $POLYDEG -rt $SSBITLEN -usp $USP $DEV $NTT -bs 1 -ih 56 -iw 56 -ic 16 -kh 3 -kw 3 -oc 64 >> $LOG_DIR/$LOG_FNAME
    ./build/test/bench_conv2d -q $LOGQ -N $POLYDEG -rt $SSBITLEN -usp $USP $DEV $NTT -bs 1 -ih 27 -iw 27 -ic 128 -kh 1 -kw 1 -oc 32 >> $LOG_DIR/$LOG_FNAME
    ./build/test/bench_conv2d -q $LOGQ -N $POLYDEG -rt $SSBITLEN -usp $USP $DEV $NTT -bs 1 -ih 27 -iw 27 -ic 32 -kh 1 -kw 1 -oc 128 >> $LOG_DIR/$LOG_FNAME
    ./build/test/bench_conv2d -q $LOGQ -N $POLYDEG -rt $SSBITLEN -usp $USP $DEV $NTT -bs 1 -ih 27 -iw 27 -ic 32 -kh 3 -kw 3 -oc 128 >> $LOG_DIR/$LOG_FNAME
    ./build/test/bench_conv2d -q $LOGQ -N $POLYDEG -rt $SSBITLEN -usp $USP $DEV $NTT -bs 1 -ih 27 -iw 27 -ic 256 -kh 1 -kw 1 -oc 32 >> $LOG_DIR/$LOG_FNAME
    ./build/test/bench_conv2d -q $LOGQ -N $POLYDEG -rt $SSBITLEN -usp $USP $DEV $NTT -bs 1 -ih 27 -iw 27 -ic 32 -kh 1 -kw 1 -oc 128 >> $LOG_DIR/$LOG_FNAME
    ./build/test/bench_conv2d -q $LOGQ -N $POLYDEG -rt $SSBITLEN -usp $USP $DEV $NTT -bs 1 -ih 27 -iw 27 -ic 32 -kh 3 -kw 3 -oc 128 >> $LOG_DIR/$LOG_FNAME
    ./build/test/bench_conv2d -q $LOGQ -N $POLYDEG -rt $SSBITLEN -usp $USP $DEV $NTT -bs 1 -ih 13 -iw 13 -ic 256 -kh 1 -kw 1 -oc 48 >> $LOG_DIR/$LOG_FNAME
    ./build/test/bench_conv2d -q $LOGQ -N $POLYDEG -rt $SSBITLEN -usp $USP $DEV $NTT -bs 1 -ih 13 -iw 13 -ic 48 -kh 1 -kw 1 -oc 192 >> $LOG_DIR/$LOG_FNAME
    ./build/test/bench_conv2d -q $LOGQ -N $POLYDEG -rt $SSBITLEN -usp $USP $DEV $NTT -bs 1 -ih 13 -iw 13 -ic 48 -kh 3 -kw 3 -oc 192 >> $LOG_DIR/$LOG_FNAME
    ./build/test/bench_conv2d -q $LOGQ -N $POLYDEG -rt $SSBITLEN -usp $USP $DEV $NTT -bs 1 -ih 13 -iw 13 -ic 384 -kh 1 -kw 1 -oc 48 >> $LOG_DIR/$LOG_FNAME
    ./build/test/bench_conv2d -q $LOGQ -N $POLYDEG -rt $SSBITLEN -usp $USP $DEV $NTT -bs 1 -ih 13 -iw 13 -ic 48 -kh 1 -kw 1 -oc 192 >> $LOG_DIR/$LOG_FNAME
    ./build/test/bench_conv2d -q $LOGQ -N $POLYDEG -rt $SSBITLEN -usp $USP $DEV $NTT -bs 1 -ih 13 -iw 13 -ic 48 -kh 3 -kw 3 -oc 192 >> $LOG_DIR/$LOG_FNAME
    ./build/test/bench_conv2d -q $LOGQ -N $POLYDEG -rt $SSBITLEN -usp $USP $DEV $NTT -bs 1 -ih 13 -iw 13 -ic 384 -kh 1 -kw 1 -oc 64 >> $LOG_DIR/$LOG_FNAME
    ./build/test/bench_conv2d -q $LOGQ -N $POLYDEG -rt $SSBITLEN -usp $USP $DEV $NTT -bs 1 -ih 13 -iw 13 -ic 64 -kh 1 -kw 1 -oc 256 >> $LOG_DIR/$LOG_FNAME
    ./build/test/bench_conv2d -q $LOGQ -N $POLYDEG -rt $SSBITLEN -usp $USP $DEV $NTT -bs 1 -ih 13 -iw 13 -ic 64 -kh 3 -kw 3 -oc 256 >> $LOG_DIR/$LOG_FNAME
    ./build/test/bench_conv2d -q $LOGQ -N $POLYDEG -rt $SSBITLEN -usp $USP $DEV $NTT -bs 1 -ih 13 -iw 13 -ic 512 -kh 1 -kw 1 -oc 64 >> $LOG_DIR/$LOG_FNAME
    ./build/test/bench_conv2d -q $LOGQ -N $POLYDEG -rt $SSBITLEN -usp $USP $DEV $NTT -bs 1 -ih 13 -iw 13 -ic 64 -kh 1 -kw 1 -oc 256 >> $LOG_DIR/$LOG_FNAME
    ./build/test/bench_conv2d -q $LOGQ -N $POLYDEG -rt $SSBITLEN -usp $USP $DEV $NTT -bs 1 -ih 13 -iw 13 -ic 64 -kh 3 -kw 3 -oc 256 >> $LOG_DIR/$LOG_FNAME
    ./build/test/bench_conv2d -q $LOGQ -N $POLYDEG -rt $SSBITLEN -usp $USP $DEV $NTT -bs 1 -ih 13 -iw 13 -ic 512 -kh 1 -kw 1 -oc 1000 >> $LOG_DIR/$LOG_FNAME
fi

echo -e "Done! Log file saved at $LOG_DIR/$LOG_FNAME"