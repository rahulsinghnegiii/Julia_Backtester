# Atlas Core Library
add_library(atlas_core STATIC
    # Core data structures
    core/types.cpp
    core/stock_info.cpp
    core/day_data.cpp
    core/cache_data.cpp
    core/subtree_context.cpp
    
    # Node processors
    nodes/node_processor.cpp
    nodes/stock_node.cpp
    nodes/conditional_node.cpp
    nodes/sort_node.cpp
    allocation_node.cpp
    
    # Engine components
    engine/backtesting_engine.cpp
    engine/strategy_parser.cpp
    
    # Cache system
    cache/global_cache.cpp
    cache/subtree_cache.cpp
    
    # Technical analysis
    ta/ta_functions.cpp
    
    # Data provider
    data/stock_data_provider.cpp
)

target_include_directories(atlas_core
    PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/../include
    PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
)

target_link_libraries(atlas_core
    PUBLIC
    nlohmann_json::nlohmann_json
    PRIVATE
    Threads::Threads
)

# Enable precompiled headers for faster compilation
target_precompile_headers(atlas_core
    PRIVATE
    <vector>
    <string>
    <memory>
    <unordered_map>
    <nlohmann/json.hpp>
)