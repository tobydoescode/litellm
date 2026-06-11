# Multi-arch build of LiteLLM
# Source: https://github.com/BerriAI/litellm
FROM python:3.13-slim-bookworm@sha256:9f4de3ee03d58c34b21ee3cf29c3cda61a5bb396cbfd9c5c056205532d391936 AS builder

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libpq-dev \
    libsndfile1 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=ghcr.io/astral-sh/uv:0.9@sha256:538e0b39736e7feae937a65983e49d2ab75e1559d35041f9878b7b7e51de91e4 /uv /usr/local/bin/uv

COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev --no-install-project

COPY generate_prisma.py .
RUN uv run python generate_prisma.py && rm generate_prisma.py

FROM python:3.13-slim-bookworm@sha256:9f4de3ee03d58c34b21ee3cf29c3cda61a5bb396cbfd9c5c056205532d391936 AS runtime

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    libatomic1 \
    libpq5 \
    libsndfile1 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/.venv /app/.venv
COPY --from=builder /root/.cache/prisma-python /root/.cache/prisma-python

ENV PATH="/app/.venv/bin:$PATH"
EXPOSE 4000

ENTRYPOINT ["litellm"]
CMD ["--port", "4000"]
