# LiteLLM

Multi-arch Docker image of [LiteLLM](https://github.com/BerriAI/litellm) built
for the home-lab k3s cluster. Exists because upstream does not publish ARM64
images, and the cluster is mixed amd64/arm64.

## Build pipeline

`.github/workflows/build-image.yaml` builds `linux/amd64` and `linux/arm64` in
parallel on GitHub-hosted runners and publishes a single multi-arch manifest
list to `ghcr.io/tobydoescode/litellm`. Tags: `latest` (default branch),
`sha-<sha>`, and semver from `v*` tags.

`pyproject.toml` holds the top-level pins (litellm, prisma). `uv.lock` is the
fully resolved lockfile — the Dockerfile runs `uv sync --frozen` against it so
builds are reproducible. Regenerate with `task lock` after editing
`pyproject.toml`.

## Local development

`task lock` needs `uv` installed locally; the build itself is containerised.

```
task lock        # regenerate requirements.txt from requirements.in
task build       # docker buildx build --platform linux/arm64
task build-load  # build and load to local docker
task push        # build and push to ghcr.io/tobydoescode/litellm:latest
```

CI is the authoritative builder; `task push` is a convenience for one-off
builds.

## Deployment

Deployed into the home-lab k3s cluster via Flux manifests in the
[lab repo](https://github.com/tobydoescode/lab) under
`deploy/flux/apps/base/litellm/`. The deployment pins the image by digest
(`@sha256:...`); Renovate in the lab repo bumps the pin when a new `:latest`
digest is published here.
