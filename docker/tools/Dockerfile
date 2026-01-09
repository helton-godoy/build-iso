# checkov:skip=CKV_DOCKER_3:Live-build requires root privileges to operate
FROM debian:trixie-slim

# Evita perguntas durante a instalação
ENV DEBIAN_FRONTEND=noninteractive

# Instalação das ferramentas necessárias
# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends \
    live-build \
    live-config \
    git \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*



# Cria um diretório de trabalho
WORKDIR /work

# Healthcheck básico
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD test -x /usr/bin/lb || exit 1


CMD ["/bin/bash"]