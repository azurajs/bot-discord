FROM docker.io/elixir:1.19

ENV DEBIAN_FRONTEND=noninteractive

WORKDIR /app

# ------------------------------------
# Instalar dependências básicas
# ------------------------------------
RUN apt-get update && \
    apt-get install -y build-essential git && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# ------------------------------------
# Instalar Hex e Rebar como root
# ------------------------------------
RUN mix local.hex --force && \
    mix local.rebar --force

# ------------------------------------
# Copiar arquivos do projeto
# ------------------------------------
COPY mix.exs mix.lock ./
COPY config ./config
COPY lib ./lib
COPY .env .env

# ------------------------------------
# Baixar e compilar dependências como root
# ------------------------------------
RUN mix deps.get && \
    mix deps.compile && \
    mix compile

# ------------------------------------
# Copiar Hex para local acessível
# ------------------------------------
RUN mkdir -p /app/.mix && \
    cp -r /root/.mix/* /app/.mix/ && \
    chown -R 1000:1000 /app

# ------------------------------------
# Mudar para usuário 1000:1000
# ------------------------------------
USER 1000:1000

# ------------------------------------
# Configurar variáveis de ambiente
# ------------------------------------
ENV HOME=/tmp
ENV MIX_HOME=/app/.mix
ENV ERL_FLAGS="+S 1:1 +A 4 +Bi"

# ------------------------------------
# Start Bot
# ------------------------------------
CMD ["mix", "run", "--no-halt"]
