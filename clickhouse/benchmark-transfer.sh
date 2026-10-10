#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

if [[ $# != 1 || ! $1 =~ ^(1|10|100)$ ]]; then
  echo "Usage: $0 SCALE_FACTOR (1, 10, or 100)" >&2
  exit 1
fi

sf=$1
script_path=$(realpath "${BASH_SOURCE[0]}")
script_dir=$(dirname "$script_path")
clickhouse="$script_dir/.clickhouse/bin/clickhouse"
run_id="transfer_${sf}_$$_$(date +%s%N)"
declare -A client_full client_null client_bytes client_pct

median() {
  printf '%s\n' "$@" | sort -n | awk 'NR == 3 { print; exit }'
}

for limit in 10000 100000 1000000; do
  full_times=()
  null_times=()
  body_bytes=()
  query="SELECT * FROM tpch_sf${sf}.orders
ORDER BY o_totalprice, o_orderkey
LIMIT $limit
SETTINGS query_plan_optimize_lazy_materialization = 0,
         use_query_cache = 0"

  # Round 0 warms the query; the next five rounds are measured.
  for round in 0 1 2 3 4 5; do
    if (( round % 2 == 0 )); then
      formats=(RowBinary Null)
    else
      formats=(Null RowBinary)
    fi

    for format in "${formats[@]}"; do
      sample=$(curl --silent --show-error --fail --max-time 600 --get http://127.0.0.1:8123/ \
        --data-urlencode "query=$query" \
        --data-urlencode "output_format=$format" \
        --data-urlencode "query_id=$run_id:$limit:$format:$round" \
        --data-urlencode 'enable_http_compression=0' \
        --output /dev/null \
        --write-out '%{time_total} %{size_download}')

      read -r seconds bytes <<< "$sample"
      if [[ $format == Null && $bytes != 0 ]]; then
        echo "Unexpected Null response: $bytes body bytes" >&2
        exit 1
      fi
      if (( round == 0 )); then
        continue
      fi
      if [[ $format == RowBinary ]]; then
        full_times+=("$seconds")
        body_bytes+=("$bytes")
      else
        null_times+=("$seconds")
      fi
    done
  done

  full=$(median "${full_times[@]}")
  null=$(median "${null_times[@]}")
  bytes=$(median "${body_bytes[@]}")
  fraction=$(awk -v full="$full" -v null="$null" 'BEGIN {
    if (full <= null) print "inconclusive"
    else printf "%.1f", 100 * (full - null) / full
  }')
  client_full[$limit]=$full
  client_null[$limit]=$null
  client_bytes[$limit]=$bytes
  client_pct[$limit]=$fraction
done

log_rows=$("$clickhouse" client --multiquery <<SQL
SYSTEM FLUSH LOGS;

SELECT
    limit,
    round(full_ms / 1000, 3) AS full_s,
    round(null_ms / 1000, 3) AS null_s,
    http_bytes,
    if(full_ms > null_ms,
       toString(round(100 * (full_ms - null_ms) / full_ms, 1)),
       'inconclusive') AS return_overhead_pct
FROM
(
    SELECT
        toUInt32(splitByChar(':', query_id)[2]) AS limit,
        quantileExactIf(query_duration_ms, splitByChar(':', query_id)[3] = 'RowBinary') AS full_ms,
        quantileExactIf(query_duration_ms, splitByChar(':', query_id)[3] = 'Null') AS null_ms,
        quantileExactIf(ProfileEvents['InterfaceHTTPSendBytes'],
                        splitByChar(':', query_id)[3] = 'RowBinary') AS http_bytes
    FROM system.query_log
    WHERE startsWith(query_id, '$run_id:')
      AND type = 'QueryFinish'
      AND splitByChar(':', query_id)[4] != '0'
    GROUP BY limit
)
ORDER BY limit
FORMAT TSV;
SQL
)

if [[ -z $log_rows ]]; then
  echo 'No benchmark rows found in system.query_log' >&2
  exit 1
fi

printf 'sf,limit,client_full_s,client_null_s,client_body_bytes,client_return_overhead_pct,server_full_s,server_null_s,server_http_bytes,server_return_overhead_pct\n'
while IFS=$'\t' read -r limit server_full server_null server_bytes server_pct; do
  printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
    "$sf" "$limit" "${client_full[$limit]}" "${client_null[$limit]}" \
    "${client_bytes[$limit]}" "${client_pct[$limit]}" \
    "$server_full" "$server_null" "$server_bytes" "$server_pct"
done <<< "$log_rows"
