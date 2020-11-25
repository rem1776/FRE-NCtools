#!/bin/bash
#Builds FRE-NCtools and runs regression tests for CI
autoreconf -i configure.ac
./configure $MPI --enable-lfs-tests
make -j check LOG_DRIVER_FLAGS=--comments
