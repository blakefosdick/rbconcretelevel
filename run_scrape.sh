#!/usr/bin/env bash
set -euo pipefail

# Config (overridable from Jenkins env)
BASE_URL="${SCRAPE_URL:-https://rbconcretelevel.framer.website/}"
WORKSPACE="${WORKSPACE:-$(pwd)}"
SITE_SUBDIR="${SITE_SUBDIR:-}"   # e.g. 'docs' or '' for root
CNAME_DOMAIN="${CNAME_DOMAIN:-}" # e.g. 'rbconcretelevel.com'

PUBLISH_DIR="${WORKSPACE}"
if [ -n "${SITE_SUBDIR}" ]; then
  PUBLISH_DIR="${WORKSPACE}/${SITE_SUBDIR}"
fi

# Routes to export (add more if you add pages)
ROUTES=(
  ""                # /
  "contact"         # /contact
  "terms-and-privacy"
)

echo "[scrape] Publishing to: ${PUBLISH_DIR}"
mkdir -p "${PUBLISH_DIR}"

need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1"; exit 1; }; }
need curl

# Clean publish dir except repo files we keep
shopt -s dotglob
for item in "${PUBLISH_DIR}"/*; do
  base="$(basename "$item")"
  if [ "$base" != ".git" ] && [ "$base" != "Jenkinsfile" ] && [ "$base" != "run_scrape.sh" ] && [ "$base" != ".nojekyll" ] && [ "$base" != "CNAME" ]; then
    rm -rf "$item"
  fi
done

# Fetch each route HTML and write pretty-URL structure
for route in "${ROUTES[@]}"; do
  url="${BASE_URL%/}/${route}"
  outdir="${PUBLISH_DIR}"
  [ -n "$route" ] && outdir="${PUBLISH_DIR}/${route}"
  mkdir -p "$outdir"
  echo "[scrape] GET ${url} -> ${outdir}/index.html"
  # -L follow redirects, -sS quiet but show errors, -H set an accept header
  curl -LsS -H 'Accept: text/html' "$url" -o "${outdir}/index.html"
done

# Ensure Pages compatibility & optional domain
touch "${PUBLISH_DIR}/.nojekyll"
if [ -n "${CNAME_DOMAIN}" ]; then
  echo "${CNAME_DOMAIN}" > "${PUBLISH_DIR}/CNAME"
  echo "[scrape] Wrote CNAME: ${CNAME_DOMAIN}"
fi

echo "[scrape] Done."
