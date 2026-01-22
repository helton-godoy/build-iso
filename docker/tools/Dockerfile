# checkov:skip=CKV_DOCKER_3:Live-build requires root privileges to operate
FROM debian:trixie-slim

# Evita perguntas durante a instalação
ENV DEBIAN_FRONTEND=noninteractive

# Configurar locale pt_BR.UTF-8
ENV LANG=pt_BR.UTF-8
ENV LC_ALL=pt_BR.UTF-8
ENV LANGUAGE=pt_BR:pt:en

# Instalação das ferramentas necessárias + locale
# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends \
    live-build \
    live-config \
    git \
    curl \
    ca-certificates \
    locales \
    && rm -rf /var/lib/apt/lists/* \
    && sed -i 's/# pt_BR.UTF-8 UTF-8/pt_BR.UTF-8 UTF-8/' /etc/locale.gen \
    && locale-gen pt_BR.UTF-8

# Cria um diretório de trabalho
WORKDIR /work

# Healthcheck básico
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD test -x /usr/bin/lb || exit 1

CMD ["/bin/bash"]