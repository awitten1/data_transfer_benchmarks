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

Both modes select all columns from `lineitem`. `partial` (the default) sorts by `l_orderkey, l_extendedprice`, using the table's storage order on `l_orderkey`. `full` sorts by `l_extendedprice, l_orderkey`, which requires reading the entire table. The optional third argument applies the same non-negative `OFFSET` to every result limit; it defaults to 100,000. Pass `0` to benchmark without an offset.

The HTTP benchmark compares `RowBinary`, `Native`, `ArrowStream`, `Parquet`, `CSV`, and `JSONEachRow` with `Null` as a no-body baseline. It runs each format at all four result limits for one warmup round and five measured rounds, rotating format order between rounds. A complete run makes 168 requests and writes 140 measured CSV rows plus a header; round 0 is not included in the CSV. HTTP compression is disabled, while format-level defaults remain in effect. In the pinned ClickHouse version, ArrowStream uses LZ4 frame compression and Parquet uses ZSTD by default. These codec choices affect both payload size and timing.

The script prints each query to stderr and writes a measured round's CSV row to stdout after the corresponding `query_log` entry is available. Each row includes the offset, curl's client time and downloaded body bytes, and `system.query_log`'s server duration, HTTP bytes, rows read, and rows returned. ClickHouse's HTTP byte count includes protocol overhead. `analysis.sql` compares each format's median with `Null` at the same limit and offset. The difference estimates the added cost of serializing and delivering the body; it does not isolate network time.
