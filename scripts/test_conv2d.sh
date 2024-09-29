DEV=-D
NTT=""

if [[ $* == *"-cpu"* ]]; then
    DEV="-H"
fi

if [[ $* == *"-ntt"* ]]; then
    NTT="--ntt"
fi

if [[ $* == *"-help"* ]]; then
    ./build/test/bench_conv2d -h
else
    ./build/test/bench_conv2d $DEV $NTT -bs 1 -ih 56 -iw 56 -ic 16 -kh 3 -kw 3 -oc 64 -q "60,49" -N 4096 -rt 32 -usp 1
fi