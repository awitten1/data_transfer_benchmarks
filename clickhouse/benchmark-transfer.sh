#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

if [[ $# -lt 1 || $# -gt 3 || ! $1 =~ ^(1|10|100)$ ]]; then
  echo "Usage: $0 SCALE_FACTOR (1, 10, or 100) [partial|full] [OFFSET]" >&2
  exit 1
fi

sf=$1
mode=${2:-partial}
if [[ $mode != partial && $mode != full ]]; then
  echo "Sort mode must be partial or full" >&2
  exit 1
fi
offset=${3:-100000}
if [[ ! $offset =~ ^(0|[1-9][0-9]*)$ ]]; then
  echo "Offset must be a non-negative integer" >&2
  exit 1
fi

script_path=$(realpath "${BASH_SOURCE[0]}")
script_dir=$(dirname "$script_path")
clickhouse="$script_dir/.clickhouse/bin/clickhouse"
run_id="transfer_${sf}_${mode}_${offset}_$$_$(date +%s%N)"

printf 'sf,sort_mode,limit,offset,round,output_format,query_id,client_elapsed_s,client_body_bytes,server_duration_ms,server_http_bytes,read_rows,result_rows\n'
for limit in 10000 100000 1000000 10000000; do
  if [[ $mode == partial ]]; then
    query="SELECT * FROM tpch_sf${sf}.lineitem
ORDER BY l_orderkey, l_extendedprice
LIMIT $limit OFFSET $offset
SETTINGS query_plan_optimize_lazy_materialization = 0,
         use_query_cache = 0"
  else
    query="SELECT * FROM tpch_sf${sf}.lineitem
ORDER BY l_extendedprice, l_orderkey
LIMIT $limit OFFSET $offset
SETTINGS query_plan_optimize_lazy_materialization = 0,
         use_query_cache = 0"
  fi

  # Round 0 warms the query; the next five rounds are measured.
  for round in 0 1 2 3 4 5; do
    if (( round % 2 == 0 )); then
      formats=(RowBinary Null)
    else
      formats=(Null RowBinary)
    fi

    for format in "${formats[@]}"; do
      query_id="$run_id:$limit:$offset:$format:$round"
      printf 'query_id=%s output_format=%s\n%s\n\n' "$query_id" "$format" "$query" >&2

      curl_args=(--silent --show-error --fail --max-time 600 --get http://127.0.0.1:8123/ \
        --data-urlencode "query=$query" \
        --data-urlencode "output_format=$format" \
        --data-urlencode "query_id=$query_id" \
        --data-urlencode 'enable_http_compression=0' \
        --output /dev/null)

      if (( round == 0 )); then
        curl "${curl_args[@]}"
        continue
      fi

      sample=$(curl "${curl_args[@]}" --write-out '%{time_total} %{size_download}')

      read -r seconds bytes <<< "$sample"
      if [[ $format == Null && $bytes != 0 ]]; then
        echo "Unexpected Null response: $bytes body bytes" >&2
        exit 1
      fi

      server_metrics=$("$clickhouse" client --multiquery <<SQL
SYSTEM FLUSH LOGS;

SELECT
    query_duration_ms,
    ProfileEvents['InterfaceHTTPSendBytes'],
    read_rows,
    result_rows
FROM system.query_log
WHERE query_id = '$query_id'
  AND type = 'QueryFinish'
FORMAT TSV;
SQL
)
      if [[ -z $server_metrics ]]; then
        echo "No query_log row found for $query_id" >&2
        exit 1
      fi
      read -r server_ms server_bytes read_rows result_rows <<< "$server_metrics"

      printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
        "$sf" "$mode" "$limit" "$offset" "$round" "$format" "$query_id" \
        "$seconds" "$bytes" "$server_ms" "$server_bytes" \
        "$read_rows" "$result_rows"
    done
  done
done
