FROM debian:trixie-slim

# Evita perguntas durante a instalação
ENV DEBIAN_FRONTEND=noninteractive

# Instalação das ferramentas necessárias
RUN apt-get update && apt-get install -y \
    live-build \
    live-config \
    git \
    curl \
    ca-certificates \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Cria um diretório de trabalho
WORKDIR /work

# O live-build exige root para muitas operações, mas 
# este ponto de entrada facilita a execução posterior.
CMD ["/bin/bash"]