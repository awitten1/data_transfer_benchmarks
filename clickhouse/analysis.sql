
create table results as select * from 'results_10.csv';


select
    output_format,
    "limit",
    round(median(client_elapsed_s),3) as median_curl_elapsed_time_seconds,
    round(median(server_duration_ms)/1000,3) as median_server_duration_seconds,
    round(median(client_body_bytes),3) as median_client_body_bytes
from results
group by all
order by "limit",output_format;

-- Difference between the formats' medians estimates the extra cost of
-- serializing and delivering the result body. The percentage uses RowBinary
-- client time as the total.
select
    "limit",
    "offset",
    round(
        median(client_elapsed_s) filter (where output_format = 'RowBinary') -
        median(client_elapsed_s) filter (where output_format = 'Null'), 4
    ) as extra_client_seconds,
    round(100 * (1 -
        median(client_elapsed_s) filter (where output_format = 'Null') /
        nullif(median(client_elapsed_s) filter (where output_format = 'RowBinary'), 0)
    ), 1) as extra_client_pct_of_rowbinary,
    round(
        (median(server_duration_ms) filter (where output_format = 'RowBinary') -
         median(server_duration_ms) filter (where output_format = 'Null')) / 1000, 4
    ) as extra_server_seconds,
    median(client_body_bytes) filter (where output_format = 'RowBinary') as result_body_bytes
from results
group by all
order by "limit", "offset";
