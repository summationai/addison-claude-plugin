#!/usr/bin/env bash
# Assemble plugins/addison-claude-internal from the external source of truth (plugins/addison-claude):
#   1. copy the external plugin
#   2. bake EDITION="internal" into sum_api.py (build-time constant — no runtime unlock)
#   3. apply internal skill overlays from internal/overlay/
#   4. namespace slash-commands (/addison: -> /addison-internal:)
#   5. write the internal plugin.json (version synced from external)
# plugins/addison-claude-internal is GENERATED — never edit it directly.
set -euo pipefail
cd "$(dirname "$0")"

SRC=plugins/addison-claude
DST=plugins/addison-claude-internal

if find "$SRC" -name ".summation-config*" | grep -q .; then
  echo "refusing to build: credential file inside $SRC" >&2
  exit 1
fi

rm -rf "$DST"
cp -R "$SRC" "$DST"

# 2. bake edition (fail hard if the anchor ever drifts). perl -i is portable across
# macOS (BSD) and the Linux CI runner (GNU); `sed -i ''` is not.
perl -i -pe 's/^EDITION = "external"$/EDITION = "internal"/' "$DST/skills/api/scripts/sum_api.py"
grep -q '^EDITION = "internal"$' "$DST/skills/api/scripts/sum_api.py" || {
  echo "edition bake failed: EDITION anchor not found in sum_api.py" >&2
  exit 1
}

# 3. internal skill overlays (login/logout/api/doctor keep env, profile, and M2M surfaces)
cp -R internal/overlay/skills/. "$DST/skills/"

# 4. namespace slash-commands
grep -rl "/addison:" "$DST" --include="*.md" --include="*.html" | while read -r f; do
  perl -i -pe 's|/addison:|/addison-internal:|g' "$f"
done

# 5. internal manifest, version synced from external
VERSION=$(python3 -c "import json; print(json.load(open('$SRC/.claude-plugin/plugin.json'))['version'])")
cat > "$DST/.claude-plugin/plugin.json" <<JSON
{
  "name": "addison-internal",
  "displayName": "Addison (Internal)",
  "version": "$VERSION",
  "description": "Internal edition of the Addison plugin: any environment (sandbox/staging/prod/per-cluster), device login + M2M, profiles, and the full helper surface. Summation employees only.",
  "author": {
    "name": "Summation"
  },
  "homepage": "https://summation.com",
  "license": "MIT",
  "repository": "https://github.com/summationai/addison-plugin",
  "keywords": [
    "data",
    "analytics",
    "internal",
    "sum-api"
  ]
}
JSON

echo "built $DST (version $VERSION)"
