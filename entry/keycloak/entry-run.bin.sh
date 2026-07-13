#!/bin/sh

chmod +x ams-service 2>/dev/null || true
chmod +x .*.bin.sh 2>/dev/null || true
chmod +x *.bin.sh 2>/dev/null || true

ln -sf "$(pwd)/ams-service" /usr/local/bin/ams-service

for script in .*.bin.sh *.bin.sh; do
    ln -sf "$(pwd)/$script" "/usr/local/bin/$(basename "$script" .bin.sh)";
done
