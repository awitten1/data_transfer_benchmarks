# data_transfer_benchmarks

Install the pinned ClickHouse 26.9.12.8 [Linux tarballs](https://clickhouse.com/docs/get-started/setup/self-managed/other-linux) locally, then start the server:

```sh
./install-clickhouse.sh
./start-clickhouse.sh
```

The installer downloads the common, debug, server, client, and Keeper archives and verifies them against ClickHouse's `.sha512` files. Downloads stay in `.clickhouse/`. The server runs in the foreground using `clickhouse-config.xml` and stores its files in `./clickhouse-data/`. In another terminal, connect with `./.clickhouse/bin/clickhouse-client`.
