FROM ubuntu
MAINTAINER syu_cream
WORKDIR /opt

#
# Prepare build environment
#
RUN apt-get -y update
RUN apt-get install -y       \
            git              \
            build-essential  \
            autoconf         \
            automake         \
            autotools-dev    \
            libtool          \
            pkg-config

#
# Install nginx to test trafficserver's HTTP/2 proxy features
#
RUN apt-get install -y nginx

#
# Install packages required by trafficserver
#
RUN apt-get install -y             \
            libmodule-install-perl \
            g++                    \
            libssl-dev             \
            tcl-dev                \
            expat                  \
            libexpat-dev           \
            libpcre3-dev

RUN ldconfig


#
# Prepare HTTP server as origin server of trafficserver
#
RUN mkdir /opt/htdocs
RUN echo "TEST" > /opt/htdocs/index.html

#
# Build and install latest opnessl
#
RUN git clone https://github.com/openssl/openssl.git
RUN cd openssl &&                                              \
    git checkout -b OpenSSL_1_0_2h refs/tags/OpenSSL_1_0_2h && \
    ./config &&                                                \
    make &&                                                    \
    make install

#
# Build and install trafficserver
#
RUN git clone https://github.com/apache/trafficserver.git
RUN cd trafficserver &&                                              \
    autoreconf -if &&                                                \
    ./configure --enable-debug --enable-cppapi &&                    \
    make &&                                                          \
    make install

RUN ldconfig

#
# Configure trafficserver as proxy server of nginx
#
RUN echo "map / http://127.0.0.1/" >> /usr/local/etc/trafficserver/remap.config
RUN openssl genrsa 2048 > server.key &&                                           \
    yes "" | openssl req -new -key server.key > server.csr &&                     \
    openssl x509 -days 3650 -req -signkey server.key < server.csr > server.crt && \
    cp server.crt /usr/local/etc/trafficserver/ &&                                \
    cp server.key /usr/local/etc/trafficserver/
RUN echo "CONFIG proxy.config.http.server_ports STRING 8080 443:ssl" >> /usr/local/etc/trafficserver/records.config
RUN echo "dest_ip=* ssl_cert_name=server.crt ssl_key_name=server.key" >> /usr/local/etc/trafficserver/ssl_multicert.config
