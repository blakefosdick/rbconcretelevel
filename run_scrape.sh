#!/usr/bin/env bash
set -euo pipefail

# Inputs via env (set in Jenkinsfile)
SCRAPE_URL="${SCRAPE_URL:-https://rbconcretelevel.framer.website/}"

WORKSPACE="$(pwd)"
TMPDIR="${WORKSPACE}/.scrape_tmp"

echo "[run_scrape] Workspace: ${WORKSPACE}"
echo "[run_scrape] URL: ${SCRAPE_URL}"

rm -rf "${TMPDIR}"
mkdir -p "${TMPDIR}"

# Try to ensure wget exists (best effort; if not, the step will fail and you can install it on the agent)
if ! command -v wget >/dev/null 2>&1; then
  echo "[run_scrape] wget not found. Please install wget on the Jenkins agent."
  exit 1
fi

echo "[run_scrape] Mirroring site with wget..."
# Notes:
# --mirror           recursive + timestamps
# --page-requisites  get all assets (CSS/JS/images)
# --adjust-extension add .html to “directory” pages
# --convert-links    make links local
# --no-parent        don’t go above start path
# -nH/--no-host-directories keep flat structure
# --directory-prefix write into ${TMPDIR}
wget \
  --mirror \
  --page-requisites \
  --adjust-extension \
  --convert-links \
  --no-parent \
  --no-host-directories -nH \
  --directory-prefix="${TMPDIR}" \
  "${SCRAPE_URL}"

# At this point ${TMPDIR} contains the mirrored site (index.html, assets, etc.)

# Sync into workspace root while preserving repo files we need to keep
# Prefer rsync if available for a clean --delete sync
if command -v rsync >/dev/null 2>&1; then
  echo "[run_scrape] rsync --delete into workspace (preserving .git, Jenkins and script files)"
  rsync -a --delete \
    --exclude='.git/' \
    --exclude='.gitignore' \
    --exclude='.gitattributes' \
    --exclude='Jenkinsfile' \
    --exclude='run_scrape.sh' \
    "${TMPDIR}/" "${WORKSPACE}/"
else
  echo "[run_scrape] rsync not found; using basic copy (may leave stale files)"
  shopt -s dotglob
  # Remove everything except .git, Jenkinsfile, run_scrape.sh
  for item in "${WORKSPACE}"/*; do
    base="$(basename "$item")"
    if [ "$base" != ".git" ] && [ "$base" != "Jenkinsfile" ] && [ "$base" != "run_scrape.sh" ]; then
      rm -rf "$item"
    fi
  done
  cp -a "${TMPDIR}/." "${WORKSPACE}/"
fi

echo "[run_scrape] Done."
