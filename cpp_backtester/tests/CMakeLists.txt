# Test configuration
enable_testing()

# Find required test frameworks
find_package(GTest QUIET)
if(NOT GTest_FOUND)
    # Download and build Google Test
    include(FetchContent)
    FetchContent_Declare(
        googletest
        URL https://github.com/google/googletest/archive/v1.14.0.zip
        DOWNLOAD_EXTRACT_TIMESTAMP TRUE
    )
    FetchContent_MakeAvailable(googletest)
endif()

# Unit tests
add_executable(unit_tests
    unit/test_types.cpp
    unit/test_strategy_parser.cpp
    unit/test_stock_node.cpp
    unit/test_backtesting_engine.cpp
    unit/test_technical_indicators.cpp
    unit/test_node_processors.cpp
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
    integration/test_small_strategy_comprehensive.cpp
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
    performance/test_small_strategy_performance.cpp
    performance/test_small_strategy_graph_performance.cpp
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

# Validation tests (Julia compatibility)
add_executable(validation_tests
    validation/test_julia_compatibility.cpp
)

target_link_libraries(validation_tests
    PRIVATE
    atlas_core
    gtest_main
    nlohmann_json::nlohmann_json
)

target_include_directories(validation_tests
    PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/../include
)

# SmallStrategy comprehensive test suite
add_executable(smallstrategy_comprehensive
    integration/test_small_strategy_comprehensive.cpp
)

target_link_libraries(smallstrategy_comprehensive
    PRIVATE
    atlas_core
    gtest_main
    nlohmann_json::nlohmann_json
)

target_include_directories(smallstrategy_comprehensive
    PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/../include
)

# SmallStrategy performance test suite
add_executable(smallstrategy_performance
    performance/test_small_strategy_graph_performance.cpp
)

target_link_libraries(smallstrategy_performance
    PRIVATE
    atlas_core
    gtest_main
    nlohmann_json::nlohmann_json
)

target_include_directories(smallstrategy_performance
    PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/../include
)

# Register tests with CTest
add_test(NAME UnitTests COMMAND unit_tests)
add_test(NAME IntegrationTests COMMAND integration_tests)
add_test(NAME PerformanceTests COMMAND performance_tests)
add_test(NAME ValidationTests COMMAND validation_tests)
add_test(NAME SmallStrategyComprehensive COMMAND smallstrategy_comprehensive)
add_test(NAME SmallStrategyPerformance COMMAND smallstrategy_performance)

# Copy test data
configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/../../App/Tests/E2E/JSONs/SmallStrategy.json
    ${CMAKE_CURRENT_BINARY_DIR}/SmallStrategy.json
    COPYONLY
)

configure_file(
    ${CMAKE_CURRENT_SOURCE_DIR}/../../App/Tests/E2E/ExpectedFiles/SmallStrategy.json
    ${CMAKE_CURRENT_BINARY_DIR}/ExpectedSmallStrategy.json
    COPYONLY
)