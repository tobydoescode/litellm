# ARM64 build of LiteLLM
# Source: https://github.com/BerriAI/litellm
FROM python:3.13-slim-bookworm

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libpq-dev \
    libsndfile1 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=ghcr.io/astral-sh/uv:0.9 /uv /usr/local/bin/uv

COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev --no-install-project

COPY generate_prisma.py .
RUN uv run python generate_prisma.py && rm generate_prisma.py

ENV PATH="/app/.venv/bin:$PATH"
EXPOSE 4000

ENTRYPOINT ["litellm"]
CMD ["--port", "4000"]
