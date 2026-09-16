# GitHub Runner Image

A lightweight Linux self-hosted GitHub Actions runner image based on [`myoung34/github-runner`](https://github.com/myoung34/docker-github-actions-runner), currently using its `ubuntu-noble` base.

It keeps the upstream runner entrypoint and adds/fixes common tooling required by the repositories that use this image:

- Python 3 / `python` alias
- pip and venv
- Node.js 24 + npm
- PHP 8.5 CLI with common Laravel/CI extensions (`bcmath`, `curl`, `intl`, `mbstring`, `mysql`, `sqlite3`, `xml`, `zip`)
- Composer
- GitHub CLI (`gh`)
- `yq`
- `ripgrep` (`rg`)
- PowerShell 7 (`pwsh`, inherited from upstream)
- Git (inherited from upstream)
- Docker CLI (inherited from upstream)
- build/archive/JSON utilities
- Linux runtime dependencies for Playwright Chromium 1.55

The Chromium browser binary is intentionally **not** baked into the image. Workflows can keep their own Playwright/browser version pinned while avoiding repeated OS dependency installation.

## Image

```text
ghcr.io/pdherdy/github-runner-image:latest
```

A second immutable tag is published for every build using the Git commit SHA.

## Usage

The image can run on any compatible Linux/amd64 Docker host, including Docker Engine, Docker Desktop and TrueNAS SCALE Custom Apps.

Example:

```yaml
services:
  runner:
    image: ghcr.io/pdherdy/github-runner-image:latest
```

Keep runner identity and work data on separate persistent mounts. For example:

```yaml
volumes:
  - ./runner-data:/runner/data
  - ./work:/_work
```

Set the runner work directory to `/_work` when using the example mount above.

Each concurrently running runner instance should have its own `/runner/data` and `/_work` storage. Do not share runner identity data between instances.

Do not store GitHub registration tokens, PATs or repository secrets in this image.

## Updating an existing Docker/Compose deployment

When `latest` is rebuilt, pull the new digest and recreate the runner container. Persistent runner identity and work mounts are preserved.

```bash
docker compose pull
docker compose up -d --force-recreate
```

For a single container not managed by Compose, pull the image first and then recreate the container with the same environment variables and mounts:

```bash
docker pull ghcr.io/pdherdy/github-runner-image:latest
```

A plain container restart does **not** replace the old image. The container has to be recreated after the pull.

## TrueNAS SCALE example

A TrueNAS SCALE deployment can use host paths instead of local Docker volumes:

```yaml
services:
  runner:
    image: ghcr.io/pdherdy/github-runner-image:latest
    volumes:
      - /mnt/app_pool/github_runners/example/runner-data:/runner/data
      - /mnt/app_pool/github_runners/example/work:/_work
```

For a Custom App using the `latest` tag, redeploy/update the app after the new image has been published so TrueNAS recreates the container from the new digest. The host-path mounts keep the runner registration and work data intact.

Docker access is intentionally not included in the default example. Add it only to a dedicated runner when a workflow explicitly needs to control the host Docker daemon.

## Publishing

`.github/workflows/publish.yml` builds `linux/amd64` and publishes to GitHub Container Registry using the repository-scoped `GITHUB_TOKEN`. No long-lived package PAT is required for CI publishing.

The Dockerfile validates the expected baseline toolchain during the image build, so a missing `python`, `npm`, `php`, `composer`, `gh`, `yq`, `rg`, `pwsh`, Git or Docker CLI causes publication to fail.
