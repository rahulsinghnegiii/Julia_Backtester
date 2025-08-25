# Test configuration
enable_testing()

# Find required test frameworks
find_package(GTest QUIET)
if(NOT GTest_FOUND)
    # Download and build Google Test
    include(FetchContent)
    FetchContent_Declare(
        googletest
        URL https://github.com/google/googletest/archive/03597a01ee50f33f9bf776e955e80b7e34123a6b.zip
    )
    FetchContent_MakeAvailable(googletest)
endif()

# Unit tests
add_executable(unit_tests
    unit/test_types.cpp
    unit/test_strategy_parser.cpp
    unit/test_stock_node.cpp
    unit/test_backtesting_engine.cpp
)

target_link_libraries(unit_tests
    PRIVATE
    atlas_core
    gtest_main
    nlohmann_json::nlohmann_json
)

target_include_directories(unit_tests
    PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/../include
)

# Integration tests
add_executable(integration_tests
    integration/test_small_strategy.cpp
    integration/test_end_to_end.cpp
)

target_link_libraries(integration_tests
    PRIVATE
    atlas_core
    gtest_main
    nlohmann_json::nlohmann_json
)

target_include_directories(integration_tests
    PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/../include
)

# Performance benchmarks
add_executable(performance_tests
    performance/benchmark_engine.cpp
)

target_link_libraries(performance_tests
    PRIVATE
    atlas_core
    gtest_main
    nlohmann_json::nlohmann_json
)

target_include_directories(performance_tests
    PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/../include
)

# Register tests with CTest
add_test(NAME UnitTests COMMAND unit_tests)
add_test(NAME IntegrationTests COMMAND integration_tests)
add_test(NAME PerformanceTests COMMAND performance_tests)

# Copy test data
configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/../../../App/Tests/E2E/JSONs/SmallStrategy.json
    ${CMAKE_CURRENT_BINARY_DIR}/SmallStrategy.json
    COPYONLY
)

configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/../../../App/Tests/E2E/ExpectedFiles/SmallStrategy.json
    ${CMAKE_CURRENT_BINARY_DIR}/SmallStrategy_expected.json
    COPYONLY
)