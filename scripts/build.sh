# This script is used to build the project
# Author: Shashank Balla

#!/bin/bash

WORK_DIR=`pwd`
BUILD_DIR=$WORK_DIR/build
N_JOBS=64
BUILD_MODE=Release



mkdir -p $BUILD_DIR

if [[ "$*" == *"-clean"* ]]; then
    rm -rf $BUILD_DIR
    mkdir $BUILD_DIR
fi

cd $BUILD_DIR

if [[ "$*" == *"-debug"* ]]; then
    BUILD_MODE=Debug
fi

cmake .. -DCMAKE_BUILD_TYPE=$BUILD_MODE -DCMAKE_INSTALL_PREFIX=$BUILD_DIR -DCMAKE_PREFIX_PATH=$BUILD_DIR -DCMAKE_CUDA_ARCHITECTURES=86 \
    -DTROY_PYBIND=OFF -DTROY_TEST=ON -DTROY_BENCH=ON -DTROY_EXAMPLES=ON
make -j$N_JOBS

if [[ "$*" == *"-install"* ]]; then
    make install -j$N_JOBS
fi

if [[ "$*" == *"-test"* ]] || [[ "$*" == *"--run_tests"* ]]; then
    cd test
    ctest
    cd ..
fi

if [[ "$*" == *"-bench"* ]] || [[ "$*" == *"--run_benchmarks"* ]]; then
    cd test
    ./troybench
    cd ..
fi