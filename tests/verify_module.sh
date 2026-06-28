#!/bin/sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
FAIL=0

note() {
  printf '%s\n' "$*"
}

fail() {
  FAIL=1
  printf 'FAIL: %s\n' "$*" >&2
}

require_file() {
  [ -f "$ROOT/$1" ] || fail "missing file: $1"
}

require_executable_shell() {
  require_file "$1"
  [ -f "$ROOT/$1" ] || return 0
  sh -n "$ROOT/$1" || fail "shell syntax failed: $1"
  first_line="$(sed -n '1p' "$ROOT/$1")"
  case "$first_line" in
    '#!'*) : ;;
    *) fail "missing shebang: $1" ;;
  esac
}

require_contains() {
  file="$1"
  pattern="$2"
  require_file "$file"
  [ -f "$ROOT/$file" ] || return 0
  grep -F -- "$pattern" "$ROOT/$file" >/dev/null 2>&1 || fail "$file does not contain: $pattern"
}

require_not_contains() {
  pattern="$1"
  if grep -R --exclude='verify_module.sh' -- "$pattern" "$ROOT" >/dev/null 2>&1; then
    fail "unexpected legacy pattern found: $pattern"
  fi
}

require_file "module.prop"
require_executable_shell "customize.sh"
require_executable_shell "service.sh"
require_executable_shell "uninstall.sh"
require_file "META-INF/com/google/android/update-binary"
require_file "META-INF/com/google/android/updater-script"
require_file "system/etc/resolv.conf"

require_executable_shell "netbird/scripts/start.sh"
require_executable_shell "netbird/scripts/netbird.cli"
require_executable_shell "netbird/scripts/netbird.service"
require_executable_shell "netbird/scripts/netbird.inotify"
require_executable_shell "netbird/scripts/resolvconf"
require_executable_shell "netbird/settings.sh"
require_file "README.md"

require_contains "module.prop" "id=magisk-netbird"
require_contains "customize.sh" "/data/adb/netbird"
require_contains "customize.sh" "jq-build-for-android"
require_contains "customize.sh" "netbird.cli"
require_contains "customize.sh" "netbird.service"
require_contains "customize.sh" "resolvconf"
require_contains "customize.sh" "system/etc"
require_contains "service.sh" "/data/adb/netbird/scripts/start.sh"
require_contains "system/etc/resolv.conf" "nameserver"
require_contains "netbird/settings.sh" "NB_DAEMON_ADDR=unix:///data/adb/netbird/run/netbird.sock"
require_contains "netbird/settings.sh" 'export USER="${USER:-root}"'
require_contains "netbird/settings.sh" 'export LOGNAME="${LOGNAME:-root}"'
require_contains "netbird/settings.sh" 'export USERNAME="${USERNAME:-root}"'
require_contains "netbird/settings.sh" 'export SHELL="${SHELL:-/system/bin/sh}"'
require_contains "netbird/settings.sh" 'export SSL_CERT_DIR="${SSL_CERT_DIR:-/system/etc/security/cacerts}"'
require_contains "netbird/settings.sh" 'export NB_USE_LEGACY_ROUTING=true'
require_contains "netbird/settings.sh" 'NB_DNS_RESOLVER_ADDRESS="${NB_DNS_RESOLVER_ADDRESS-127.0.0.1:1053}"'
require_contains "netbird/settings.sh" "dns_resolver_address_is_custom"
require_contains "netbird/settings.sh" 'NB_DAEMON_GID="${NB_DAEMON_GID:-3003}"'
require_contains "netbird/settings.sh" 'NB_RESOLV_CONF="${NB_RESOLV_CONF:-/etc/resolv.conf}"'
require_contains "netbird/settings.sh" 'NB_RESOLV_CONF_BACKUP="${NB_RUN_DIR}/resolv.conf.original"'
require_contains "netbird/settings.sh" 'NB_RESOLV_CONF_MODULE="${NB_MOD_DIR}/system/etc/resolv.conf"'
require_contains "netbird/settings.sh" "return 1"
require_contains "netbird/settings.sh" "pidof netbird"
require_contains "netbird/settings.sh" '/proc/$pid/cmdline'
require_contains "netbird/scripts/netbird.cli" "NB_DAEMON_ADDR"
require_contains "netbird/scripts/netbird.cli" "/data/adb/netbird/bin/netbird"
require_contains "netbird/scripts/netbird.cli" "append_admin_url_if_missing"
require_contains "netbird/scripts/netbird.cli" "append_android_default_flags"
require_contains "netbird/scripts/netbird.cli" "--disable-ipv6"
require_contains "netbird/scripts/netbird.cli" "--disable-dns=false"
require_contains "netbird/scripts/netbird.cli" "--dns-resolver-address"
require_contains "netbird/scripts/netbird.service" "netbird service run"
require_contains "netbird/scripts/netbird.service" "ensure_native_config"
require_contains "netbird/scripts/netbird.service" "DisableIPv6"
require_contains "netbird/scripts/netbird.service" "DisableDNS = false"
require_contains "netbird/scripts/netbird.service" 'CustomDNSAddress = $dns'
require_contains "netbird/scripts/netbird.service" "del(.CustomDNSAddress)"
require_contains "netbird/scripts/netbird.service" "netbird_wg_ipv4"
require_contains "netbird/scripts/netbird.service" "effective_dns_resolver_address"
require_contains "netbird/scripts/netbird.service" 'NB_POLICY_RULE_PRIORITY="${NB_POLICY_RULE_PRIORITY:-9000}"'
require_contains "netbird/scripts/netbird.service" 'NB_ROOT_BYPASS_RULE_PRIORITY="${NB_ROOT_BYPASS_RULE_PRIORITY:-9010}"'
require_contains "netbird/scripts/netbird.service" "NB_DNS_REDIRECT_TARGET_FILE"
require_contains "netbird/scripts/netbird.service" "sync_android_policy_rules"
require_contains "netbird/scripts/netbird.service" "sync_android_vpn_bypass_rules"
require_contains "netbird/scripts/netbird.service" "cleanup_android_vpn_bypass_rules"
require_contains "netbird/scripts/netbird.service" "android_underlying_route_table"
require_contains "netbird/scripts/netbird.service" "NB_POLICY_RULE_PRIORITY"
require_contains "netbird/scripts/netbird.service" "NB_POLICY_ROUTE_TABLE"
require_contains "netbird/scripts/netbird.service" "NB_ANDROID_VPN_PROTECT_MARK"
require_contains "netbird/scripts/netbird.service" "ip route flush table"
require_contains "netbird/scripts/netbird.service" "ip route replace"
require_contains "netbird/scripts/netbird.service" "ip rule add priority"
require_contains "netbird/scripts/netbird.service" 'ip rule add priority "$NB_ROOT_BYPASS_RULE_PRIORITY" uidrange 0-0 lookup "$underlying_table"'
require_contains "netbird/scripts/netbird.service" 'ip -6 rule add priority "$NB_ROOT_BYPASS_RULE_PRIORITY" uidrange 0-0 lookup "$underlying_table"'
require_contains "netbird/scripts/netbird.service" 'lookup "$NB_POLICY_ROUTE_TABLE"'
require_contains "netbird/scripts/netbird.service" 'MARK --set-xmark "${NB_ANDROID_VPN_PROTECT_MARK}/${NB_ANDROID_VPN_PROTECT_MARK}"'
require_contains "netbird/scripts/netbird.service" "sync_android_inbound_wt_rules"
require_contains "netbird/scripts/netbird.service" '-i "$iface" -j ACCEPT'
require_contains "netbird/scripts/netbird.service" "sync_android_resolv_conf"
require_contains "netbird/scripts/netbird.service" "restore_android_resolv_conf"
require_contains "netbird/scripts/netbird.service" "# Generated by Magisk NetBird"
require_contains "netbird/scripts/netbird.service" 'mount -o bind "$NB_RESOLV_CONF_MODULE" "$NB_RESOLV_CONF"'
require_contains "netbird/scripts/netbird.service" 'umount "$NB_RESOLV_CONF"'
require_contains "netbird/scripts/netbird.service" "prepare_android_resolvconf_manager"
require_contains "netbird/scripts/netbird.service" "sync_android_dns_redirect"
require_contains "netbird/scripts/netbird.service" "cleanup_android_dns_redirect"
require_contains "netbird/scripts/netbird.service" "cleanup_stale_dns_dnat_rules"
require_contains "netbird/scripts/netbird.service" "iptables -w 5 -t nat -S OUTPUT"
require_contains "netbird/scripts/netbird.service" 'for redirect_target in $redirect_targets'
require_contains "netbird/scripts/netbird.service" "dns_upstreams"
require_contains "netbird/scripts/netbird.service" "NB_DNS_UPSTREAMS_FILE"
require_contains "netbird/scripts/netbird.service" 'su -g "$NB_DAEMON_GID"'
require_contains "netbird/scripts/netbird.service" '--gid-owner "$NB_DAEMON_GID"'
require_contains "netbird/scripts/netbird.service" "-m owner --uid-owner 0 -j RETURN"
require_contains "netbird/scripts/netbird.service" "--uid-owner 0"
require_contains "netbird/scripts/netbird.service" '--dport 53 -j DNAT --to-destination "$dns_address"'
require_contains "netbird/scripts/netbird.service" '-j DNAT --to-destination "$dns_address"'
require_not_contains 'NB_POLICY_RULE_PRIORITY="${NB_POLICY_RULE_PRIORITY:-12490}"'
require_contains "netbird/scripts/resolvconf" "Magisk NetBird resolvconf stub"
require_contains "netbird/scripts/resolvconf" "--version"
require_contains "README.md" "NetBird-managed WireGuard interface"

require_not_contains "/data/adb/tailscale"
require_not_contains "tailscaled"
require_not_contains "tailscale0"
require_not_contains "NB_USE_NETSTACK_MODE=true"
require_not_contains "NB_SOCKS5_LISTENER_PORT"
require_not_contains "hev-socks5-tunnel"
require_not_contains "netbird.tun start"
require_not_contains "netbird.tun sync-routes"
require_not_contains "netbird0 transparent routing"
require_not_contains "sync-routes"
require_not_contains "NB_DNS_DOMAINS_FILE"
require_not_contains 'NB_DNS_RESOLVER_ADDRESS="${NB_DNS_RESOLVER_ADDRESS:-127.0.0.1:53}"'
require_not_contains 'NB_DNS_RESOLVER_ADDRESS="${NB_DNS_RESOLVER_ADDRESS:-}"'
require_not_contains 'for dns_address in $redirect_targets'
require_not_contains "dnsServers[].domains"
require_not_contains "dns_domain_hex_string"
require_not_contains "--hex-string"
require_not_contains '--dport 53 -m string --algo bm --string'
require_not_contains '-m string --string "qwq"'
require_not_contains '-I INPUT 2 -i "$iface" -p icmp -j ACCEPT'
require_contains "netbird/scripts/netbird.service" 'rm -f "$NB_RUN_DIR/dns.domains"'

if [ "$FAIL" -eq 0 ]; then
  note "PASS: magisk-netbird module structure and shell syntax verified"
fi

exit "$FAIL"
