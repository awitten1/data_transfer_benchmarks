
create table results as select * from 'results_10.csv';

select output_format,
    avg(client_elapsed_s) as avg_client_elapsed_s,
    avg(server_duration_ms)/1000 as avg_server_duration_s
from results
group by output_format;
