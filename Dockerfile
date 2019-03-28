FROM alpine as build
ARG SMB_VERSION
ENV SMB_VERSION ${SMB_VERSION:-4.10.0}

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

FROM alpine
ENV WORKDIR /root
ENV PIDDIR "/var/run/unbound"
WORKDIR ${WORKDIR}
COPY --from=build [ "${WORKDIR}/install.tar.gz", "${WORKDIR}/" ]
COPY [ "docker-entrypoint.sh", "/usr/local/bin/" ]
CMD ["postgres"]
RUN \
    echo "***********************" && \
    tar -vxf "${WORKDIR}/install.tar.gz" -C "/" && \
    rm -f "${WORKDIR}/install.tar.gz" && \
    ln -s "/usr/local/bin/docker-entrypoint.sh" "/" && \
    chmod 555 "/usr/local/bin/docker-entrypoint.sh" && \
    chmod 555 "/docker-entrypoint.sh" && \
    apk update && \
    apk upgrade && \
    apk add --update \
        libevent && \
    addgroup -g 9999 unbound && \
    adduser -u 9999 -g "" -G unbound -s /sbin/nologin -DH unbound && \
    mkdir -p "${PIDDIR}" && \
    chmod -R 775 "${PIDDIR}" && \
    chown -R 9999:9999 "${PIDDIR}"

LABEL maintainer="docker@scurr.me"
LABEL version=${UB_VERSION}

EXPOSE 53/tcp 53/udp
VOLUME [ "/usr/local/etc/unbound", "/var/log/unbound" ]
ENTRYPOINT ["/docker-entrypoint.sh"]
#ENTRYPOINT ["/usr/local/sbin/unbound", "-vd"]
CMD ["/usr/local/sbin/unbound", "-vd"]
#CMD ["unbound.conf"]
HEALTHCHECK --interval=3s --retries=3 --start-period=3s --timeout=3s \
    CMD grep "Name:" /proc/$(cat /var/run/unbound/unbound.pid 2>/dev/null || echo 0)/status 2>/dev/null | grep -sqi unbound && (nslookup a.root-servers.net localhost &> /dev/null || return 1) || return 1
