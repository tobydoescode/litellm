# ARM64 build of LiteLLM
# Source: https://github.com/BerriAI/litellm
# Build: docker buildx build --platform linux/arm64 -t ghcr.io/<owner>/litellm:v1.82.3 --push .
ARG LITELLM_VERSION=1.82.3

FROM python:3.11-slim-bookworm

ARG LITELLM_VERSION

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libpq-dev \
    libsndfile1 \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir "litellm[proxy]==${LITELLM_VERSION}"

EXPOSE 4000

ENTRYPOINT ["litellm"]
CMD ["--port", "4000"]
