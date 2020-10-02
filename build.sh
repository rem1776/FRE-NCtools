#!/bin/bash

#install dependencies
add-apt-repository ppa:remik-ziemlinski/nccmp --update
apt-get install -y libnetcdf-dev libnetcdff-dev netcdf-bin libopenmpi-dev openmpi-bin bats nccmp
#build and test
autoreconf -i configure.ac
./configure $MPI
make -j check LOG_DRIVER_FLAGS=--comments
