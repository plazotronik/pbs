#!/usr/bin/env bash
set -euo pipefail

# ==== PRECONF ====
IMAGE_NAME="plazotronik/pbs"
REPO_URL="https://github.com/plazotronik/pbs.git"
WORKDIR="$(pwd)/pbs-build"

if [ $# -lt 1 ]; then
  echo "Use: $0 <full_version>"
  echo "Example: $0 4.0.13"
  exit 1
fi

VERSION_FULL="$1"
VERSION_MAJOR="${VERSION_FULL%%.*}"
VERSION_MINOR="${VERSION_FULL%.*}"
TAGS=("$VERSION_FULL" "$VERSION_MINOR" "$VERSION_MAJOR" "latest")

# ==== CLONE ====
rm -rf "$WORKDIR"
git clone --depth=1 "$REPO_URL" "$WORKDIR"
cd "$WORKDIR"

# ==== BUILD AMD64 ====
docker buildx build \
  --platform linux/amd64 \
  --provenance=false \
  --sbom=false \
  -f Dockerfile \
  -t docker.io/${IMAGE_NAME}:${VERSION_FULL}-amd64 \
  --push \
  .

# ==== BUILD ARM64 ====
docker buildx build \
  --platform linux/arm64/v8 \
  --provenance=false \
  --sbom=false \
  -f Dockerfile.aarch64 \
  -t docker.io/${IMAGE_NAME}:${VERSION_FULL}-arm64 \
  --push \
  .

# ==== CREATE AND PUSH MANIFESTS ====
for TAG in "${TAGS[@]}"; do
  docker manifest create docker.io/${IMAGE_NAME}:${TAG} \
    --amend docker.io/${IMAGE_NAME}:${VERSION_FULL}-amd64 \
    --amend docker.io/${IMAGE_NAME}:${VERSION_FULL}-arm64
  docker manifest push docker.io/${IMAGE_NAME}:${TAG}
done

echo "Multi-arch tags '${TAGS[*]}' published"
