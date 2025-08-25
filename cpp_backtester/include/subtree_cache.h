#pragma once

#include "types.h"
#include <string>
#include <vector>
#include <memory>
#include <cstdint>
#include <array>

namespace atlas {

/**
 * @brief Packed portfolio entry for efficient storage
 * Equivalent to Julia's PortfolioEntry struct
 */
struct PortfolioEntry {
    uint32_t date;      // Packed date representation (YYYYMMDD)
    std::array<char, 8> ticker;  // Fixed-size ticker (null-terminated)
    float weight;
    
    PortfolioEntry() = default;
    PortfolioEntry(uint32_t d, const std::string& t, float w);
    
    // Helper methods
    std::string get_ticker() const;
    void set_ticker(const std::string& ticker_str);
};

/**
 * @brief Subtree cache for portfolio history
 * Equivalent to Julia's SubtreeCache.jl functionality
 */
class SubtreeCache {
public:
    SubtreeCache();
    ~SubtreeCache() = default;
    
    /**
     * @brief Write portfolio history to memory-mapped file
     * @param date_range Vector of date strings
     * @param end_date End date string
     * @param hash Node hash for cache key
     * @param common_data_span Number of days to write
     * @param portfolio_history Portfolio history data
     * @param live_execution Live execution flag
     * @return true if successful
     */
    bool write_subtree_portfolio_mmap(
        const std::vector<std::string>& date_range,
        const std::string& end_date,
        const std::string& hash,
        int common_data_span,
        const std::vector<DayData>& portfolio_history,
        bool live_execution = false
    );
    
    /**
     * @brief Append portfolio history to existing memory-mapped file
     * @param date_range Vector of date strings
     * @param end_date End date string
     * @param hash Node hash for cache key
     * @param common_data_span Number of days to append
     * @param portfolio_history Portfolio history data
     * @param live_execution Live execution flag
     * @return true if successful
     */
    bool append_subtree_portfolio_mmap(
        const std::vector<std::string>& date_range,
        const std::string& end_date,
        const std::string& hash,
        int common_data_span,
        const std::vector<DayData>& portfolio_history,
        bool live_execution = false
    );
    
    /**
     * @brief Read portfolio history from memory-mapped file
     * @param hash Node hash for cache key
     * @param end_date End date string
     * @return Pair of portfolio history and last date, nullptr if not found
     */
    std::pair<std::unique_ptr<std::vector<DayData>>, std::string> read_subtree_portfolio_mmap(
        const std::string& hash,
        const std::string& end_date
    );
    
    /**
     * @brief Read portfolio history with dates from memory-mapped file
     * @param hash Node hash for cache key
     * @param end_date End date string
     * @return Tuple of portfolio history, dates, and last date
     */
    std::tuple<std::unique_ptr<std::vector<DayData>>, std::unique_ptr<std::vector<std::string>>, std::string>
    read_subtree_portfolio_with_dates_mmap(
        const std::string& hash,
        const std::string& end_date
    );
    
    /**
     * @brief Set portfolio history from subtree cache data
     * @param portfolio_history Target portfolio history to update
     * @param subtree_portfolio_history Source subtree portfolio data
     * @param active_mask Boolean mask for active days
     * @param node_weight Weight to apply to stocks
     * @param common_data_span Number of days to process
     */
    void set_portfolio_history(
        std::vector<DayData>& portfolio_history,
        const std::vector<DayData>& subtree_portfolio_history,
        const std::vector<bool>& active_mask,
        float node_weight,
        int common_data_span
    );
    
    /**
     * @brief Clear cache for specific hash
     * @param hash Cache key to clear
     * @return true if successful
     */
    bool clear_cache(const std::string& hash);
    
    /**
     * @brief Clear all cached data
     * @return true if successful
     */
    bool clear_all_cache();
    
    /**
     * @brief Get cache size for specific hash
     * @param hash Cache key
     * @return Size in bytes, 0 if not found
     */
    size_t get_cache_size(const std::string& hash) const;
    
    /**
     * @brief Set cache directory
     * @param cache_dir Directory path for cache files
     */
    void set_cache_directory(const std::string& cache_dir);
    
    /**
     * @brief Get current cache directory
     * @return Cache directory path
     */
    const std::string& get_cache_directory() const { return cache_dir_; }
    
private:
    std::string cache_dir_;
    
    // Date conversion utilities (equivalent to Julia's date2int/int2date)
    uint32_t date_to_int(const std::string& date_str) const;
    std::string int_to_date(uint32_t date_int) const;
    
    // File path utilities
    std::string get_mmap_file_path(const std::string& hash) const;
    std::string get_parquet_file_path(const std::string& hash) const;
    
    // Memory mapping utilities
    bool create_cache_directory() const;
    size_t calculate_file_size(const std::string& file_path) const;
    
    // Data conversion utilities
    std::vector<PortfolioEntry> convert_to_portfolio_entries(
        const std::vector<std::string>& date_range,
        const std::string& end_date,
        int common_data_span,
        const std::vector<DayData>& portfolio_history,
        bool live_execution
    ) const;
    
    std::vector<DayData> convert_from_portfolio_entries(
        const std::vector<PortfolioEntry>& entries
    ) const;
    
    // File I/O utilities
    bool write_entries_to_file(const std::string& file_path, const std::vector<PortfolioEntry>& entries);
    bool append_entries_to_file(const std::string& file_path, const std::vector<PortfolioEntry>& entries);
    std::unique_ptr<std::vector<PortfolioEntry>> read_entries_from_file(
        const std::string& file_path, const std::string& end_date) const;
    
    // Validation utilities
    bool validate_portfolio_entry(const PortfolioEntry& entry) const;
    bool validate_date_string(const std::string& date_str) const;
};

/**
 * @brief Exception for subtree cache errors
 */
class SubtreeCacheError : public std::runtime_error {
public:
    explicit SubtreeCacheError(const std::string& message) 
        : std::runtime_error("Subtree cache error: " + message) {}
};

/**
 * @brief RAII cache manager for subtree operations
 */
class SubtreeCacheScope {
public:
    explicit SubtreeCacheScope(SubtreeCache& cache, const std::string& hash) 
        : cache_(cache), hash_(hash) {}
    
    ~SubtreeCacheScope() {
        // Optional: clear cache on destruction
        // cache_.clear_cache(hash_);
    }
    
    SubtreeCache& get_cache() { return cache_; }
    const std::string& get_hash() const { return hash_; }
    
private:
    SubtreeCache& cache_;
    std::string hash_;
};

} // namespace atlas