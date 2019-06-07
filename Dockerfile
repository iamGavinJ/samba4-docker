FROM alpine:edge as build
ARG SMB_VERSION
ENV SMB_VERSION ${UB_VERSION:-4.10.4}

ENV WORKDIR /root
ENV BUILDDIR ${WORKDIR}/build
ENV DESTDIR /opt

WORKDIR ${WORKDIR}
RUN \
    printf "**** setup build environment ****\n" && \
    mkdir -p "${BUILDDIR}" && \
    sed -i -- 's/dl-cdn.alpinelinux.org/mirrors.gigenet.com/g' /etc/apk/repositories && \
    sed -i -- 's/alpine/alpinelinux/g' /etc/apk/repositories && \
    apk update && \
    apk upgrade && \
    apk add --update --force-refresh --no-cache \
        man \
        man-pages \
        curl \
        tzdata && \
    ln -s /usr/share/zoneinfo/America/Los_Angeles /etc/localtime && \
    apk add --update --force-refresh --no-cache \
        gcc \
        python3-dev \
        perl \
        perl-dev \
        \
        musl-dev \
        acl-dev \
        attr-dev \
        libaio-dev \
        libcap-dev \
        jansson-dev \
        libarchive-dev \
        linux-pam-dev \
        libbsd-dev \
        bison \
        flex-dev \
        rpcgen \
        talloc-dev \
        tevent-dev && \
    apk add  --update --force-refresh --no-cache \
        --repository http://mirrors.gigenet.com/alpinelinux/edge/testing/ --update-cache \
        tracker-dev

RUN \
    printf "**** extract source ****\n" && \
    curl -L -o - --url https://download.samba.org/pub/samba/stable/samba-${SMB_VERSION}.tar.gz | tar x -vz --strip-components=1 -f - -C "${BUILDDIR}"

COPY [ "netdb.h.diff", "${WORKDIR}/" ]

RUN \
    printf "**** build ****\n" && \
    patch -Np0 -i *.diff && \
    export PATH=${BUILDDIR}/buildtools/bin:$PATH && \
    cd ${BUILDDIR} && \
    waf configure -j 4 \
        --prefix=${DESTDIR} \
        --destdir=/ \
        --without-gettext \
        --without-systemd \
        --without-ldap \
        --without-ads \
        --without-ad-dc \
        --accel-aes=intelaesni \
        --enable-spotlight \
        --bundled-libraries=!tevent && \
    waf build -j 4 && \
    waf install -j 4 \
        --prefix=${DESTDIR} \
        --destdir=/

RUN \
    echo "*** tar ***" && \
    tar -vczf "${WORKDIR}/install.tar.gz" -C "${DESTDIR}" .
