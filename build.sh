#!/bin/bash

#install dependencies
sudo add-apt-repository ppa:remik-ziemlinski/nccmp --update
sudo apt-get install -y libnetcdf-dev libnetcdff-dev netcdf-bin libopenmpi-dev openmpi-bin bats nccmp
#build and test
autoreconf -i configure.ac
./configure $MPI
make -j check LOG_DRIVER_FLAGS=--comments
