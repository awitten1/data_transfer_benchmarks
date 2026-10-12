cmake_minimum_required(VERSION 3.14)
project(clickhouse-benchmark LANGUAGES CXX)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_CXX_STANDARD 20)

include(FetchContent)

set(CH_USE_3X_API ON)

FetchContent_Declare(
    clickhouse_cpp
    GIT_REPOSITORY https://github.com/ClickHouse/clickhouse-cpp.git
    GIT_TAG v2.6.2
)
FetchContent_MakeAvailable(clickhouse_cpp)

find_package(AdbcDriverManager REQUIRED)

add_executable(main main.cpp)
target_link_libraries(main PRIVATE clickhouse-cpp-lib)
target_link_libraries(main PRIVATE
    AdbcDriverManager::adbc_driver_manager_shared
)