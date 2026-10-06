# webhook.site image builds

Rebuilds the upstream [webhook.site](https://github.com/webhooksite/webhook.site)
container. No application sources live here — the workflow checks out upstream
at a commit and builds its `Dockerfile`, then layers a four-line `Dockerfile` of
its own on top.

That overlay exists because upstream ships `pdo_mysql` and `pdo_sqlite` but no
`pdo_pgsql`, and sqlite is not usable where this runs: it depends on fcntl
locking, which is unreliable on NFS.

```
ghcr.io/davehornigan/webhook.site:<YYYYMMDDHHMM>
ghcr.io/davehornigan/webhook.site:latest
```

The tag is when the image was built, in UTC to the minute: a release is named
for when it was released. It is purely numeric, so it sorts correctly for both
humans and a Flux image policy without any tag filtering. Which upstream commit
it came from is on the image, not in the tag:

| label | holds |
|-------|-------|
| `org.opencontainers.image.revision` | upstream commit sha |
| `pro.hornigan.upstream.committed`   | when that commit landed |
| `pro.hornigan.upstream.release`     | newest upstream release at build time |

```
docker buildx imagetools inspect ghcr.io/davehornigan/webhook.site:latest \
  --format '{{json .Image.Config.Labels}}'
```

## Why commits and not releases

Upstream tags releases roughly once every few years:

| release | date |
|---------|------|
| 1.3     | 2023-06-21 |
| 1.2     | 2021-05-17 |
| 1.1     | 2018-04-29 |

Meanwhile `master` keeps moving. A workflow that only reacted to new releases
would stay silent for years while the code it builds changes underneath. So the
trigger is the upstream commit, and the newest release is recorded as the
`pro.hornigan.upstream.release` label and in the release notes instead.

To pin a release instead, set `UPSTREAM_REF` in the workflow to that tag.

## How it decides to build

The daily run reads `org.opencontainers.image.revision` back off the published
`:latest` and compares it with upstream's current commit. Same sha, nothing to
do; different sha, build. The tag cannot answer that question, since it names
the build rather than the source — which is also why a forced rebuild is free
of collisions: it simply gets a later timestamp. If it does, the run ends. There is no state file
to drift: a failed or interrupted build simply leaves the tag absent, and the
next run retries it.

`workflow_dispatch` takes a `force` input to rebuild regardless.

GitHub disables cron in a public repository after 60 days without repository
activity, and scheduled runs do not count. This repo is committed to rarely, so
expect that mail eventually and re-enable the schedule from the Actions tab.

## Upstream caveats

* The official `webhooksite/webhook.site` image on Docker Hub carries only
  `latest`, last pushed 2025-04-04 — roughly a year and a half behind the
  repository. That gap is the reason this repo exists.
* Builds are `linux/amd64` only. Upstream's stages use `node:11` and
  `bkuhl/fpm-nginx:7.4`, which publish no arm64.
* The self-hosted edition omits Custom Actions and WebhookScript; those are
  cloud-only. It receives, stores and displays requests.

MIT, same as upstream.

## Running it locally

`compose.yaml` brings up the same shape the cluster runs: Postgres instead of
the baked sqlite, a separate queue worker, a one-shot migration, and the echo
server under the one hostname the image's nginx will accept.

```
export APP_KEY="base64:$(openssl rand -base64 32)"
docker compose up -d --build
curl -X POST localhost:8099/token -H 'Content-Type: application/json' -d '{}'
```

Upstream ships its own compose file; it does not work against the current
images. It overrides the echo server's command with one its entrypoint no
longer understands, passes Redis settings under names the echo server does not
read, and puts the database in sqlite. Each of those took a failed container to
find, so they are commented where they are fixed.
