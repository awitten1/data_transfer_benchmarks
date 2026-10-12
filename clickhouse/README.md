# ClickHouse

From the repository root, install the pinned ClickHouse 26.9.12.8 [Linux tarballs](https://clickhouse.com/docs/get-started/setup/self-managed/other-linux) locally, then start the server:

```sh
cd clickhouse
./install-clickhouse.sh
./start-clickhouse.sh
```

The installer downloads the common, debug, server, client, and Keeper archives and verifies them against ClickHouse's `.sha512` files. Downloads stay in `.clickhouse/`. The server runs in the foreground using `clickhouse-config.xml` and stores its files in `clickhouse-data/`. In another terminal, connect with `./.clickhouse/bin/clickhouse-client` from this directory.

To load TPC-H from ClickHouse's [public S3 datasets](https://clickhouse.com/docs/get-started/sample-datasets/tpch) while the server is running, choose scale factor 1, 10, or 100:

```sh
./load-tpch.sh 1
```

The loader creates a database named `tpch_sf1` and imports the eight tables directly from S3.

To estimate how much time is added by returning query results, run the HTTP benchmark against a loaded database:

```sh
./benchmark-transfer.sh 10 partial > partial_10.csv
./benchmark-transfer.sh 10 full > full_10.csv
./benchmark-transfer.sh 10 partial 0 > partial_10_offset_0.csv
```

Both modes select all columns from `lineitem`. `partial` (the default) sorts by `l_orderkey, l_extendedprice`, using the table's storage order on `l_orderkey`. `full` sorts by `l_extendedprice, l_orderkey`, which requires reading the entire table. The optional third argument applies the same non-negative `OFFSET` to every result limit; it defaults to 100,000. Pass `0` to benchmark without an offset. For each result limit, the script runs one warmup round (round 0) and five measurement rounds, alternating between `RowBinary` and `Null` output. Round 0 runs both formats but produces no CSV rows. The script prints each query to stderr and writes a measured round's CSV row to stdout after the corresponding `query_log` entry is available. Each row includes the offset, curl's client time and downloaded body bytes, and `system.query_log`'s server duration, HTTP bytes, rows read, and rows returned. ClickHouse's HTTP byte count includes protocol overhead. The script leaves all analysis to the CSV consumer.
