#!/bin/zsh

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
build_dir="$(mktemp -d)"
temp_assets_dir="${TMPDIR%/}/clipo-readme-assets"
trap 'rm -rf "$build_dir" "$temp_assets_dir"' EXIT

swiftc \
  -framework AppKit \
  -framework SwiftUI \
  "$repo_root/scripts/render_readme_assets.swift" \
  "$repo_root/Clipo/Features/Popup/ClipboardRowView.swift" \
  "$repo_root/Clipo/Features/Popup/EmptyStateView.swift" \
  "$repo_root/Clipo/Features/Popup/FilterChipStrip.swift" \
  "$repo_root/Clipo/Features/Design/DesignTokens.swift" \
  "$repo_root/Clipo/Features/Design/AnimationPresets.swift" \
  "$repo_root/Clipo/Features/Design/LiquidGlassMaterial.swift" \
  "$repo_root/Clipo/Features/Design/VisualEffectView.swift" \
  "$repo_root/Clipo/Support/AppIconProvider.swift" \
  "$repo_root/Clipo/Models/ClipboardItem.swift" \
  "$repo_root/Clipo/Features/History/HistoryFilter.swift" \
  -o "$build_dir/render-readme-assets"

"$build_dir/render-readme-assets"

ffmpeg -y \
  -framerate 2 \
  -i "$temp_assets_dir/gif-frames/frame-%02d.png" \
  -vf "scale=420:-1:flags=lanczos" \
  "$repo_root/docs/assets/clipo-workflow.gif" \
  >/dev/null 2>&1

echo "Generated README assets in $repo_root/docs/assets"
