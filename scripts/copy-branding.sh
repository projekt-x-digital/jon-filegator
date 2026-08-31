#!/usr/bin/env sh
set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
source_logo="$project_root/branding/logo.svg"
target_dir="$project_root/dist/branding"

if [ ! -f "$source_logo" ]; then
  echo "Missing branding/logo.svg" >&2
  exit 1
fi

install -d "$target_dir"
install -m 0644 "$source_logo" "$target_dir/logo.svg"
