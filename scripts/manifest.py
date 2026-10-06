#!/usr/bin/env python3
"""(Re)generate the DIST lines for one kind version in app-containers/kind/Manifest.

Usage: manifest.py <pv> <src-tarball> <deps-tarball>
Merges into the existing Manifest, keeping DIST lines of other versions.
"""
import hashlib
import sys


def digests(path):
    b2b = hashlib.blake2b(digest_size=64)
    sha512 = hashlib.sha512()
    size = 0
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            size += len(chunk)
            b2b.update(chunk)
            sha512.update(chunk)
    return f"{size} BLAKE2B {b2b.hexdigest()} SHA512 {sha512.hexdigest()}"


def main():
    pv, src, deps = sys.argv[1], sys.argv[2], sys.argv[3]
    manifest = "app-containers/kind/Manifest"
    lines = []
    current = {f"kind-{pv}.tar.gz", f"kind-{pv}-deps.tar.xz"}
    try:
        with open(manifest) as f:
            for line in f:
                line = line.rstrip("\n")
                if line.startswith("DIST ") and line.split()[1] not in current:
                    lines.append(line)
    except FileNotFoundError:
        pass
    lines.append(f"DIST kind-{pv}-deps.tar.xz {digests(deps)}")
    lines.append(f"DIST kind-{pv}.tar.gz {digests(src)}")
    lines.sort()
    with open(manifest, "w") as f:
        f.write("\n".join(lines) + "\n")
    for line in lines:
        print(line)


if __name__ == "__main__":
    main()