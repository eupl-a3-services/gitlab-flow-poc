#!/bin/sh


if [ -n "$1" ]; then
  SRC="/bin/$1.bin.sh"
  DST=".bin/$1.bin.sh"

  if [ ! -f "$SRC" ]; then
    log ERROR "Source file not found: $SRC"
    exit 1
  fi

  if [ -e "$DST" ]; then
    log ERROR "File already exists: $DST"
    exit 2
  fi

  mkdir -p .bin
  cp "$SRC" "$DST"

  log success "Copied: $SRC -> $DST"
  exit 0
fi

OLD_DIR=$(pwd)
DIR_CHANGED=false

if [ -d ".bin" ]; then
  cd .bin && DIR_CHANGED=true
elif [ -d "bin" ]; then
  cd bin && DIR_CHANGED=true
fi

chmod +x .*.bin.sh *.bin.sh 2>/dev/null || true

for script in .*.bin.sh *.bin.sh; do
  [ -e "$script" ] || continue
  
  base_name=$(basename "$script" .bin.sh)
  target_path="/usr/local/bin/$base_name"
  
  ln -sf "$(pwd)/$script" "$target_path"
  
  log success "Installed: Symbolic link created: $target_path -> $(pwd)/$script"
done

if [ "$DIR_CHANGED" = "true" ]; then
  cd "$OLD_DIR"
fi