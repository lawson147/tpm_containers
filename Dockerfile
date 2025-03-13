FROM ubuntu:20.04

# 安装依赖
RUN apt-get update && apt-get install -y \
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
RUN useradd --system --user-group tss && \
    wget https://github.com/tpm2-software/tpm2-tss/releases/download/2.1.0/tpm2-tss-2.1.0.tar.gz && \
    tar zxvf tpm2-tss-2.1.0.tar.gz && \
    cd tpm2-tss-2.1.0 && \
    ./configure --enable-unit && \
    make && \
    make install && \
    ldconfig

RUN wget https://github.com/tpm2-software/tpm2-abrmd/releases/download/2.0.2/tpm2-abrmd-2.0.2.tar.gz && \
    tar zxvf tpm2-abrmd-2.0.2.tar.gz && \
    cd tpm2-abrmd-2.0.2 && \
    ./configure --with-dbuspolicydir=/etc/dbus-1/system.d --with-systemdsystemunitdir=/lib/systemd/system && \
    make && \
    make install

# 配置服务
RUN cp /usr/local/share/dbus-1/system-services/com.intel.tss2.Tabrmd.service /usr/share/dbus-1/system-services/ && \
    pkill -HUP dbus-daemon

# 启动TPM模拟器和tabrmd
CMD ["/usr/local/bin/tpm_server", "&", "/usr/local/sbin/tpm2-abrmd", "--tcti=libtss2-tcti-mssim.so.0:host=127.0.0.1,port=2321"]
