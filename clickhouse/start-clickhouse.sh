#!/usr/bin/env bash
set -euo pipefail

script_path=$(realpath "${BASH_SOURCE[0]}")
work_dir=$(dirname "$script_path")
data_dir="$work_dir/clickhouse-data"
clickhouse_bin="$work_dir/.clickhouse/bin/clickhouse"
mkdir -p "$data_dir"
cd "$data_dir"
exec "$clickhouse_bin" server --config-file="$work_dir/clickhouse-config.xml"
