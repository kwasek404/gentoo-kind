# gentoo-kind

A Gentoo git overlay for [app-containers/kind](app-containers/kind): ebuilds for
[kind](https://kind.sigs.k8s.io/) (Kubernetes in Docker), auto-bumped from
upstream [kubernetes-sigs/kind](https://github.com/kubernetes-sigs/kind) tags.

## Layout
- `app-containers/kind/` - kind ebuild and Manifest
- `profile/` - overlay metadata (repo_name)
- `scripts/` - bump pipeline (`bump.sh`, `manifest.py`)
- `.github/workflows/bump.yml` - scheduled/manual bump workflow

## Pipeline
On a daily schedule (and on manual dispatch) `bump.yml` runs `scripts/bump.sh`.
For each new upstream tag it:
1. fetches the upstream source archive at the tag
2. builds the go-module deps tarball (`go mod download`) in a pinned
   `golang:1.26.7` container
3. regenerates `app-containers/kind/Manifest`
4. commits, pushes, and publishes a GitHub release carrying the deps tarball

The ebuild content is version-independent; the filename carries the PV, so a
bump is a file copy plus a new Manifest line.

## Manual bump
```
DRY_RUN=1 bash scripts/bump.sh [tag]
```
Omitting the tag uses the latest stable upstream release.

## Consuming the overlay
The overlay uses thin manifests (DIST lines only, no EBUILD/MISC digests), matching the guru overlay convention.
Add to `/etc/portage/repos.conf`:
```
[gentoo-kind]
location = /var/db/repos/gentoo-kind
sync-type = git
sync-uri = https://github.com/kwasek404/gentoo-kind.git
```