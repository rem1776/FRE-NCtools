FROM ubuntu:xenial
## install dependencies
RUN apt-get update \
 && apt-get -y install software-properties-common \
 && add-apt-repository ppa:remik-ziemlinski/nccmp --update \
 && apt-get install -y libnetcdf-dev netcdf-bin gfortran bats nccmp autoconf
## copy over repo
COPY . .
## run tests
ENTRYPOINT ["build.sh"]
