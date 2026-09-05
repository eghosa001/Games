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
# all Web template variants referenced by the editor must be present. Do not
# skip the download merely because Vercel's persistent cache contains one
# variant but not the others.
if [ ! -f "${TEMPLATES_DIR}/web_nothreads_debug.zip" ] \
  || [ ! -f "${TEMPLATES_DIR}/web_nothreads_release.zip" ] \
  || [ ! -f "${TEMPLATES_DIR}/web_debug.zip" ] \
  || [ ! -f "${TEMPLATES_DIR}/web_release.zip" ]; then
  rm -rf /tmp/godot_templates
  curl -fsSL "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v4.5-stable_export_templates.tpz" -o /tmp/templates.tpz
  unzip -q -o /tmp/templates.tpz -d /tmp/godot_templates
  cp -R /tmp/godot_templates/templates/. "${TEMPLATES_DIR}/"
fi

# The project historically declared several autoloads with the same
# class_name as their singleton name. Godot 4.5 rejects that combination at
# startup ("hides an autoload singleton"). Keep the runtime singleton names
# unchanged and remove only the conflicting optional class declarations in
# this isolated Vercel build workspace. The source files remain untouched.
for file in \
  scripts/infrastructure_system.gd \
  scripts/collection_system.gd \
  scripts/liveops_system.gd \
  scripts/headquarters_system.gd \
  scripts/employee_system.gd \
  scripts/global_ranking_system.gd \
  scripts/world_event_system.gd \
  scripts/analytics_system.gd \
  scripts/ui_screen_manager.gd; do
  [ -f "$file" ] && sed -i '/^class_name Renew\(InfrastructureSystem\|CollectionSystem\|LiveOpsSystem\|HeadquartersSystem\|EmployeeSystem\|GlobalRankingSystem\|WorldEventSystem\|AnalyticsSystem\|UIScreenManager\)$/d' "$file"
done

# Typed Variants make the project compile consistently under Godot 4.5's
# stricter inference rules. These are build-workspace normalizations only.
find scripts -type f -name '*.gd' -print0 | xargs -0 sed -i \
  -e 's/var spend:=/var spend: Dictionary =/g' \
  -e 's/var spend :=/var spend: Dictionary =/g' \
  -e 's/var resources_before :=/var resources_before: Dictionary =/g'

# Import first so parse/autoload errors are reported before export.
"${GODOT_BIN}" --headless --path . --editor --quit
"${GODOT_BIN}" --headless --path . --export-release "Web" build/web/index.html

test -s build/web/index.html
