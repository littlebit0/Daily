#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "$script_dir/.." && pwd)"
tool_root="$(dirname "$project_root")"

select_existing_path() {
  local required_child="$1"
  shift
  local first_candidate=""

  for candidate in "$@"; do
    if [[ -z "$candidate" ]]; then
      continue
    fi
    if [[ -z "$first_candidate" ]]; then
      first_candidate="$candidate"
    fi
    if [[ -e "$candidate/$required_child" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  if [[ -n "$first_candidate" ]]; then
    printf '%s\n' "$first_candidate"
    return 0
  fi

  return 1
}

flutter_root="${FLUTTER_ROOT:-}"
flutter_bin=""

if [[ -n "$flutter_root" ]]; then
  flutter_bin="$flutter_root/bin/flutter"
elif command -v flutter >/dev/null 2>&1; then
  flutter_bin="$(command -v flutter)"
else
  flutter_root="$(select_existing_path "bin/flutter" \
    "$tool_root/flutter-sdk" \
    "$HOME/development/flutter" \
    "$HOME/flutter" \
    "/opt/flutter" \
    "/usr/local/flutter" \
  )"
  flutter_bin="$flutter_root/bin/flutter"
fi

if [[ ! -x "$flutter_bin" ]]; then
  echo "Flutter SDK not found. Set FLUTTER_ROOT or install Flutter." >&2
  echo "Expected executable: $flutter_bin" >&2
  exit 1
fi

export PUB_CACHE="${PUB_CACHE:-$tool_root/PubCache}"
export PATH="$(dirname "$flutter_bin"):$PATH"

build_path="$project_root/build"
tmp_build_path="${DAILY_FLUTTER_BUILD_DIR:-/tmp/daily-flutter-build}"

if [[ ! -e "$build_path" ]]; then
  mkdir -p "$tmp_build_path"
  ln -s "$tmp_build_path" "$build_path"
fi

cd "$project_root"
"$flutter_bin" "$@"
