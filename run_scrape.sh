#!/usr/bin/env bash
# Robust Framer → static sync for Jenkins
# - Mirrors site to a temp dir
# - Settles filesystem
# - Rsyncs into repo (ignoring Jenkins support files)
# - Ignores rsync exit code 24 (vanished files) but fails on others

set -euo pipefail

# --- Config via env (overridable from Jenkins) ---
SCRAPE_URL="${SCRAPE_URL:-https://rbconcretelevel.framer.website/}"
WORKSPACE="${WORKSPACE:-$(pwd)}"

# Optional: extra wget args (e.g., to strip cache-busters)
# WGET_ARGS="--reject-regex '.*\\?.*'"
WGET_ARGS="${WGET_ARGS:-}"

# Optional: publish into a subfolder (e.g., docs). Leave empty for repo root.
SITE_SUBDIR="${SITE_SUBDIR:-}"

TMPDIR="${WORKSPACE}/.scrape_tmp"
PUBLISH_DIR="${WORKSPACE}"
if [ -n "${SITE_SUBDIR}" ]; then
  PUBLISH_DIR="${WORKSPACE}/${SITE_SUBDIR}"
fi

echo "[run_scrape] Workspace      : ${WORKSPACE}"
echo "[run_scrape] SCRAPE_URL     : ${SCRAPE_URL}"
echo "[run_scrape] SITE_SUBDIR    : ${SITE_SUBDIR:-<root>}"
echo "[run_scrape] WGET_ARGS      : ${WGET_ARGS:-<none>}"

# --- Pre-flight checks ---
if ! command -v wget >/dev/null 2>&1; then
  echo "[run_scrape] ERROR: wget not found on agent."
  exit 1
fi

# rsync is optional; we’ll fall back to copy if missing
HAS_RSYNC=0
if command -v rsync >/dev/null 2>&1; then
  HAS_RSYNC=1
fi

# --- Fresh temp dir ---
rm -rf "${TMPDIR}"
mkdir -p "${TMPDIR}"

# --- Mirror the site ---
echo "[run_scrape] Mirroring site with wget..."
# Notes:
# --mirror           recursive + timestamps
# --page-requisites  get CSS/JS/images
# --adjust-extension add .html to directory-like pages
# --convert-links    make links local
# --no-parent        don’t go above start
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
  ${WGET_ARGS} \
  "${SCRAPE_URL}"

echo "[run_scrape] Mirroring complete. Settling filesystem..."
sync
sleep 1

# Ensure publish dir exists
mkdir -p "${PUBLISH_DIR}"

# --- Sync mirrored files into repo ---
if [ "${HAS_RSYNC}" -eq 1 ]; then
  echo "[run_scrape] Using rsync (with --delete) into ${PUBLISH_DIR} (preserving .git/Jenkins files)"
  # Exclusions are relative to the DEST root; we run from WORKSPACE for clarity
  set +e
  rsync -a --delete \
    --exclude='.git/' \
    --exclude='.gitignore' \
    --exclude='.gitattributes' \
    --exclude='Jenkinsfile' \
    --exclude='run_scrape.sh' \
    "${TMPDIR}/" "${PUBLISH_DIR}/"
  RSYNC_RC=$?
  set -e

  if [ "${RSYNC_RC}" -eq 24 ]; then
    echo "[run_scrape] rsync code 24 (vanished files) — safe to ignore."
  elif [ "${RSYNC_RC}" -ne 0 ]; then
    echo "[run_scrape] ERROR: rsync failed with exit code ${RSYNC_RC}"
    exit "${RSYNC_RC}"
  fi
else
  echo "[run_scrape] rsync not found; doing cautious copy into ${PUBLISH_DIR}"
  shopt -s dotglob
  # Remove everything except core repo/Jenkins files in the publish root
  for item in "${PUBLISH_DIR}"/*; do
    base="$(basename "$item")"
    if [ "$base" != ".git" ] && [ "$base" != "Jenkinsfile" ] && [ "$base" != "run_scrape.sh" ]; then
      rm -rf "$item"
    fi
  done
  cp -a "${TMPDIR}/." "${PUBLISH_DIR}/"
fi

echo "[run_scrape] Sync complete."

# Optional: write/refresh CNAME for GitHub Pages if provided by Jenkins env
if [ -n "${CNAME_DOMAIN:-}" ]; then
  echo "${CNAME_DOMAIN}" > "${PUBLISH_DIR}/CNAME"
  echo "[run_scrape] Wrote CNAME: ${CNAME_DOMAIN}"
fi

echo "[run_scrape] Done."
