FROM ubuntu:xenial
## install dependencies
RUN apt-get -y install software-properties-common
RUN add-apt-repository ppa:remik-ziemlinski/nccmp --update
RUN apt-get install -y libnetcdf-dev libnetcdff-dev netcdf-bin libopenmpi-dev openmpi-bin bats nccmp
## copy over repo
COPY . /FRE-NCtools
## run tests
ENTRYPOINT ["/build.sh"]
