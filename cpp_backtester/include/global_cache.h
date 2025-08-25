#pragma once

#include "types.h"
#include <string>
#include <unordered_map>
#include <memory>
#include <vector>
#include <chrono>
#include <nlohmann/json.hpp>

namespace atlas {

/**
 * @brief Cache entry for flow data
 */
struct FlowCacheEntry {
    std::unordered_map<std::string, nlohmann::json> flow_data;
    std::chrono::system_clock::time_point timestamp;
    
    FlowCacheEntry() = default;
    FlowCacheEntry(const std::unordered_map<std::string, nlohmann::json>& data) 
        : flow_data(data), timestamp(std::chrono::system_clock::now()) {}
};

/**
 * @brief Cache entry for results data
 */
struct ResultsCacheEntry {
    std::unordered_map<std::string, std::vector<float>> data;
    std::chrono::system_clock::time_point timestamp;
    
    ResultsCacheEntry() = default;
    ResultsCacheEntry(const std::unordered_map<std::string, std::vector<float>>& results) 
        : data(results), timestamp(std::chrono::system_clock::now()) {}
};

/**
 * @brief Global cache manager for backtesting results and flow data
 * Equivalent to Julia's GlobalCache.jl functionality
 */
class GlobalCache {
public:
    static GlobalCache& instance();
    
    // Flow data caching
    bool cache_flow_data(const std::string& hash, const std::string& end_date, 
                        const std::unordered_map<std::string, nlohmann::json>& flow_data);
    std::unique_ptr<std::unordered_map<std::string, nlohmann::json>> get_cached_flow_data(
        const std::string& hash, const std::string& end_date);
    
    // Results caching
    bool cache_results(const std::string& hash, 
                      const std::unordered_map<std::string, std::vector<float>>& response);
    std::unique_ptr<std::unordered_map<std::string, std::vector<float>>> get_cached_results(
        const std::string& hash);
    
    // Generic data caching
    bool cache_data(const std::string& hash, 
                   const std::unordered_map<std::string, std::vector<float>>& response,
                   const std::string& end_date,
                   const std::unordered_map<std::string, nlohmann::json>& flow_data);
    
    struct CacheDataResult {
        std::unique_ptr<std::unordered_map<std::string, std::vector<float>>> cached_response;
        int uncalculated_days;
        bool cache_present;
    };
    
    CacheDataResult get_cached_data(const std::string& hash, const std::string& end_date, 
                                   bool live_data = false);
    
    // Cache management
    void clear_cache();
    void clear_expired_entries(std::chrono::seconds max_age = std::chrono::seconds(3600));
    size_t get_cache_size() const;
    
    // File-based caching (equivalent to Julia's JSON file operations)
    bool save_cache_to_file(const std::string& cache_dir = "./Cache");
    bool load_cache_from_file(const std::string& cache_dir = "./Cache");
    
private:
    GlobalCache() = default;
    ~GlobalCache() = default;
    GlobalCache(const GlobalCache&) = delete;
    GlobalCache& operator=(const GlobalCache&) = delete;
    
    // Cache storage
    std::unordered_map<std::string, FlowCacheEntry> flow_cache_;
    std::unordered_map<std::string, ResultsCacheEntry> results_cache_;
    
    // Utility methods
    std::string generate_flow_key(const std::string& hash, const std::string& end_date) const;
    bool create_cache_directory(const std::string& path) const;
    std::string get_cache_file_path(const std::string& hash, const std::string& end_date, 
                                   const std::string& suffix = "") const;
    
    // File I/O helpers
    bool write_json_to_file(const std::string& file_path, const nlohmann::json& data) const;
    std::unique_ptr<nlohmann::json> read_json_from_file(const std::string& file_path) const;
    
    // Date utilities
    int get_trading_days(const std::string& symbol, const std::string& start_date, 
                        const std::string& end_date, bool live_data = false) const;
    bool is_date_greater_equal(const std::string& date1, const std::string& date2) const;
};

/**
 * @brief Exception for global cache errors
 */
class GlobalCacheError : public std::runtime_error {
public:
    explicit GlobalCacheError(const std::string& message) 
        : std::runtime_error("Global cache error: " + message) {}
};

/**
 * @brief RAII cache manager for automatic cleanup
 */
class CacheScope {
public:
    explicit CacheScope(GlobalCache& cache) : cache_(cache) {}
    ~CacheScope() { cache_.clear_expired_entries(); }
    
private:
    GlobalCache& cache_;
};

} // namespace atlas