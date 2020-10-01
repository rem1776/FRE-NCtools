FROM ubuntu:xenial

COPY build.sh /build.sh

ENTRYPOINT ["/build.sh"]
