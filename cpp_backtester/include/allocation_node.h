#pragma once

#include \"node_processor.h\"
#include <vector>
#include <string>
#include <unordered_map>

namespace atlas {

/**
 * @brief Allocation function types
 */
enum class AllocationFunction {
    EQUAL_ALLOCATION,       // Equal weight allocation
    INVERSE_VOLATILITY,     // Inverse volatility weighting
    MARKET_CAP,             // Market cap weighting
    ALLOCATION              // Manual allocation
};

/**
 * @brief Processor for allocation nodes (portfolio weighting)
 * Equivalent to Julia's AllocationNode.jl functionality
 */
class AllocationNodeProcessor : public NodeProcessor {
public:
    AllocationNodeProcessor() = default;
    
    NodeResult process(
        const StrategyNode& node,
        std::vector<bool>& active_mask,
        int total_days,
        float node_weight,
        std::vector<DayData>& portfolio_history,
        const std::vector<std::string>& date_range,
        std::unordered_map<std::string, int>& flow_count,
        std::unordered_map<std::string, std::vector<DayData>>& flow_stocks,
        std::unordered_map<std::string, std::vector<float>>& indicator_cache,
        std::unordered_map<std::string, std::vector<float>>& price_cache,
        const Strategy& strategy,
        bool live_execution = false,
        int global_cache_length = 0
    ) override;
    
    std::string get_node_type() const override { return \"allocation\"; }
    
private:
    /**
     * @brief Validate allocation node structure
     * @param node Allocation node to validate
     * @return true if valid, false otherwise
     */
    bool validate_allocation_node(const StrategyNode& node) const;
    
    /**
     * @brief Parse allocation function from node properties
     * @param properties Node properties
     * @return Allocation function enum
     */
    AllocationFunction parse_allocation_function(const nlohmann::json& properties) const;
    
    /**
     * @brief Process equal allocation
     * @param node Allocation node
     * @param active_mask Active days mask
     * @param total_days Total number of days
     * @param node_weight Node weight
     * @param portfolio_history Portfolio history to update
     * @param date_range Date range
     * @param flow_count Flow count tracking
     * @param flow_stocks Flow stocks tracking
     * @param strategy Strategy context
     * @param live_execution Live execution flag
     * @param global_cache_length Global cache length
     * @return Number of processed days
     */
    int process_equal_allocation(
        const StrategyNode& node,
        std::vector<bool>& active_mask,
        int total_days,
        float node_weight,
        std::vector<DayData>& portfolio_history,
        const std::vector<std::string>& date_range,
        std::unordered_map<std::string, int>& flow_count,
        std::unordered_map<std::string, std::vector<DayData>>& flow_stocks,
        const Strategy& strategy,
        bool live_execution,
        int global_cache_length
    );
    
    /**
     * @brief Process inverse volatility allocation
     * @param node Allocation node
     * @param active_mask Active days mask
     * @param total_days Total number of days
     * @param node_weight Node weight
     * @param portfolio_history Portfolio history to update
     * @param date_range Date range
     * @param flow_count Flow count tracking
     * @param flow_stocks Flow stocks tracking
     * @param indicator_cache Indicator cache
     * @param price_cache Price cache
     * @param strategy Strategy context
     * @param live_execution Live execution flag
     * @param global_cache_length Global cache length
     * @return Number of processed days
     */
    int process_inverse_volatility(
        const StrategyNode& node,
        std::vector<bool>& active_mask,
        int total_days,
        float node_weight,
        std::vector<DayData>& portfolio_history,
        const std::vector<std::string>& date_range,
        std::unordered_map<std::string, int>& flow_count,
        std::unordered_map<std::string, std::vector<DayData>>& flow_stocks,
        std::unordered_map<std::string, std::vector<float>>& indicator_cache,
        std::unordered_map<std::string, std::vector<float>>& price_cache,
        const Strategy& strategy,
        bool live_execution,
        int global_cache_length
    );
    
    /**
     * @brief Process market cap allocation
     * @param node Allocation node
     * @param active_mask Active days mask
     * @param total_days Total number of days
     * @param node_weight Node weight
     * @param portfolio_history Portfolio history to update
     * @param date_range Date range
     * @param flow_count Flow count tracking
     * @param flow_stocks Flow stocks tracking
     * @param indicator_cache Indicator cache
     * @param price_cache Price cache
     * @param strategy Strategy context
     * @param live_execution Live execution flag
     * @return Number of processed days
     */
    int process_market_cap(
        const StrategyNode& node,
        std::vector<bool>& active_mask,
        int total_days,
        float node_weight,
        std::vector<DayData>& portfolio_history,
        const std::vector<std::string>& date_range,
        std::unordered_map<std::string, int>& flow_count,
        std::unordered_map<std::string, std::vector<DayData>>& flow_stocks,
        std::unordered_map<std::string, std::vector<float>>& indicator_cache,
        std::unordered_map<std::string, std::vector<float>>& price_cache,
        const Strategy& strategy,
        bool live_execution
    );
    
    /**
     * @brief Calculate volatility for stocks in portfolio
     * @param portfolio_history Portfolio history
     * @param period Volatility calculation period
     * @param price_cache Price cache
     * @return Map of ticker to volatility
     */
    std::unordered_map<std::string, float> calculate_volatilities(
        const std::vector<DayData>& portfolio_history,
        int period,
        std::unordered_map<std::string, std::vector<float>>& price_cache
    );
    
    /**
     * @brief Get market cap data for stocks
     * @param tickers List of stock tickers
     * @return Map of ticker to market cap
     */
    std::unordered_map<std::string, float> get_market_caps(
        const std::vector<std::string>& tickers
    );
    
    /**
     * @brief Apply allocation weights to portfolio
     * @param portfolio_history Portfolio history to update
     * @param weights Map of ticker to weight
     * @param active_mask Active days mask
     * @param total_days Total number of days
     * @param node_weight Overall node weight
     */
    void apply_allocation_weights(
        std::vector<DayData>& portfolio_history,
        const std::unordered_map<std::string, float>& weights,
        const std::vector<bool>& active_mask,
        int total_days,
        float node_weight
    );
    
    /**
     * @brief Calculate price returns for volatility calculation
     * @param prices Vector of prices
     * @return Vector of returns
     */
    std::vector<float> calculate_returns(const std::vector<float>& prices);
    
    /**
     * @brief Calculate standard deviation of returns
     * @param returns Vector of returns
     * @return Standard deviation
     */
    float calculate_volatility(const std::vector<float>& returns);
    
    /**
     * @brief Process child nodes of allocation node
     * @param node Allocation node with children
     * @param active_mask Active days mask
     * @param total_days Total number of days
     * @param node_weight Node weight
     * @param portfolio_history Portfolio history to update
     * @param date_range Date range
     * @param flow_count Flow count tracking
     * @param flow_stocks Flow stocks tracking
     * @param indicator_cache Indicator cache
     * @param price_cache Price cache
     * @param strategy Strategy context
     * @param live_execution Live execution flag
     * @param global_cache_length Global cache length
     * @return Number of processed days
     */
    int process_children(
        const StrategyNode& node,
        std::vector<bool>& active_mask,
        int total_days,
        float node_weight,
        std::vector<DayData>& portfolio_history,
        const std::vector<std::string>& date_range,
        std::unordered_map<std::string, int>& flow_count,
        std::unordered_map<std::string, std::vector<DayData>>& flow_stocks,
        std::unordered_map<std::string, std::vector<float>>& indicator_cache,
        std::unordered_map<std::string, std::vector<float>>& price_cache,
        const Strategy& strategy,
        bool live_execution,
        int global_cache_length
    );
};

/**
 * @brief Exception for allocation node processing errors
 */
class AllocationNodeError : public NodeProcessingError {
public:
    explicit AllocationNodeError(const std::string& message) 
        : NodeProcessingError(\"Allocation node error: \" + message) {}
};

} // namespace atlas