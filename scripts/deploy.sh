#!/usr/bin/env bash
set -Eeuo pipefail

release_id=${1:?Usage: deploy.sh RELEASE_ID [BASE_DIR] [HEALTHCHECK_URL] [PHP_FPM_SERVICE]}
base_dir=${2:-/var/www/shopdaten.jonova.de}
healthcheck_url=${3:-https://shopdaten.jonova.de/index.php?r=/getconfig}
php_fpm_service=${4:-php8.4-fpm}

if [[ ! "$release_id" =~ ^[a-zA-Z0-9._-]+$ ]]; then
  echo "Invalid release id: $release_id" >&2
  exit 1
fi

if [[ "$base_dir" != /* || "$base_dir" == / ]]; then
  echo "BASE_DIR must be an absolute, non-root path" >&2
  exit 1
fi

if [[ ! "$php_fpm_service" =~ ^php[0-9]+\.[0-9]+-fpm$ ]]; then
  echo "Invalid PHP-FPM service: $php_fpm_service" >&2
  exit 1
fi

archive_path="$base_dir/incoming/$release_id.tar.gz"
release_dir="$base_dir/releases/$release_id"
shared_dir="$base_dir/shared"
live_link="$base_dir/live"

required_shared_paths=(
  "$shared_dir/private"
  "$shared_dir/private/csrf.key"
  "$shared_dir/private/users.json"
  "$shared_dir/repository"
)

if [[ ! -f "$archive_path" ]]; then
  echo "Release archive not found: $archive_path" >&2
  exit 1
fi

for shared_path in "${required_shared_paths[@]}"; do
  if [[ ! -e "$shared_path" ]]; then
    echo "Required shared path not found: $shared_path" >&2
    exit 1
  fi
done

if [[ -e "$release_dir" ]]; then
  echo "Release directory already exists: $release_dir" >&2
  exit 1
fi

if [[ -e "$live_link" && ! -L "$live_link" ]]; then
  echo "Refusing to replace non-symlink path: $live_link" >&2
  exit 1
fi

umask 0027
mkdir -p "$release_dir"
tar -xzf "$archive_path" --strip-components=1 --no-same-owner -C "$release_dir"

install -m 0644 "$release_dir/configuration_sample.php" "$release_dir/configuration.php"
ln -s "$shared_dir/private" "$release_dir/private"
ln -s "$shared_dir/repository" "$release_dir/repository"

php -l "$release_dir/configuration.php" >/dev/null
php -l "$release_dir/dist/index.php" >/dev/null
php -r "require '$release_dir/vendor/autoload.php';" >/dev/null

previous_target=$(readlink "$live_link" 2>/dev/null || true)
temporary_link="$base_dir/.live-$release_id"
ln -s "$release_dir" "$temporary_link"
mv -Tf "$temporary_link" "$live_link"

rollback_live_link() {
  if [[ -n "$previous_target" ]]; then
    rollback_link="$base_dir/.live-rollback-$release_id"
    ln -s "$previous_target" "$rollback_link"
    mv -Tf "$rollback_link" "$live_link"
  else
    unlink "$live_link"
  fi
}

if ! sudo /usr/bin/systemctl restart "$php_fpm_service"; then
  echo "PHP-FPM restart failed; rolling back" >&2
  rollback_live_link
  sudo /usr/bin/systemctl restart "$php_fpm_service" || true
  exit 1
fi

if curl --fail --silent --show-error --location --max-time 20 "$healthcheck_url" >/dev/null; then
  rm -f -- "$archive_path"
  echo "Deployed $release_id"
  exit 0
fi

echo "Health check failed; rolling back" >&2
rollback_live_link
sudo /usr/bin/systemctl restart "$php_fpm_service" || true

exit 1
