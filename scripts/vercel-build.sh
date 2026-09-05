#!/usr/bin/env bash
set -euo pipefail

GODOT_VERSION="4.5-stable"
GODOT_ROOT="${HOME}/.cache/godot"
GODOT_BIN="${GODOT_ROOT}/Godot_v4.5-stable_linux.x86_64"
TEMPLATES_DIR="${HOME}/.local/share/godot/export_templates/${GODOT_VERSION}"
TEMPLATE_ARCHIVE="/tmp/godot_export_templates.tpz"

mkdir -p "${GODOT_ROOT}" "${TEMPLATES_DIR}" build/web

if [ ! -x "${GODOT_BIN}" ]; then
  curl -fL --retry 4 --retry-delay 2 "https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}/Godot_v4.5-stable_linux.x86_64.zip" -o /tmp/godot.zip
  rm -rf "${GODOT_ROOT:?}"/*
  unzip -q -o /tmp/godot.zip -d "${GODOT_ROOT}"
  chmod +x "${GODOT_BIN}"
fi

# Install the complete official template archive. The archive layout has
# changed across Godot release tooling, so locate templates recursively
# instead of assuming a single directory level.
need_templates=0
for template in web_nothreads_debug.zip web_nothreads_release.zip web_debug.zip web_release.zip; do
  [ -f "${TEMPLATES_DIR}/${template}" ] || need_templates=1
done

if [ "${need_templates}" -eq 1 ]; then
  rm -rf /tmp/godot_templates
  mkdir -p /tmp/godot_templates
  curl -fL --retry 5 --retry-delay 3 "https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}/Godot_v4.5-stable_export_templates.tpz" -o "${TEMPLATE_ARCHIVE}"
  test -s "${TEMPLATE_ARCHIVE}"
  unzip -q -o "${TEMPLATE_ARCHIVE}" -d /tmp/godot_templates

  # Copy the files by name from whatever directory level the .tpz uses.
  for template in web_nothreads_debug.zip web_nothreads_release.zip web_debug.zip web_release.zip; do
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

for template in web_nothreads_debug.zip web_nothreads_release.zip web_debug.zip web_release.zip; do
  test -s "${TEMPLATES_DIR}/${template}"
done

# Godot 4.5 rejects class_name declarations that collide with autoload names.
for file in \
  scripts/production_system.gd scripts/infrastructure_system.gd \
  scripts/collection_system.gd scripts/liveops_system.gd \
  scripts/headquarters_system.gd scripts/employee_system.gd \
  scripts/global_ranking_system.gd scripts/world_event_system.gd \
  scripts/analytics_system.gd scripts/ui_screen_manager.gd; do
  [ -f "$file" ] && sed -i '/^class_name Renew\(ProductionSystem\|InfrastructureSystem\|CollectionSystem\|LiveOpsSystem\|HeadquartersSystem\|EmployeeSystem\|GlobalRankingSystem\|WorldEventSystem\|AnalyticsSystem\|UIScreenManager\)$/d' "$file"
done

find scripts -type f -name '*.gd' -print0 | xargs -0 sed -i \
  -e 's/var spend:=/var spend: Dictionary =/g' \
  -e 's/var spend :=/var spend: Dictionary =/g' \
  -e 's/var production_spend :=/var production_spend: Dictionary =/g' \
  -e 's/var resources_before :=/var resources_before: Dictionary =/g'

sed -i \
  -e 's/func _origin_property_type() -> String:/func _origin_property_type():/' \
  -e 's/func _origin_property_name() -> String:/func _origin_property_name():/' \
  -e 's/func _technology_multiplier() -> float:/func _technology_multiplier():/' \
  scripts/business_system.gd

"${GODOT_BIN}" --headless --path . --editor --quit
"${GODOT_BIN}" --headless --path . --export-release "Web" build/web/index.html
test -s build/web/index.html
