#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

version_file="src/karabiner_configurator/core.clj"

if ! command -v lein >/dev/null 2>&1; then
  echo "error: lein is required but was not found on PATH" >&2
  exit 1
fi

if ! command -v native-image >/dev/null 2>&1; then
  if [[ -x /opt/homebrew/opt/graalvm/bin/native-image ]]; then
    export PATH="/opt/homebrew/opt/graalvm/bin:$PATH"
  else
    echo "error: native-image is required but was not found on PATH" >&2
    echo "hint: install GraalVM Native Image or add it to PATH" >&2
    exit 1
  fi
fi

source_version="$(
  perl -0ne 'if (/\(:version options\).*?:exit-message\s+"([^"]+)"/s) { print "$1\n"; exit }' "$version_file"
)"

if [[ -z "$source_version" ]]; then
  echo "error: could not find the Goku version in $version_file" >&2
  exit 1
fi

tag_version="$(
  git describe --tags --abbrev=0 --match 'v[0-9]*' 2>/dev/null | sed 's/^v//'
)"

base_version="${tag_version:-$source_version}"
base_version="${base_version%a}"
local_version="${base_version}a"

tmp_file="$(mktemp "${TMPDIR:-/tmp}/goku-core.XXXXXX")"
cp "$version_file" "$tmp_file"

restore_version_file() {
  cp "$tmp_file" "$version_file"
  rm -f "$tmp_file"
}

trap restore_version_file EXIT INT TERM

export GOKU_CURRENT_VERSION="$source_version"
export GOKU_LOCAL_VERSION="$local_version"

perl -0pi -e '
  BEGIN {
    $from = $ENV{"GOKU_CURRENT_VERSION"};
    $to = $ENV{"GOKU_LOCAL_VERSION"};
  }
  $count += s/(\(:version options\).*?:exit-message\s+")\Q$from\E(")/$1$to$2/s;
  END {
    die "expected exactly one Goku version replacement\n" unless $count == 1;
  }
' "$version_file"

if [[ -n "$tag_version" ]]; then
  echo "Building Goku $local_version from release tag v$tag_version"
else
  echo "Building Goku $local_version from source version $source_version"
fi
make all

built_version="$(./goku --version)"
if [[ "$built_version" != "$local_version" ]]; then
  echo "error: built binary reports $built_version, expected $local_version" >&2
  exit 1
fi

echo "Built $repo_root/goku"
echo "Version: $built_version"
