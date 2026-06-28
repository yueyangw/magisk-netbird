#!/system/bin/sh

[ -n "${DEBUG:-}" ] && {
  PS4="+ \${0##*/}:\${LINENO}: "
  set -u
  set -x
} || true

SKIPUNZIP=1
SKIPMOUNT=false

if [ "$BOOTMODE" != true ]; then
  ui_print "! Please install in Magisk Manager or KernelSU Manager"
  abort "Install from recovery is not supported"
elif [ "${KSU:-false}" = true ] && [ "${KSU_VER_CODE:-0}" -lt 10670 ]; then
  abort "error: Please update KernelSU and KernelSU Manager"
fi

NB_DIR="/data/adb/netbird"
NB_BIN_DIR="${NB_DIR}/bin"
NB_SCRIPTS_DIR="${NB_DIR}/scripts"
NB_RUN_DIR="${NB_DIR}/run"
SERVICE_DIR="/data/adb/service.d"

case "$ARCH" in
  arm64)
    NB_ARCH="arm64"
    JQ_ASSET="jq-aarch64-linux-android"
    ;;
  arm)
    NB_ARCH="armv6"
    JQ_ASSET="jq-armv7a-linux-androideabi"
    ;;
  *)
    ui_print "Unsupported architecture: $ARCH"
    abort
    ;;
esac

ui_print "- Detected architecture: $ARCH"

gh_release_asset() {
  repo="$1"
  pattern="$2"
  url="$(
    wget --no-check-certificate --timeout=15 -qO- "https://api.github.com/repos/${repo}/releases/latest" |
      grep "browser_download_url" |
      grep -Ei "$pattern" |
      sed 's/.*"browser_download_url": "\([^"]*\)".*/\1/' |
      head -n 1 || true
  )"
  [ -n "$url" ] || return 1
  filename="$(basename "$url")"
  ui_print "- Downloading $filename"
  wget --no-check-certificate --timeout=120 -qO "${TMPDIR}/${filename}" "$url" || return 1
  FILENAME="$filename"
  return 0
}

ui_print "- Preparing directories"
mkdir -p "$NB_BIN_DIR" "$NB_SCRIPTS_DIR" "$NB_RUN_DIR" "$SERVICE_DIR" "$MODPATH/system/bin" "$MODPATH/system/etc"

if [ -d "$NB_DIR" ]; then
  ui_print "- Preserving existing NetBird state under $NB_DIR"
fi

ui_print "- Removing legacy userspace bridge files if present"
rm -f "$NB_BIN_DIR"/hev-* \
  "$NB_SCRIPTS_DIR"/netbird.tun \
  "$NB_SCRIPTS_DIR"/netbird.tun.up \
  "$NB_SCRIPTS_DIR"/netbird.tun.down \
  "$NB_DIR"/tun.conf \
  "$NB_RUN_DIR"/routes.generated \
  "$NB_RUN_DIR"/netbird.tun.log \
  "$NB_RUN_DIR"/netbird.tun.log.bak \
  "$NB_RUN_DIR"/netbird.tun.pid

ui_print "- Extracting module files"
unzip -qqo "$ZIPFILE" -x 'META-INF/*' 'netbird/bin/*' 'netbird/scripts/*' 'netbird/settings.sh' -d "$MODPATH"
unzip -qqjo "$ZIPFILE" 'netbird/scripts/*' -d "$NB_SCRIPTS_DIR"
unzip -qqjo "$ZIPFILE" 'netbird/settings.sh' -d "$NB_DIR"

ui_print "- Installing bundled binaries if present"
unzip -qqjo "$ZIPFILE" "netbird/bin/*-${ARCH}" -d "$NB_BIN_DIR" 2>/dev/null || true
for f in "$NB_BIN_DIR"/*-"$ARCH"; do
  [ -f "$f" ] && mv -f "$f" "${f%-"$ARCH"}"
done

if [ ! -x "$NB_BIN_DIR/netbird" ]; then
  ui_print "- Bundled netbird binary not found; downloading latest NetBird release"
  gh_release_asset "netbirdio/netbird" "netbird_.*_linux_${NB_ARCH}\\.tar\\.gz" || abort "error: Unable to download NetBird binary"
  tar -xzf "${TMPDIR}/${FILENAME}" -C "$TMPDIR" || abort "error: Unable to extract NetBird archive"
  found="$(find "$TMPDIR" -type f -name netbird | head -n 1)"
  [ -n "$found" ] || abort "error: NetBird binary not found in archive"
  mv -f "$found" "$NB_BIN_DIR/netbird"
fi

if [ ! -x "$NB_BIN_DIR/jq" ]; then
  ui_print "- Bundled jq binary not found; downloading Android jq"
  gh_release_asset "theshoqanebi/jq-build-for-android" "^${JQ_ASSET}$" || abort "error: Unable to download jq"
  mv -f "${TMPDIR}/${FILENAME}" "$NB_BIN_DIR/jq" || abort "error: Unable to install jq"
fi

ln -sf "$NB_SCRIPTS_DIR/netbird.cli" "$MODPATH/system/bin/netbird"
ln -sf "$NB_BIN_DIR/jq" "$MODPATH/system/bin/jq"
ln -sf "$NB_SCRIPTS_DIR/netbird.service" "$MODPATH/system/bin/netbird.service"
ln -sf "$NB_SCRIPTS_DIR/resolvconf" "$MODPATH/system/bin/resolvconf"

ui_print "- Setting permissions"
set_perm_recursive "$NB_BIN_DIR" 0 0 0755 0755 "u:object_r:system_file:s0"
set_perm_recursive "$NB_SCRIPTS_DIR" 0 0 0755 0755 "u:object_r:system_file:s0"
set_perm_recursive "$MODPATH/system/bin" 0 0 0755 0755 "u:object_r:system_file:s0"
set_perm_recursive "$MODPATH/system/etc" 0 0 0755 0644 "u:object_r:system_file:s0"
set_perm "$MODPATH/service.sh" 0 0 0755 "u:object_r:system_file:s0"

if [ ! -f "$SERVICE_DIR/netbird_service.sh" ]; then
  ui_print "- Installing boot service into $SERVICE_DIR"
  mv -f "$MODPATH/service.sh" "$SERVICE_DIR/netbird_service.sh"
else
  ui_print "- Updating existing boot service"
  mv -f "$MODPATH/service.sh" "$SERVICE_DIR/netbird_service.sh"
fi

ui_print "- Creating temporary /dev command links until reboot"
ln -sf "$NB_SCRIPTS_DIR/netbird.cli" /dev/netbird
ln -sf "$NB_SCRIPTS_DIR/netbird.service" /dev/netbird.service

ui_print "-----------------------------------------------------------"
ui_print " Magisk NetBird installed"
ui_print "-----------------------------------------------------------"
ui_print "- Start daemon: su -c 'netbird.service start'"
ui_print "- Login:        su -c 'netbird up --setup-key <key>'"
ui_print "- Logs:         su -c 'netbird.service log daemon'"

"$NB_SCRIPTS_DIR/start.sh" postinstall >/dev/null 2>&1 &

[ -n "${DEBUG:-}" ] && set +u || true
