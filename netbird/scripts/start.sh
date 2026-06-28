#!/system/bin/sh

DIR="$(dirname "$(realpath "$0")")"
. "$DIR/../settings.sh"

case "${1:-}" in
  postinstall)
    mkdir -p "$NB_RUN_DIR"
    netbird.service restart >/dev/null 2>&1 &
    exit 0
    ;;
esac

start_service() {
  if [ ! -f "${NB_MOD_DIR}/disable" ]; then
    netbird.service start >/dev/null 2>&1
  else
    log Info "Module is disabled; skipping NetBird startup"
  fi
}

start_inotifyd() {
  for pid in $(busybox pidof inotifyd 2>/dev/null || true); do
    if tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null | grep -q "netbird.inotify"; then
      kill -9 "$pid" 2>/dev/null || true
    fi
  done
  log Info "Starting NetBird module inotify watcher"
  inotifyd "netbird.inotify" "${NB_MOD_DIR}" >/dev/null 2>&1 &
}

module_version="$(busybox awk -F= '/^version=/{ print $2 }' "$NB_MOD_PROP" 2>/dev/null || true)"
log Info "Magisk NetBird version: ${module_version:-unknown}"
start_service
start_inotifyd
