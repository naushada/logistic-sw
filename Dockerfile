# get and configure an image
FROM ubuntu:focal
ENV TZ=Asia/Calcutta
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get -y upgrade
RUN apt-get install -y --no-install-recommends \
    ca-cacert \
    cmake \
    build-essential \
    libboost-all-dev \
    libssl-dev \
    wget \
    zlib1g-dev

################## Webgui section ###############################

FROM node:latest AS gui-build
RUN cd /root
RUN mkdir webgui && cd webgui
RUN mkdir webclient && cd webclient
WORKDIR /root/webgui/webclient
RUN git clone https://github.com/naushada/bayt.git
RUN cd bayt/sw
RUN cp -r /root/webgui/webclient/bayt/sw/node_modules/primeng /tmp
RUN cp -r /root/webgui/webclient/bayt/sw/node_modules/primeicons /tmp
RUN cp -r /root/webgui/webclient/bayt/sw/node_modules/ngx-draggable-resize /tmp


##########3 installing dependencies node_module ######################

RUN apt-get -y update
RUN apt-get -y upgrade
RUN apt-get -y install nodejs npm
WORKDIR /root/webgui/webclient/bayt/sw
RUN npm install

######## copy some packages from local to container ##############################

RUN cp -r /tmp/primeng /root/webgui/webclient/bayt/sw/node_modules/
RUN cp -r /tmp/primeicons /root/webgui/webclient/bayt/sw/node_modules/
RUN cp -r /tmp/ngx-draggable-resize /root/webgui/webclient/bayt/sw/node_modules/

##### Compile the Angular webgui #################
RUN npm install -g @angular/cli

WORKDIR /root/webgui/webclient/bayt/sw
RUN ng build --configuration production --aot --base-href /bayt/

# get and build ACE
WORKDIR /root
RUN wget https://github.com/DOCGroup/ACE_TAO/releases/download/ACE%2BTAO-7_0_0/ACE+TAO-7.0.0.tar.gz
RUN tar -xzvf ACE+TAO-7.0.0.tar.gz
ENV ACE_SRC=/root/ACE_wrappers ACE_PREFIX=/usr/local/ACE_TAO-7.0.0
RUN echo '#include "ace/config-linux.h"' > ACE_wrappers/ace/config.h
RUN echo 'include $(ACE_SRC)/include/makeinclude/platform_linux.GNU' > $ACE_SRC/include/makeinclude/platform_macros.GNU
WORKDIR /root/ACE_wrappers
RUN make install INSTALL_PREFIX=${ACE_PREFIX} ACE_ROOT=${ACE_SRC}
RUN ldconfig

RUN apt-get -y install libboost-all-dev
RUN apt-get -y install libbson-dev
RUN apt-get -y install libzstd-dev

RUN apt-get -y install git
WORKDIR /root/mongo-c
RUN apt-get -y install mongodb-server-core
RUN git clone -b r1.19 https://github.com/mongodb/mongo-c-driver.git
RUN cd mongo-c-driver
WORKDIR /root/mongo-c/mongo-c-driver/build
RUN cmake ..
RUN make && make install

# For mongo-cxx-driver - cpp driver to interface with mongo DB
WORKDIR /root/mongo-cxx
RUN git clone -b releases/v3.4 https://github.com/mongodb/mongo-cxx-driver.git
RUN cd mongo-cxx-driver

WORKDIR /root/mongo-cxx/mongo-cxx-driver/build
RUN cmake ..  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local
RUN make && make install
RUN ldconfig

# Granada Engine - A microservice that interface to mongo-cxx DB
WORKDIR /root
RUN git clone https://github.com/naushada/granada.git
RUN cd granada
RUN mkdir ix86_64
WORKDIR /root/granada/ix86_64
RUN cmake .. && make

RUN cd ../ && mkdir webgui && cd webgui && mkdir webclient && cd webclient
COPY --from=gui-build /root/webgui/webclient/bayt/sw/dist/sw .

WORKDIR /root/granada/ix86_64
CMD ./uniservice
