ARG ELIXIR_VERSION=1.18.4
ARG OTP_VERSION=28.0.2
ARG DISTRO=ubuntu-noble-20250714

ARG IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-${DISTRO}"

FROM ${IMAGE}

RUN apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates \
  git \
  postgresql-client-16 \
  libpq-dev \
  sqlite3

WORKDIR /workspace/drops-relation

COPY mix.exs mix.lock ./

RUN mix local.hex --force && \
  mix local.rebar --force
