# Ubuntu 24.04 + public gsm (seiscomp + world-minimal). User sysop.
# gsm is the only install path. Pin SEISCOMP_VERSION for replayable builds.

FROM ubuntu:24.04

ARG SEISCOMP_VERSION=7.3.1
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      gnupg \
      mariadb-client \
      python3 \
      python3-cryptography \
      python3-requests \
      python3-venv \
      wget \
 && rm -rf /var/lib/apt/lists/*

# ubuntu:24.04 already has uid 1000 (user ubuntu). Replace with sysop.
RUN userdel -r ubuntu \
 && groupadd -g 1000 sysop \
 && useradd -m -u 1000 -g sysop -s /bin/bash sysop

USER sysop
WORKDIR /home/sysop
ENV HOME=/home/sysop

RUN mkdir -p /home/sysop/install /home/sysop/data \
 && wget -q -O /tmp/gempa-gsm.tar.gz \
      https://data.gempa.de/packages/Public/gsm/gempa-gsm.tar.gz \
 && tar xzf /tmp/gempa-gsm.tar.gz -C /home/sysop/install \
 && rm /tmp/gempa-gsm.tar.gz \
 && cd /home/sysop/install/gsm \
 && ./gsm setup -y -r 7 --os ubuntu --osversion 24.04 --arch x86_64 \
      --installpath /home/sysop/seiscomp --datadir /home/sysop/data \
 && ./gsm update \
 && ./gsm install -y "seiscomp=${SEISCOMP_VERSION}" world-minimal

USER root
# install-deps uses apt/apt-get without -y; lists were cleared in the previous layer
RUN apt-get update \
 && find /home/sysop/seiscomp/share/deps -name 'install-*.sh' -print0 \
      | xargs -0 sed -i \
        -e 's/apt-get install/apt-get install -y/g' \
        -e 's/apt install/apt-get install -y/g' \
 && bash -lc '. /home/sysop/seiscomp/share/deps/ubuntu/24.04/install-base.sh' \
 && bash -lc '. /home/sysop/seiscomp/share/deps/ubuntu/24.04/install-fdsnws.sh' \
 && rm -rf /var/lib/apt/lists/*

COPY --chown=sysop:sysop config/compose/global.cfg /home/sysop/seiscomp/etc/global.cfg
COPY --chown=sysop:sysop config/compose/scmaster.cfg /home/sysop/seiscomp/etc/scmaster.cfg
COPY --chown=sysop:sysop config/slarchive.cfg /home/sysop/seiscomp/etc/slarchive.cfg
COPY --chown=sysop:sysop config/compose/fdsnws.cfg /home/sysop/seiscomp/etc/fdsnws.cfg
COPY --chown=sysop:sysop config/key/ /home/sysop/seiscomp/etc/key/
COPY docker/entrypoint.sh /entrypoint.sh
COPY docker/import-inventory.sh docker/run-seedlink.sh docker/run-slarchive.sh /docker/

RUN chmod 0755 /entrypoint.sh /docker/*.sh

USER sysop
ENV SEISCOMP_ROOT=/home/sysop/seiscomp
ENV PATH=/home/sysop/seiscomp/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV LD_LIBRARY_PATH=/home/sysop/seiscomp/lib

EXPOSE 18180 18000
ENTRYPOINT ["/entrypoint.sh"]
CMD ["seiscomp", "exec", "scmaster", "--console", "1"]
