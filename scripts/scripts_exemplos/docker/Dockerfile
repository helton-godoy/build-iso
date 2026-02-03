FROM debian:trixie-slim
ENV DEBIAN_FRONTEND=noninteractive

# 1. Fluxo Único de Provisionamento (Repositórios -> Instalação -> Locales -> Limpeza)
RUN echo "deb http://ftp.br.debian.org/debian trixie main contrib non-free non-free-firmware" > /etc/apt/sources.list && \
    apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl gpg rsync wget && \
    mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://repo.charm.sh/apt/gpg.key | gpg --dearmor -o /etc/apt/keyrings/charm.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | tee /etc/apt/sources.list.d/charm.list && \
    apt-get update && apt-get install -y --no-install-recommends \
    live-build debootstrap squashfs-tools xorriso isolinux \
    syslinux-common grub-efi-amd64-bin grub-pc-bin mtools \
    dosfstools zstd build-essential dkms linux-headers-amd64 \
    locales zfsutils-linux gum && \
    echo "pt_BR.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen pt_BR.UTF-8 && \
    update-locale LANG=pt_BR.UTF-8 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ENV LANG=pt_BR.UTF-8
ENV LC_ALL=pt_BR.UTF-8

WORKDIR /project
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
