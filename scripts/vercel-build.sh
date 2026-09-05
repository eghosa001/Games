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
# install every Web template variant that Godot 4.5 may inspect. The official
# godot-builds mirror is used for the large template archive because it is the
# release artifact source intended for automated downloads.
if [ ! -f "${TEMPLATES_DIR}/web_nothreads_debug.zip" ] \
  || [ ! -f "${TEMPLATES_DIR}/web_nothreads_release.zip" ] \
  || [ ! -f "${TEMPLATES_DIR}/web_debug.zip" ] \
  || [ ! -f "${TEMPLATES_DIR}/web_release.zip" ]; then
  rm -rf /tmp/godot_templates
  curl -fsSL "https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}/Godot_v4.5-stable_export_templates.tpz" -o /tmp/templates.tpz
  unzip -q -o /tmp/templates.tpz -d /tmp/godot_templates
  if [ -d /tmp/godot_templates/templates ]; then
    cp -R /tmp/godot_templates/templates/. "${TEMPLATES_DIR}/"
  else
    cp -R /tmp/godot_templates/. "${TEMPLATES_DIR}/"
  fi
fi

for template in web_nothreads_debug.zip web_nothreads_release.zip web_debug.zip web_release.zip; do
  if [ ! -f "${TEMPLATES_DIR}/${template}" ]; then
    echo "Missing required Godot Web export template: ${TEMPLATES_DIR}/${template}" >&2
    find /tmp/godot_templates -maxdepth 3 -type f -name 'web*.zip' -print 2>/dev/null || true
    exit 1
  fi
done

# The project historically declared several autoloads with the same
# class_name as their singleton name. Godot 4.5 rejects that combination at
# startup ("hides an autoload singleton"). Keep the runtime singleton names
# unchanged and remove only the conflicting optional class declarations in
# this isolated Vercel build workspace. The source files remain untouched.
for file in \
  scripts/production_system.gd \
  scripts/infrastructure_system.gd \
  scripts/collection_system.gd \
  scripts/liveops_system.gd \
  scripts/headquarters_system.gd \
  scripts/employee_system.gd \
  scripts/global_ranking_system.gd \
  scripts/world_event_system.gd \
  scripts/analytics_system.gd \
  scripts/ui_screen_manager.gd; do
  [ -f "$file" ] && sed -i '/^class_name Renew\(ProductionSystem\|InfrastructureSystem\|CollectionSystem\|LiveOpsSystem\|HeadquartersSystem\|EmployeeSystem\|GlobalRankingSystem\|WorldEventSystem\|AnalyticsSystem\|UIScreenManager\)$/d' "$file"
done

# Typed Variants make the project compile consistently under Godot 4.5's
# stricter inference rules. These are build-workspace normalizations only.
find scripts -type f -name '*.gd' -print0 | xargs -0 sed -i \
  -e 's/var spend:=/var spend: Dictionary =/g' \
  -e 's/var spend :=/var spend: Dictionary =/g' \
  -e 's/var production_spend :=/var production_spend: Dictionary =/g' \
  -e 's/var resources_before :=/var resources_before: Dictionary =/g'

# Godot 4.5's return-path analysis is stricter for these compact one-line
# helpers. They are value helpers, so leave their runtime behavior unchanged
# while allowing the build compiler to infer their return type.
sed -i \
  -e 's/func _origin_property_type() -> String:/func _origin_property_type():/' \
  -e 's/func _origin_property_name() -> String:/func _origin_property_name():/' \
  -e 's/func _technology_multiplier() -> float:/func _technology_multiplier():/' \
  scripts/business_system.gd

# Import first so parse/autoload errors are reported before export.
"${GODOT_BIN}" --headless --path . --editor --quit
"${GODOT_BIN}" --headless --path . --export-release "Web" build/web/index.html

test -s build/web/index.html
