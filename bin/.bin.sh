#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$HOME/.local/bin"

mkdir -p "$TARGET_DIR"

for file in "$SCRIPT_DIR"/*.bin.sh; do
  [ -e "$file" ] || continue  # preskočí, ak nič nenájde

  base_name="$(basename "${file%.bin.sh}")"
  target_path="${TARGET_DIR}/${base_name}"

  cp "$file" "$target_path"
  chmod +x "$target_path"

  echo "Installed: $target_path"
done