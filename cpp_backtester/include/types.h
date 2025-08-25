#pragma once

#include <vector>
#include <string>
#include <memory>
#include <unordered_map>

namespace atlas {

// Forward declarations
class StockInfo;
class DayData;
class CacheData;
class SubtreeContext;

/**
 * @brief Represents a stock with its ticker and weight for portfolio allocation
 * Equivalent to Julia's StockInfo struct
 */
class StockInfo {
public:
    StockInfo() = default;
    StockInfo(const std::string& ticker, float weight_tomorrow);
    
    // Getters
    const std::string& ticker() const { return ticker_; }
    float weight_tomorrow() const { return weight_tomorrow_; }
    
    // Setters
    void set_ticker(const std::string& ticker) { ticker_ = ticker; }
    void set_weight_tomorrow(float weight) { weight_tomorrow_ = weight; }
    
    // Equality comparison
    bool operator==(const StockInfo& other) const;
    bool operator!=(const StockInfo& other) const;

private:
    std::string ticker_;
    float weight_tomorrow_{0.0f};
};

/**
 * @brief Represents portfolio data for a single day
 * Equivalent to Julia's DayData struct
 */
class DayData {
public:
    DayData() = default;
    explicit DayData(std::vector<StockInfo> stock_list);
    
    // Getters
    const std::vector<StockInfo>& stock_list() const { return stock_list_; }
    std::vector<StockInfo>& stock_list() { return stock_list_; }
    
    // Utility methods
    void add_stock(const StockInfo& stock);
    void clear();
    size_t size() const { return stock_list_.size(); }
    bool empty() const { return stock_list_.empty(); }
    
    // Equality comparison
    bool operator==(const DayData& other) const;
    bool operator!=(const DayData& other) const;

private:
    std::vector<StockInfo> stock_list_;
};

/**
 * @brief Cache data structure for optimization
 * Equivalent to Julia's CacheData struct
 */
class CacheData {
public:
    CacheData() = default;
    CacheData(std::unordered_map<std::string, std::vector<float>> response,
              int uncalculated_days, bool cache_present);
    
    // Getters
    const std::unordered_map<std::string, std::vector<float>>& response() const { return response_; }
    int uncalculated_days() const { return uncalculated_days_; }
    bool cache_present() const { return cache_present_; }
    
    // Setters
    void set_response(const std::unordered_map<std::string, std::vector<float>>& response);
    void set_uncalculated_days(int days) { uncalculated_days_ = days; }
    void set_cache_present(bool present) { cache_present_ = present; }

private:
    std::unordered_map<std::string, std::vector<float>> response_;
    int uncalculated_days_{0};
    bool cache_present_{false};
};

/**
 * @brief Context for subtree processing
 * Equivalent to Julia's SubtreeContext struct
 */
class SubtreeContext {
public:
    SubtreeContext() = default;
    SubtreeContext(int backtest_period,
                   std::vector<DayData> profile_history,
                   std::unordered_map<std::string, int> flow_count,
                   std::unordered_map<std::string, std::vector<DayData>> flow_stocks,
                   std::vector<std::string> trading_dates,
                   std::vector<bool> active_mask,
                   int common_data_span);
    
    // Getters
    int backtest_period() const { return backtest_period_; }
    const std::vector<DayData>& profile_history() const { return profile_history_; }
    const std::unordered_map<std::string, int>& flow_count() const { return flow_count_; }
    const std::unordered_map<std::string, std::vector<DayData>>& flow_stocks() const { return flow_stocks_; }
    const std::vector<std::string>& trading_dates() const { return trading_dates_; }
    const std::vector<bool>& active_mask() const { return active_mask_; }
    int common_data_span() const { return common_data_span_; }
    
    // Mutable getters for modification
    std::vector<DayData>& profile_history() { return profile_history_; }
    std::unordered_map<std::string, int>& flow_count() { return flow_count_; }
    std::unordered_map<std::string, std::vector<DayData>>& flow_stocks() { return flow_stocks_; }
    std::vector<bool>& active_mask() { return active_mask_; }

private:
    int backtest_period_{0};
    std::vector<DayData> profile_history_;
    std::unordered_map<std::string, int> flow_count_;
    std::unordered_map<std::string, std::vector<DayData>> flow_stocks_;
    std::vector<std::string> trading_dates_;
    std::vector<bool> active_mask_;
    int common_data_span_{0};
};

} // namespace atlas