# LiteLLM

Multi-arch Docker image of [LiteLLM](https://github.com/BerriAI/litellm) built
for the home-lab k3s cluster. Exists because upstream does not publish ARM64
images, and the cluster is mixed amd64/arm64.

## Build pipeline

`.github/workflows/build-image.yaml` builds `linux/amd64` and `linux/arm64` in
parallel on GitHub-hosted runners and publishes a single multi-arch manifest
list to `ghcr.io/tobydoescode/litellm`. Tags: `latest` (default branch),
`sha-<sha>`, and semver from `v*` tags.

The Dockerfile installs `litellm[proxy]` from `requirements.txt` and runs
`generate_prisma.py` at build time to pre-generate the Prisma client.

## Local development

No local Python toolchain required — everything runs in the image.

```
task build       # docker buildx build --platform linux/arm64
task build-load  # build and load to local docker
task push        # build and push to ghcr.io/tobydoescode/litellm:<VERSION>
```

CI is the authoritative builder; `task push` is a convenience for one-off
builds. Version is pinned in `Taskfile.yml`.

## Deployment

Deployed into the home-lab k3s cluster via Flux manifests in the
[lab repo](https://github.com/tobydoescode/lab) under
`deploy/flux/apps/base/litellm/`. The deployment pins the image by digest
(`@sha256:...`); Renovate in the lab repo bumps the pin when a new `:latest`
digest is published here.
