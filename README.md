# webhook.site image builds

Rebuilds the upstream [webhook.site](https://github.com/webhooksite/webhook.site)
container. No application sources live here — the workflow checks out upstream
at a commit and builds its `Dockerfile`.

```
ghcr.io/davehornigan/webhook.site:<YYYYMMDD>
ghcr.io/davehornigan/webhook.site:latest
```

The tag is the date of the newest commit on upstream `master`, which is also
what decides whether to build: a date the registry has not seen means there is
something new. Two commits on the same day land under one tag, so the second
does not retrigger a build — upstream averages one or two commits a month, and
`force` covers the case when it matters.

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

The daily run reads the committer date of the newest commit on `master` and
asks the registry whether an image with that date already exists. If it does, the run ends. There is no state file
to drift: a failed or interrupted build simply leaves the tag absent, and the
next run retries it.

`workflow_dispatch` takes a `force` input to rebuild an existing tag.

## Upstream caveats

* The official `webhooksite/webhook.site` image on Docker Hub carries only
  `latest`, last pushed 2025-04-04 — roughly a year and a half behind the
  repository. That gap is the reason this repo exists.
* Builds are `linux/amd64` only. Upstream's stages use `node:11` and
  `bkuhl/fpm-nginx:7.4`, which publish no arm64.
* The self-hosted edition omits Custom Actions and WebhookScript; those are
  cloud-only. It receives, stores and displays requests.

MIT, same as upstream.
