#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "$script_dir/.." && pwd)"

"$script_dir/flutter.sh" build macos --debug

build_app="$project_root/build/macos/Build/Products/Debug/Daily.app"
install_app="${DAILY_MACOS_APP_PATH:-$HOME/Applications/Daily.app}"

if [[ ! -d "$build_app" ]]; then
  echo "macOS build app not found: $build_app" >&2
  exit 1
fi

previous_team_identifier=""
if [[ -d "$install_app" ]]; then
  previous_team_identifier="$(
    codesign -dv --verbose=4 "$install_app" 2>&1 \
      | awk -F= '/^TeamIdentifier=/ { print $2; exit }'
  )"
fi

mkdir -p "$(dirname "$install_app")"
rm -rf "$install_app"
ditto "$build_app" "$install_app"
xattr -cr "$install_app" 2>/dev/null || true

codesign_identity="${DAILY_CODESIGN_IDENTITY:-}"
if [[ -z "$codesign_identity" ]]; then
  codesign_identity="$(
    security find-identity -v -p codesigning 2>/dev/null \
      | awk -F '"' '/Apple Development|Developer ID Application|Mac Developer/ { print $2; exit }'
  )"
fi

if [[ -n "$codesign_identity" ]]; then
  codesign --force --deep --options runtime \
    --entitlements "$project_root/macos/Runner/DebugProfile.entitlements" \
    --sign "$codesign_identity" \
    "$install_app"
  echo "Daily signed with $codesign_identity"
else
  echo "warning: no Apple code-signing identity found; Daily will run ad-hoc signed." >&2
  echo "warning: macOS Notification Center can drop ad-hoc app notifications as app not found." >&2
fi

launch_services="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
"$launch_services" -u "$build_app" 2>/dev/null || true
"$launch_services" -u "$install_app" 2>/dev/null || true
while IFS= read -r registered_app; do
  if [[ "$registered_app" != "$install_app" ]]; then
    "$launch_services" -u "$registered_app" 2>/dev/null || true
  fi
done < <(mdfind "kMDItemCFBundleIdentifier == 'com.littlebit0.daily.macos'" 2>/dev/null || true)
"$launch_services" -f "$install_app"
mdimport "$install_app" 2>/dev/null || true

current_team_identifier="$(
  codesign -dv --verbose=4 "$install_app" 2>&1 \
    | awk -F= '/^TeamIdentifier=/ { print $2; exit }'
)"
if [[ "${DAILY_REFRESH_NOTIFICATION_SERVICES:-auto}" != "0" \
  && -n "$current_team_identifier" \
  && "$current_team_identifier" != "$previous_team_identifier" ]]; then
  killall NotificationCenter 2>/dev/null || true
  killall usernoted 2>/dev/null || true
  echo "Daily notification services refreshed for TeamIdentifier change."
fi

pkill -f '/Daily.app/Contents/MacOS/Daily' 2>/dev/null || true
open -n "$install_app"

echo "Daily launched from $install_app"
