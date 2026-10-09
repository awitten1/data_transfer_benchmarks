#!/usr/bin/env bash
set -euo pipefail

if [[ $# != 1 ]]; then
  echo "Usage: $0 SCALE_FACTOR (1, 10, or 100)" >&2
  exit 1
fi

sf=$1
case "$sf" in
  1) file_suffix=tbl ;;
  10) file_suffix=tbl.zst ;;
  100) file_suffix=tbl.gz ;;
  *)
    echo "Usage: $0 SCALE_FACTOR (1, 10, or 100)" >&2
    exit 1
    ;;
esac

script_path=$(realpath "${BASH_SOURCE[0]}")
work_dir=$(dirname "$script_path")
client="$work_dir/.clickhouse/bin/clickhouse-client"
database="tpch_sf$sf"

show_connection_command() {
  printf '\nConnect with:\n  %q --host=127.0.0.1 --database=%q\n' "$client" "$database"
}
trap show_connection_command EXIT

exists=$("$client" --host=127.0.0.1 --query "EXISTS DATABASE $database")
if [[ "$exists" != 0 ]]; then
  echo "Database $database already exists" >&2
  exit 1
fi

"$client" --host=127.0.0.1 --query "CREATE DATABASE $database"
"$client" --host=127.0.0.1 --database="$database" --multiquery < "$work_dir/tpch-init.sql"

for table in nation region part supplier partsupp customer orders lineitem; do
  echo "Loading $table"
  "$client" --host=127.0.0.1 --database="$database" --query "
    INSERT INTO $table
    SELECT * FROM s3(
      'https://clickhouse-datasets.s3.amazonaws.com/h/$sf/$table.$file_suffix',
      NOSIGN,
      CSV
    )
    SETTINGS format_csv_delimiter = '|',
             input_format_defaults_for_omitted_fields = 1,
             input_format_csv_empty_as_default = 1
  "
done
