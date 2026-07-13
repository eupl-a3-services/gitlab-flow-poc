#!/bin/sh

chmod +x .*.bin.sh *.bin.sh 2>/dev/null || true

for script in .*.bin.sh *.bin.sh; do
    ln -sf "$(pwd)/$script" "/usr/local/bin/$(basename "$script" .bin.sh)";
done
