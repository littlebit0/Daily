#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "$script_dir/.." && pwd)"

"$script_dir/flutter.sh" build macos --debug

build_app="$project_root/build/macos/Build/Products/Debug/Daily Test.app"
install_app="${DAILY_MACOS_APP_PATH:-$HOME/Applications/Daily Test.app}"

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

codesign --verify --deep --strict "$install_app"
echo "Daily uses the Xcode-managed development signature from the build."

launch_services="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
"$launch_services" -u "$build_app" 2>/dev/null || true
"$launch_services" -u "$install_app" 2>/dev/null || true
while IFS= read -r registered_app; do
  if [[ "$registered_app" != "$install_app" ]]; then
    "$launch_services" -u "$registered_app" 2>/dev/null || true
  fi
done < <(mdfind "kMDItemCFBundleIdentifier == 'com.littlebit0.daily.test'" 2>/dev/null || true)
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

pkill -f '/Daily Test.app/Contents/MacOS/Daily Test' 2>/dev/null || true
open -n "$install_app"

echo "Daily launched from $install_app"
