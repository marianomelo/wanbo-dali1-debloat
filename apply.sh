#!/usr/bin/env bash
# Debloat a Wanbo Dali 1 projector over network ADB. Safe to run repeatedly: anything already
# applied stays as it is. Everything is reversible (see README, "Revert").
# Usage: ./apply.sh <projector-ip>
set -euo pipefail
cd "$(dirname "$0")"
[ $# -eq 1 ] || { echo "Usage: $0 <projector-ip>"; exit 1; }
D="$1:5555"

adb connect "$D" >/dev/null
adb -s "$D" get-state >/dev/null || { echo "Cannot connect or not authorized (see README, Troubleshooting)"; exit 1; }

# </dev/null: otherwise adb shell eats the stdin of the while-read loops
ash() { adb -s "$D" shell "$@" </dev/null | tr -d '\r'; }

has_projectivy=$(ash pm list packages com.spocky.projengmenu)

# "not installed for 0" = already removed
while read -r p; do ash pm uninstall -k --user 0 "$p" >/dev/null 2>&1 || true; done < packages/removed-user0.txt

while read -r p; do
  [ -z "$p" ] && continue
  if [ "$p" = com.zeasn.launcher ] && [ -z "$has_projectivy" ]; then
    echo "Skipping $p: without Projectivy installed, the Home button would have nothing to open"
    continue
  fi
  ash pm disable-user --user 0 "$p" >/dev/null 2>&1 || true
done < packages/disabled.txt

# Play Store re-enables a merely disabled YouTube on reboot; hiding sticks
ash pm hide com.google.android.youtube.tv >/dev/null || true
# Only entry on stock firmware: com.kystar.middleware.track (logs the foreground app)
ash settings delete secure enabled_accessibility_services >/dev/null
for k in window_animation_scale transition_animation_scale animator_duration_scale; do
  ash settings put global "$k" 0
done

# SmartTube: YouTube refuses to run on this device. The APK is checked against GitHub's sha256.
if [ -z "$(ash pm list packages org.smarttube.stable)" ]; then
  tmp=$(mktemp -d)
  read -r url digest < <(curl -fsSL https://api.github.com/repos/yuliskov/SmartTube/releases/latest | python3 -c '
import json, sys
a = [a for a in json.load(sys.stdin)["assets"] if "stable" in a["name"] and "armeabi-v7a" in a["name"]][0]
print(a["browser_download_url"], a["digest"].split(":")[1])')
  curl -fsSL -o "$tmp/smarttube.apk" "$url"
  echo "$digest  $tmp/smarttube.apk" | sha256sum -c -
  adb -s "$D" install "$tmp/smarttube.apk"
  rm -rf "$tmp"
fi

if [ -n "$has_projectivy" ]; then
  ash cmd package set-home-activity com.spocky.projengmenu/.ui.home.MainActivity
else
  ash am start -a android.intent.action.VIEW -d 'market://details?id=com.spocky.projengmenu' >/dev/null
  echo
  echo "Manual step: Projectivy Launcher is open in Play Store on the projector."
  echo "  1. Install it and finish its welcome wizard with the remote."
  echo "  2. Run ./apply.sh $1 again (sets it as Home and disables the Wanbo launcher)."
fi

ash pm trim-caches 999G
echo
echo "Disabled: $(ash pm list packages -d | wc -l) · Home: $(ash cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME | tail -1)"
echo "Reboot to finish: adb -s $D reboot"
