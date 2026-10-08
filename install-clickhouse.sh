#!/usr/bin/env bash
set -euo pipefail

script_path=$(realpath "${BASH_SOURCE[0]}")
work_dir=$(dirname "$script_path")
version=26.9.12.8

case "$(uname -m)" in
  x86_64) arch=amd64 ;;
  aarch64) arch=arm64 ;;
  *) echo "Unsupported architecture" >&2; exit 1 ;;
esac

install_dir="$work_dir/.clickhouse"
download_dir="$install_dir/downloads"
packages_dir="$install_dir/packages"
bin_dir="$install_dir/bin"
base_url=https://packages.clickhouse.com/tgz/stable

mkdir -p "$download_dir" "$packages_dir" "$bin_dir"

for pkg in clickhouse-common-static clickhouse-common-static-dbg clickhouse-server clickhouse-client clickhouse-keeper; do
  archive="$pkg-$version-$arch.tgz"
  file="$download_dir/$archive"
  checksum_file="$archive.sha512"

  curl -fsSL --retry 3 --output "$download_dir/$checksum_file" "$base_url/$checksum_file"
  if [[ ! -f "$file" ]] || ! (cd "$download_dir" && sha512sum -c --status "$checksum_file"); then
    echo "Downloading $archive"
    curl -fsSL --retry 3 --output "$file" "$base_url/$archive"
  fi

  (cd "$download_dir" && sha512sum -c "$checksum_file")
done

for pkg in clickhouse-common-static clickhouse-common-static-dbg clickhouse-server clickhouse-client clickhouse-keeper; do
  tar -xzf "$download_dir/$pkg-$version-$arch.tgz" -C "$packages_dir"
done

ln -sfn "$packages_dir/clickhouse-common-static-$version/usr/bin/clickhouse" "$bin_dir/clickhouse"
ln -sfn "$bin_dir/clickhouse" "$bin_dir/clickhouse-server"
ln -sfn "$bin_dir/clickhouse" "$bin_dir/clickhouse-client"
ln -sfn "$packages_dir/clickhouse-keeper-$version/usr/bin/clickhouse-keeper" "$bin_dir/clickhouse-keeper"
