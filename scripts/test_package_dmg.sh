#!/bin/zsh

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
package_script="$repo_root/scripts/package_dmg.sh"

work_dir="$(mktemp -d)"
mount_dir="$(mktemp -d)"
trap 'hdiutil detach "$mount_dir" >/dev/null 2>&1 || true; rm -rf "$work_dir" "$mount_dir"' EXIT

fake_app="$work_dir/Clipo.app"
mkdir -p "$fake_app/Contents/MacOS"
cat > "$fake_app/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key>
  <string>com.bat.clipo</string>
  <key>CFBundleName</key>
  <string>Clipo</string>
</dict>
</plist>
EOF
touch "$fake_app/Contents/MacOS/Clipo"
chmod +x "$fake_app/Contents/MacOS/Clipo"

output_dmg="$work_dir/Clipo-test.dmg"

"$package_script" --app-path "$fake_app" --output "$output_dmg" --volume-name "Clipo Test"

if [[ ! -f "$output_dmg" ]]; then
  echo "Expected DMG at $output_dmg"
  exit 1
fi

hdiutil attach "$output_dmg" -mountpoint "$mount_dir" -nobrowse -quiet

if [[ ! -d "$mount_dir/Clipo.app" ]]; then
  echo "Mounted DMG does not contain Clipo.app"
  exit 1
fi

if [[ ! -L "$mount_dir/Applications" ]]; then
  echo "Mounted DMG does not contain Applications shortcut"
  exit 1
fi

echo "package_dmg test passed"
