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
