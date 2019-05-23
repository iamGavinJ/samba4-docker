FROM alpine:edge as build
ARG SMB_VERSION
ENV SMB_VERSION ${SMB_VERSION:-4.10.3}

ENV WORKDIR /root
ENV BUILDDIR ${WORKDIR}/build
ENV DESTDIR /opt
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
        \
        musl-dev \
        acl-dev \
        attr-dev \
        krb5-dev \
        libaio-dev \
        libcap-dev \
        cyrus-sasl-dev \
        linux-pam-dev \
        zlib-dev \
        libtirpc-dev \
        libnsl-dev \
        valgrind-dev \
        readline-dev \
        \
        libbsd-dev \
        \
        perl \
        perl-dev \
        \
        cmocka-dev \
        libxslt-dev \
        popt-dev \
        docbook-xsl \
        talloc-dev \
        tevent-dev \
        py3-tevent \
        \
        lmdb-dev \
        \
        gnutls-dev \
        libgcrypt-dev \
        gpgme-dev \
        \
        libexecinfo-dev \
        libunwind-dev \
        lttng-ust-dev \
        jansson-dev \
        gnu-libiconv-dev \
        \
        gamin-dev \
        libarchive-dev \
        avahi-dev \
        cups-dev \
        ncurses-dev \
        \
        rpcgen \
        && \
    ln -s /usr/share/zoneinfo/America/Los_Angeles /etc/localtime

RUN \ 
    echo "**** extract source ****" && \
    mkdir -p "${BUILDDIR}" && \
    curl -L -o - --url https://download.samba.org/pub/samba/stable/samba-${SMB_VERSION}.tar.gz | tar x -vz --strip-components=1 -f - -C "${BUILDDIR}"

RUN \ 
    echo "**** configure source ****" && \
    cd "${BUILDDIR}" && \
    ./configure CPPFLAGS="-I/usr/include/tirpc/" \
        --without-systemd \
        --without-ldap \
        --without-ads \
        --accel-aes=intelaesni \
        --prefix="${DESTDIR}" 

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

