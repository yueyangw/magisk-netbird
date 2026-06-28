#!/system/bin/sh

SERVICE_DIR="/data/adb/service.d"

if [ -x /data/adb/netbird/scripts/netbird.tun ]; then
  /data/adb/netbird/scripts/netbird.tun stop >/dev/null 2>&1 || true
fi

if [ -x /data/adb/netbird/scripts/netbird.service ]; then
  /data/adb/netbird/scripts/netbird.service stop >/dev/null 2>&1 || true
fi

rm -f "${SERVICE_DIR}/netbird_service.sh"
rm -rf /data/adb/netbird
