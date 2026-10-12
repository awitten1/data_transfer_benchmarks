
create table results as select * from 'results_10.csv';


with median_values as (
    select
        query_id,
        output_format,
        "limit",
        row_number() over
            (partition by "limit", output_format order by client_elapsed_s desc) as rn,
        count(1) over (partition by "limit", output_format) as c
    from results
    qualify rn = cast((c + 1) / 2 as int)
),
x as (
    select
        output_format,
        "limit",
        round(median(client_elapsed_s),3) as median_curl_elapsed_time_seconds,
        round(median(server_duration_ms)/1000,3) as median_server_duration_seconds,
        round(median(client_body_bytes),3) as median_client_body_bytes
    from results
    group by all
    order by "limit", output_format
)
select x.*,
    median_values.query_id,
    row_number() over (partition by "limit" order by median_curl_elapsed_time_seconds asc) as r
from x join median_values using ("limit",output_format)
order by "limit", r asc

-- Compare each format's median with Null at the same limit and offset.
-- The percentage uses that format's client time as the total.
with format_metrics as (
    select
        output_format,
        "limit",
        "offset",
        median(client_elapsed_s) as client_seconds,
        median(server_duration_ms) as server_ms,
        median(client_body_bytes) as body_bytes
    from results
    group by all
)
select
    measured.output_format,
    measured."limit",
    measured."offset",
    round(measured.client_seconds - baseline.client_seconds, 4) as extra_client_seconds,
    round(100 * (1 - baseline.client_seconds / nullif(measured.client_seconds, 0)), 1)
        as extra_client_pct_of_format,
    round((measured.server_ms - baseline.server_ms) / 1000, 4) as extra_server_seconds,
    measured.body_bytes as result_body_bytes
from format_metrics as measured
left join format_metrics as baseline
    on baseline.output_format = 'Null'
    and baseline."limit" = measured."limit"
    and baseline."offset" = measured."offset"
where measured.output_format != 'Null'
order by measured."limit", measured."offset", measured.output_format;
