#!/bin/zsh
# generate-app-icons.sh
# Renders the Pointward app icon at every required iOS size, natively (crisp),
# into the asset catalog. Run from the repo root:  ./Scripts/generate-app-icons.sh
set -e

OUT="HomeLink/Assets.xcassets/AppIcon.appiconset"
GEN="Scripts/AppIconGenerator.swift"

# pixelSize:filename — every file referenced by Contents.json
SIZES=(
  "1024:AppIcon-1024.png"
  "180:AppIcon-180.png"
  "167:AppIcon-167.png"
  "152:AppIcon-152.png"
  "120:AppIcon-120.png"
  "87:AppIcon-87.png"
  "80:AppIcon-80.png"
  "60:AppIcon-60.png"
  "58:AppIcon-58.png"
  "40:AppIcon-40.png"
  "29:AppIcon-29.png"
  "20:AppIcon-20.png"
)

for entry in $SIZES; do
  px="${entry%%:*}"
  file="${entry##*:}"
  swift "$GEN" "$px" "$OUT/$file"
done

echo "✓ all app icon sizes rendered"
