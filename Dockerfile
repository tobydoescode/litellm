# ARM64 build of LiteLLM
# Source: https://github.com/BerriAI/litellm
FROM python:3.14-slim-bookworm

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libc6-dev \
    libpq-dev \
    libsndfile1 \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir uv

COPY requirements.txt requirements-override.txt ./
RUN uv pip install --system --no-cache --override requirements-override.txt -r requirements.txt

COPY generate_prisma.py .
RUN python generate_prisma.py && rm generate_prisma.py

EXPOSE 4000

ENTRYPOINT ["litellm"]
CMD ["--port", "4000"]
