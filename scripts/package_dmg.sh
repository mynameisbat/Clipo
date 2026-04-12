#!/bin/zsh

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
derived_data_path="$repo_root/.derivedData"
project_path="$repo_root/Clipo.xcodeproj"
scheme="Clipo"
configuration="Release"

app_path=""
output_path=""
volume_name="Clipo"

usage() {
  cat <<'EOF'
Usage: scripts/package_dmg.sh [--app-path /path/to/Clipo.app] [--output /path/to/Clipo.dmg] [--volume-name "Clipo"]

If --app-path is omitted, the script builds Release from Clipo.xcodeproj first.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app-path)
      app_path="$2"
      shift 2
      ;;
    --output)
      output_path="$2"
      shift 2
      ;;
    --volume-name)
      volume_name="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$app_path" ]]; then
  xcodebuild build \
    -project "$project_path" \
    -scheme "$scheme" \
    -configuration "$configuration" \
    -destination 'platform=macOS' \
    -derivedDataPath "$derived_data_path"

  app_path="$derived_data_path/Build/Products/$configuration/Clipo.app"
fi

if [[ ! -d "$app_path" ]]; then
  echo "App bundle not found at: $app_path" >&2
  exit 1
fi

version="$(defaults read "$app_path/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo "1.0.0")"

if [[ -z "$output_path" ]]; then
  output_path="$repo_root/Clipo-v$version.dmg"
fi

stage_dir="$(mktemp -d)"
trap 'rm -rf "$stage_dir"' EXIT

rm -f "$output_path"
mkdir -p "$stage_dir"
ditto "$app_path" "$stage_dir/Clipo.app"
ln -s /Applications "$stage_dir/Applications"

hdiutil create \
  -volname "$volume_name" \
  -srcfolder "$stage_dir" \
  -ov \
  -format UDZO \
  "$output_path" \
  >/dev/null

echo "Created $output_path"
