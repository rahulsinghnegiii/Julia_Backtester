cmake_minimum_required(VERSION 3.20)
project(AtlasBacktester VERSION 1.0.0 LANGUAGES CXX)

# Set C++ standard
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Enable testing
enable_testing()

# Compiler-specific options
if(MSVC)
    add_compile_options(/W4 /WX)
else()
    add_compile_options(-Wall -Wextra -Wpedantic -Werror)
endif()

# Build type configuration
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
endif()

# Find or fetch required packages
find_package(Threads REQUIRED)

# Fetch nlohmann_json if not found
find_package(nlohmann_json QUIET)
if(NOT nlohmann_json_FOUND)
    include(FetchContent)
    FetchContent_Declare(
        nlohmann_json
        URL https://github.com/nlohmann/json/releases/download/v3.11.3/json.tar.xz
    )
    FetchContent_MakeAvailable(nlohmann_json)
endif()

# Add subdirectories
add_subdirectory(src)
add_subdirectory(tests)

# Main executable
add_executable(atlas_backtester
    src/main.cpp
)

target_link_libraries(atlas_backtester
    PRIVATE
    atlas_core
    nlohmann_json::nlohmann_json
    Threads::Threads
)

# Enhanced SmallStrategy validator
add_executable(enhanced_small_strategy_validator
    enhanced_small_strategy_validator.cpp
)

target_link_libraries(enhanced_small_strategy_validator
    PRIVATE
    atlas_core
    nlohmann_json::nlohmann_json
    Threads::Threads
)

target_include_directories(enhanced_small_strategy_validator
    PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

# SmallStrategy validator with JSON output
add_executable(small_strategy_validator
    small_strategy_validator.cpp
)

target_include_directories(small_strategy_validator
    PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

# Installation
install(TARGETS atlas_backtester
    RUNTIME DESTINATION bin
)

# CPack configuration
set(CPACK_PACKAGE_NAME "AtlasBacktester")
set(CPACK_PACKAGE_VERSION ${PROJECT_VERSION})
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "High-performance financial backtesting engine")
include(CPack)