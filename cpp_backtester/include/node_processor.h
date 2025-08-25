#pragma once

#include \"types.h\"
#include \"strategy_parser.h\"
#include <vector>
#include <unordered_map>
#include <string>

namespace atlas {

/**
 * @brief Result of node processing
 */
struct NodeResult {
    int processed_days;
    bool success;
    std::string error_message;
    
    NodeResult() : processed_days(0), success(false) {}
    NodeResult(int days, bool success, const std::string& error = \"\")
        : processed_days(days), success(success), error_message(error) {}
};

/**
 * @brief Base class for all node processors
 * Equivalent to Julia's node processing functions
 */
class NodeProcessor {
public:
    virtual ~NodeProcessor() = default;
    
    /**
     * @brief Process a node in the strategy tree
     * @param node Strategy node to process
     * @param active_mask Boolean mask of active days
     * @param total_days Total number of days in the backtest
     * @param node_weight Weight of this node in the portfolio
     * @param portfolio_history History of portfolio data
     * @param date_range Range of dates for the backtest
     * @param flow_count Flow count tracking
     * @param flow_stocks Flow stocks tracking
     * @param indicator_cache Cache for technical indicators
     * @param price_cache Cache for price data
     * @param strategy Strategy root for context
     * @param live_execution Whether this is live execution
     * @param global_cache_length Global cache length
     * @return Result of node processing
     */
    virtual NodeResult process(
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
    ) = 0;
    
    /**
     * @brief Get the node type this processor handles
     * @return Node type string
     */
    virtual std::string get_node_type() const = 0;
    
protected:
    /**
     * @brief Validate common node requirements
     * @param node Node to validate
     * @return true if valid, false otherwise
     */
    virtual bool validate_node(const StrategyNode& node) const;
    
    /**
     * @brief Increment flow count for a hash
     * @param flow_count Flow count map
     * @param hash Hash to increment
     */
    void increment_flow_count(std::unordered_map<std::string, int>& flow_count, const std::string& hash);
    
    /**
     * @brief Set flow stocks for a hash
     * @param flow_stocks Flow stocks map
     * @param portfolio_history Portfolio history
     * @param hash Hash to set
     */
    void set_flow_stocks(
        std::unordered_map<std::string, std::vector<DayData>>& flow_stocks,
        const std::vector<DayData>& portfolio_history,
        const std::string& hash
    );
};

/**
 * @brief Exception for node processing errors
 */
class NodeProcessingError : public std::exception {
public:
    explicit NodeProcessingError(const std::string& message) : message_(message) {}
    const char* what() const noexcept override { return message_.c_str(); }
    
private:
    std::string message_;
};

} // namespace atlas