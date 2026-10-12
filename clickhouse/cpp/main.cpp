#include <chrono>
#include <clickhouse/client.h>
#include <iostream>

namespace ch = clickhouse;



int main()
{
    ch::Client client{ch::ClientOptions{}
        .SetHost("localhost")
        .SetDefaultDatabase("tpch_sf10")};

    int trials = 5;


    for (auto limit : std::vector<long>{100'000,1'000'000}) {
        std::vector<float> res;

        for (int i = 0; i < trials; ++i) {
            auto t1 = std::chrono::system_clock::now();
            client.BeginSelect(
                std::format("SELECT * FROM lineitem "
                "ORDER BY l_orderkey, l_extendedprice "
                "LIMIT {} OFFSET 100000 ", limit)
            );
            while (auto block = client.NextBlock()) {
                volatile size_t sz = block->GetRowCount();
            }
            std::chrono::duration<float> diff = std::chrono::system_clock::now() - t1;
            res.push_back(diff.count());
        }

        std::sort(res.begin(), res.end());
        std::cout << "limit = " << limit << " median runtime (seconds) = " << res[trials / 2] << std::endl;

    }

    return 0;
}