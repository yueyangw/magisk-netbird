#!/system/bin/sh

NB_MOD_DIR="/data/adb/modules/magisk-netbird"
export NB_MOD_PROP="${NB_MOD_DIR}/module.prop"

NB_DIR="/data/adb/netbird"
NB_BIN_DIR="${NB_DIR}/bin"
NB_SCRIPTS_DIR="${NB_DIR}/scripts"
NB_RUN_DIR="${NB_DIR}/run"
NB_LOG_FILE="${NB_RUN_DIR}/netbird.log"
NB_RUN_LOG_FILE="${NB_RUN_DIR}/runs.log"
NB_CONFIG_FILE="${NB_DIR}/default.json"
NB_DAEMON_SOCKET="${NB_RUN_DIR}/netbird.sock"

export PATH="${NB_BIN_DIR}:${NB_SCRIPTS_DIR}:/data/adb/magisk:/data/adb/ksu/bin:$PATH:/system/bin:${NB_MOD_DIR}/system/bin"
export HOME="${NB_DIR}"
export USER="${USER:-root}"
export LOGNAME="${LOGNAME:-root}"
export USERNAME="${USERNAME:-root}"
export SHELL="${SHELL:-/system/bin/sh}"
export SSL_CERT_DIR="${SSL_CERT_DIR:-/system/etc/security/cacerts}"
export NB_STATE_DIR="${NB_DIR}"
export NB_DAEMON_ADDR=unix:///data/adb/netbird/run/netbird.sock
export NB_LOG_FILE="${NB_LOG_FILE}"
export NB_USE_LEGACY_ROUTING=true
NB_DNS_RESOLVER_ADDRESS="${NB_DNS_RESOLVER_ADDRESS-127.0.0.1:1053}"
export NB_DNS_RESOLVER_ADDRESS
NB_DAEMON_GID="${NB_DAEMON_GID:-3003}"
export NB_DAEMON_GID
NB_RESOLV_CONF="${NB_RESOLV_CONF:-/etc/resolv.conf}"
NB_RESOLV_CONF_BACKUP="${NB_RUN_DIR}/resolv.conf.original"
NB_RESOLV_CONF_MODULE="${NB_MOD_DIR}/system/etc/resolv.conf"
export NB_RESOLV_CONF
export NB_RESOLV_CONF_BACKUP
export NB_RESOLV_CONF_MODULE

NB_DAEMON_CMD="${NB_BIN_DIR}/netbird service run --daemon-addr ${NB_DAEMON_ADDR} --log-file ${NB_LOG_FILE} --config ${NB_CONFIG_FILE}"
export NB_DAEMON_CMD

CURRENT_TIME="$(date '+%H:%M:%S')"

normal="\033[0m"
red="\033[1;31m"
green="\033[1;32m"
yellow="\033[1;33m"
blue="\033[1;34m"

mkdir -p "${NB_RUN_DIR}" 2>/dev/null || true

dns_resolver_address_is_custom() {
  [ -n "$NB_DNS_RESOLVER_ADDRESS" ]
}

log() {
  level="$1"
  shift || true
  msg="$*"
  case "$level" in
    Info) color="${blue}" ;;
    Success) color="${green}" ;;
    Warning) color="${yellow}" ;;
    Error) color="${red}" ;;
    *) color="${normal}" ;;
  esac
  line="${CURRENT_TIME} [${level}]: ${msg}"
  if [ -t 1 ]; then
    printf '%b%s%b\n' "$color" "$line" "$normal"
  fi
  printf '%s\n' "$line" >>"${NB_RUN_LOG_FILE}" 2>/dev/null || true
}

pidof_command() {
  pattern="$1"
  case "$pattern" in
    "netbird service run")
      pids="$(pidof netbird 2>/dev/null || true)"
      ;;
    *)
      pids="$(busybox pgrep -f "$pattern" 2>/dev/null || pgrep -f "$pattern" 2>/dev/null || true)"
      ;;
  esac

  found=0
  for pid in $pids; do
    [ "$pid" = "$$" ] && continue
    cmdline="$(tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null || true)"
    case "$cmdline" in
      *"$pattern"*)
        printf '%s\n' "$pid"
        found=1
        ;;
    esac
  done
  [ "$found" -eq 1 ] || return 1
}

kill_command() {
  pattern="$1"
  signal="$2"
  for pid in $(pidof_command "$pattern" 2>/dev/null || true); do
    kill "-${signal}" "$pid" >/dev/null 2>&1 || true
  done
}
