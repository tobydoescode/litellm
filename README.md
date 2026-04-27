# LiteLLM

Multi-arch Docker image of [LiteLLM](https://github.com/BerriAI/litellm) built
for the home-lab k3s cluster. Exists because upstream does not publish ARM64
images, and the cluster is mixed amd64/arm64.

## Build pipeline

`.github/workflows/build-image.yaml` validates shell/workflow/lockfile state,
builds `linux/amd64` and `linux/arm64` candidate images in parallel on
GitHub-hosted runners, runs a PostgreSQL-backed LiteLLM smoke test for each
architecture, and then publishes a single multi-arch manifest list to
`ghcr.io/tobydoescode/litellm`. Tags: `latest` (default branch), `sha-<sha>`,
and semver from `v*` tags.

`pyproject.toml` holds the top-level Python pins (LiteLLM and Prisma), and
`uv.lock` is the fully resolved lockfile. The Dockerfile uses digest-pinned
base images and runs `uv sync --frozen` against the lockfile. Regenerate the
lockfile with `task lock` after editing `pyproject.toml`.

## Local development

`task lock` needs `uv` installed locally; the build itself is containerised.

```
task lock        # update uv.lock from pyproject.toml
task build       # docker buildx build --platform linux/arm64 by default
task build-load  # build and load the default local-platform image
task push        # build and push the default local-platform image
```

## Image smoke test

CI builds each architecture image locally, starts a disposable PostgreSQL
database, runs the candidate LiteLLM image against it, checks
`/health/liveliness`, and verifies that Prisma initialized LiteLLM tables in
the database. Images are pushed only after this smoke test passes.

To run the same smoke test locally:

```bash
docker buildx build --platform linux/arm64 -t litellm:smoke --load .
LITELLM_SMOKE_IMAGE=litellm:smoke ./scripts/image-smoke.sh
```

CI is the authoritative builder; `task push` is a convenience for one-off
builds.

## Deployment

Deployed into the home-lab k3s cluster via Flux manifests in the
[lab repo](https://github.com/tobydoescode/lab) under
`deploy/flux/apps/base/litellm/`. The deployment pins the image by digest
(`@sha256:...`); Renovate in the lab repo bumps the pin when a new `:latest`
digest is published here.
