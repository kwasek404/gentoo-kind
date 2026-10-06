#!/usr/bin/env bash
# Bump the kind ebuild to a new upstream tag.
#
# Manual:   DRY_RUN=1 bash scripts/bump.sh [tag]     (tag defaults to latest stable release)
# CI:       TARGET_TAG/DRY_RUN/GOLANG_IMAGE come from .github/workflows/bump.yml
set -euo pipefail

cd "$(dirname "$0")/.."

UPSTREAM=kubernetes-sigs/kind
REPO=kwasek404/gentoo-kind
PKG_DIR=app-containers/kind

tag="${1:-${TARGET_TAG:-}}"
if [[ -z "${tag}" ]]; then
	tag="$(gh api repos/${UPSTREAM}/releases/latest --jq .tag_name)"
fi
pv="${tag#v}"

local_latest="$(ls ${PKG_DIR}/kind-*.ebuild | sed 's|.*/kind-||; s|\.ebuild$||' | sort -V | tail -1)"
if [[ "${pv}" == "${local_latest}" ]]; then
	echo "up to date: kind-${pv} ebuild already present"
	exit 0
fi

work="$(mktemp -d)"

# 1. fetch the upstream source archive (exact URL form the ebuild declares)
curl -fL --retry 3 -o "${work}/kind-${pv}.tar.gz" \
	"https://github.com/${UPSTREAM}/archive/v${pv}.tar.gz"

# 2. build the go-module deps tarball (per go-module.eclass header docs)
docker run --rm -v "${work}":/w -w /w "${GOLANG_IMAGE}" bash -c "
	command -v xz >/dev/null || { apt-get update && apt-get install -y --no-install-recommends xz-utils; }
	tar xzf kind-${pv}.tar.gz
	cd kind-${pv}
	GOMODCACHE=\"\$PWD/go-mod\" go mod download -modcacherw
	XZ_OPT='-T0 -9' tar -acf ../kind-${pv}-deps.tar.xz go-mod
"

# 3. ebuild content is version-independent; the filename carries the version
cp "${PKG_DIR}/kind-${local_latest}.ebuild" "${PKG_DIR}/kind-${pv}.ebuild"

# 4. Manifest: merge this version's distfiles into the package Manifest
python3 scripts/manifest.py "${pv}" \
	"${work}/kind-${pv}.tar.gz" "${work}/kind-${pv}-deps.tar.xz"

if [[ "${DRY_RUN:-1}" == "1" ]]; then
	echo "DRY RUN: changes staged, nothing pushed"
	git status --short
	exit 0
fi

# 5. publish: commit, push, release with the deps tarball asset
# CI runners have no default git identity
if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
	git config user.name "github-actions[bot]"
	git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
fi
git add -A
git commit -m "kind ${pv}: ebuild + Manifest"
git push
gh release create "kind-${pv}" --repo "${REPO}" \
	--title "kind ${pv}" \
	--notes "Go module deps tarball for kind ${pv} (go mod download, go-module.eclass compatible)." \
	"${work}/kind-${pv}-deps.tar.xz"
