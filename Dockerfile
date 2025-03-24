FROM ubuntu:20.04

VOLUME ["/sys/fs/cgroup"]
# 安装依赖
RUN apt-get update

RUN apt-get install tzdata
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN apt-get install -y \
    apt-utils \ 
    wget \
    make \
    gcc \
    libssl-dev \
    libglib2.0-dev \
    pkg-config \
    libdbus-1-dev \
    dbus-x11 \
    libcmocka-dev \
    uthash-dev

# 安装TPM模拟器
RUN mkdir -p /opt/ibmtpm && \
    cd /opt/ibmtpm && \
    wget https://jaist.dl.sourceforge.net/project/ibmswtpm2/ibmtpm1332.tar.gz && \
    tar zxvf ibmtpm1332.tar.gz && \
    cd src && \
    make && \
    cp tpm_server /usr/local/bin/

# 安装tpm2-tss和tpm2-abrmd
RUN apt-get install -y libgcrypt-dev libjson-c-dev libcurl4-openssl-dev

ENV http_proxy="192.168.63.1:7890"
ENV https_proxy="192.168.63.1:7890"

RUN useradd --system --user-group tss && \
    wget https://github.com/tpm2-software/tpm2-tss/releases/download/4.1.3/tpm2-tss-4.1.3.tar.gz && \
    tar zxvf tpm2-tss-4.1.3.tar.gz && \
    cd tpm2-tss-4.1.3 && \
    ./configure --enable-unit && \
    make && \
    make install && \
    ldconfig

RUN apt-get install -y libglib2.0-dev
# RUN gdbus-codegen -v && echo $PATH
# RUN apt-get install -y iputils-ping && ping 192.168.63.1
    
RUN wget https://github.com/tpm2-software/tpm2-abrmd/releases/download/3.0.0/tpm2-abrmd-3.0.0.tar.gz && \
    tar zxvf tpm2-abrmd-3.0.0.tar.gz && \
    cd tpm2-abrmd-3.0.0 && \
    ./configure --with-dbuspolicydir=/etc/dbus-1/system.d --with-systemdsystemunitdir=/lib/systemd/system && \
    make && \
    make install

# 配置服务
ENV http_proxy=""
ENV https_proxy=""

ENV container docker
VOLUME [ "/sys/fs/cgroup", "/tmp", "/run", "/var" ]

RUN apt-get install -y vim systemd
RUN sed -i '3s/.*/Exec=\/usr\/local\/sbin\/tpm2-abrmd/' /usr/local/share/dbus-1/system-services/com.intel.tss2.Tabrmd.service

# RUN touch /var/run/dbus/system_bus_socket
RUN cp /usr/local/share/dbus-1/system-services/com.intel.tss2.Tabrmd.service /usr/share/dbus-1/system-services/

# RUN dbus-daemon --config-file=/usr/share/dbus-1/system.conf --print-address

# pkill -HUP dbus-daemon

# # 启动TPM模拟器和tabrmd
# CMD ["/usr/local/bin/tpm_server", "&", "/usr/local/sbin/tpm2-abrmd", "--tcti=libtss2-tcti-mssim.so.0:host=127.0.0.1,port=2321"]
# CMD ["/usr/sbin/init"]


ENV container docker
ENV LC_ALL C
ENV DEBIAN_FRONTEND noninteractive

RUN sed -i 's/# deb/deb/g' /etc/apt/sources.list

RUN apt-get install -y systemd

RUN (cd /lib/systemd/system/sysinit.target.wants/; for i in *; do [ $i == systemd-tmpfiles-setup.service ] || rm -f $i; done); \
    rm -f /lib/systemd/system/multi-user.target.wants/*; \
    rm -f /etc/systemd/system/*.wants/*; \
    rm -f /lib/systemd/system/local-fs.target.wants/*; \
    rm -f /lib/systemd/system/sockets.target.wants/*udev*; \
    rm -f /lib/systemd/system/sockets.target.wants/*initctl*; \
    rm -f /lib/systemd/system/basic.target.wants/*; \
    rm -f /lib/systemd/system/anaconda.target.wants/*; \
    rm -f /lib/systemd/system/plymouth*; \
    rm -f /lib/systemd/system/systemd-update-utmp*; \
    rm -rf /var/lib/apt/lists/*; \
    rm -rf /tmp/*; \
    rm -rf /var/tmp/*; \
    apt-get clean packages; \
    apt-get clean all; \
    apt-get autoremove -y

# CMD ["/lib/systemd/systemd"]
COPY tpm-server.service  /lib/systemd/system/
COPY tpm-server /etc/init.d/
CMD ["/sbin/init"]