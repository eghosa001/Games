#!/usr/bin/env bash
set -euo pipefail

GODOT_VERSION="4.7.2"
GODOT_RELEASE="${GODOT_VERSION}-stable"
GODOT_TEMPLATE_VERSION="${GODOT_VERSION}.stable"
GODOT_ROOT="${HOME}/.cache/godot"
GODOT_BIN="${GODOT_ROOT}/Godot_v${GODOT_RELEASE}_linux.x86_64"
export XDG_DATA_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}"
TEMPLATES_DIR="${XDG_DATA_HOME}/godot/export_templates/${GODOT_TEMPLATE_VERSION}"
TEMPLATE_ARCHIVE="/tmp/godot_export_templates.tpz"

mkdir -p "${GODOT_ROOT}" "${TEMPLATES_DIR}" build/web

if [ ! -x "${GODOT_BIN}" ]; then
  curl -fL --retry 4 --retry-delay 2 \
    "https://github.com/godotengine/godot/releases/download/${GODOT_RELEASE}/Godot_v${GODOT_RELEASE}_linux.x86_64.zip" \
    -o /tmp/godot.zip
  rm -rf "${GODOT_ROOT:?}"/*
  unzip -q -o /tmp/godot.zip -d "${GODOT_ROOT}"
  chmod +x "${GODOT_BIN}"
fi

need_templates=0
for template in web_nothreads_debug.zip web_nothreads_release.zip; do
  [ -s "${TEMPLATES_DIR}/${template}" ] || need_templates=1
done

if [ "${need_templates}" -eq 1 ]; then
  rm -rf /tmp/godot_templates
  mkdir -p /tmp/godot_templates
  curl -fL --retry 5 --retry-delay 3 \
    "https://github.com/godotengine/godot/releases/download/${GODOT_RELEASE}/Godot_v${GODOT_RELEASE}_export_templates.tpz" \
    -o "${TEMPLATE_ARCHIVE}"
  test -s "${TEMPLATE_ARCHIVE}"
  unzip -q -o "${TEMPLATE_ARCHIVE}" -d /tmp/godot_templates
  for template in web_nothreads_debug.zip web_nothreads_release.zip; do
    source_file="$(find /tmp/godot_templates -type f -name "${template}" -print -quit)"
    if [ -z "${source_file}" ]; then
      echo "Template ${template} was not present in the downloaded archive." >&2
      find /tmp/godot_templates -type f -name 'web*.zip' -print >&2 || true
      exit 1
    fi
    cp -f "${source_file}" "${TEMPLATES_DIR}/${template}"
  done
  version_file="$(find /tmp/godot_templates -type f -name version.txt -print -quit || true)"
  [ -z "${version_file}" ] || cp -f "${version_file}" "${TEMPLATES_DIR}/version.txt"
fi

for template in web_nothreads_debug.zip web_nothreads_release.zip; do
  test -s "${TEMPLATES_DIR}/${template}"
done

"${GODOT_BIN}" --version
"${GODOT_BIN}" --headless --editor --path . --quit

rm -rf build/web
mkdir -p build/web
"${GODOT_BIN}" --headless --path . --export-release "Web" build/web/index.html

test -s build/web/index.html
pck_file="$(find build/web -maxdepth 1 -type f -name '*.pck' -print -quit)"
wasm_file="$(find build/web -maxdepth 1 -type f -name '*.wasm' -print -quit)"
test -n "${pck_file}" && test -s "${pck_file}"
test -n "${wasm_file}" && test -s "${wasm_file}"
grep -q 'GODOT_THREADS_ENABLED = false' build/web/index.html
if grep -q 'GODOT_THREADS_ENABLED = true' build/web/index.html; then
  echo 'ERROR: Web export has thread support enabled.' >&2
  exit 1
fi
