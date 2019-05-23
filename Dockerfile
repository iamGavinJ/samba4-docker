FROM alpine as build
ARG SMB_VERSION
ENV SMB_VERSION ${SMB_VERSION:-4.10.3}

ENV WORKDIR /root
ENV BUILDDIR ${WORKDIR}/build
ENV DESTDIR ${WORKDIR}/install
#ENV PIDDIR "/var/run/unbound"

WORKDIR ${WORKDIR}
RUN \
    echo "**** install packages ****" && \
    apk update && \
    apk upgrade && \
    apk add --update --force-refresh --no-cache \
        curl \
        tzdata \
        build-base \
        python3-dev \
        py3-distutils-extra \
        perl \
        perl-dev \
        attr-dev \
        acl-dev \
        ncurses-dev \
        gnutls \
        libtirpc-dev \
        jansson-dev \
        libarchive-dev \
        binutils-dev \
        rpcgen && \
    ln -s /usr/share/zoneinfo/America/Los_Angeles /etc/localtime

RUN \ 
    echo "**** extract source ****" && \
    mkdir -p "${BUILDDIR}" && \
    curl -L -o - --url https://download.samba.org/pub/samba/stable/samba-${SMB_VERSION}.tar.gz | tar x -vz --strip-components=1 -f - -C "${BUILDDIR}"

RUN \ 
    echo "**** configure source ****" && \
    cd "${BUILDDIR}" && \
    ./configure \
        --prefix="${DESTDIR}" \
        --enable-gnutls \
        --with-static-modules=ALL \
        --without-winbind \
        --without-ads \
        --without-ldap \
        --disable-cups \
        --disable-iprint \
        --without-quotas \
        --without-fake-kaserver \
        --disable-glusterfs \
        --disable-cephfs \
        --without-systemd \
        --accel-aes=intelaesni \
        --without-ad-dc \
        --without-ntvfs-fileserver \
        --with-json \
        --without-pam \
        --disable-python

COPY [ "wscript.patch", "netdb.h.patch", "${WORKDIR}/" ]

RUN \
    echo "**** make install ****" && \
    mkdir -p "${DESTDIR}" && \
    patch "${BUILDDIR}/lib/ldb/wscript" "${WORKDIR}/wscript.patch" && \
    patch "/usr/include/netdb.h" "${WORKDIR}/netdb.h.patch" && \
    cd "${BUILDDIR}" && \
    make && \
    make install

RUN \
    echo "*** tar ***" && \
    tar -vczf "${WORKDIR}/install.tar.gz" -C "${DESTDIR}" .

