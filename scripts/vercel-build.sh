#!/usr/bin/env bash
set -euo pipefail

GODOT_VERSION="4.5-stable"
GODOT_ROOT="${HOME}/.cache/godot"
GODOT_BIN="${GODOT_ROOT}/Godot_v4.5-stable_linux.x86_64"
TEMPLATES_DIR="${HOME}/.local/share/godot/export_templates/${GODOT_VERSION}"

mkdir -p "${GODOT_ROOT}" "${TEMPLATES_DIR}" build/web

if [ ! -x "${GODOT_BIN}" ]; then
  curl -fsSL "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v4.5-stable_linux.x86_64.zip" -o /tmp/godot.zip
  unzip -q -o /tmp/godot.zip -d "${GODOT_ROOT}"
  chmod +x "${GODOT_BIN}"
fi

# Godot validates the complete Web preset during project initialization, so
# both the threaded and non-threaded Web templates must be present. Do not
# skip the download merely because one variant already exists in Vercel's
# persistent cache.
if [ ! -f "${TEMPLATES_DIR}/web_nothreads_debug.zip" ] \
  || [ ! -f "${TEMPLATES_DIR}/web_nothreads_release.zip" ] \
  || [ ! -f "${TEMPLATES_DIR}/web_debug.zip" ] \
  || [ ! -f "${TEMPLATES_DIR}/web_release.zip" ]; then
  rm -rf /tmp/godot_templates
  curl -fsSL "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v4.5-stable_export_templates.tpz" -o /tmp/templates.tpz
  unzip -q -o /tmp/templates.tpz -d /tmp/godot_templates
  cp -R /tmp/godot_templates/templates/. "${TEMPLATES_DIR}/"
fi

# Import first so parse/autoload errors are reported before export.
"${GODOT_BIN}" --headless --path . --editor --quit
"${GODOT_BIN}" --headless --path . --export-release "Web" build/web/index.html

test -s build/web/index.html
