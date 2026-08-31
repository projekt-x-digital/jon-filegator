#!/usr/bin/env bash
set -Eeuo pipefail

project_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
output_path=${1:-"$project_root/build/oneteam-news-filegator.tar.gz"}
staging_root=$(mktemp -d)
package_root="$staging_root/filegator"

cleanup() {
  rm -rf -- "$staging_root"
}
trap cleanup EXIT

required_paths=(
  backend
  dist
  vendor
  configuration_sample.php
  LICENSE
)

for required_path in "${required_paths[@]}"; do
  if [[ ! -e "$project_root/$required_path" ]]; then
    echo "Missing runtime path: $required_path" >&2
    exit 1
  fi
done

if [[ ! -f "$project_root/dist/branding/logo.svg" ]]; then
  echo "Branding was not copied to dist. Run npm run build first." >&2
  exit 1
fi

mkdir -p "$package_root" "$(dirname -- "$output_path")"

for runtime_path in "${required_paths[@]}"; do
  cp -a "$project_root/$runtime_path" "$package_root/"
done

tar -czf "$output_path" -C "$staging_root" filegator
echo "$output_path"
