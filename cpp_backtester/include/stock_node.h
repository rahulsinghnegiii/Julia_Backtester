#pragma once

#include \"node_processor.h\"

namespace atlas {

/**
 * @brief Processor for stock nodes
 * Equivalent to Julia's StockNode.jl functionality
 */
class StockNodeProcessor : public NodeProcessor {
public:
    StockNodeProcessor() = default;
    
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
    
    std::string get_node_type() const override { return \"stock\"; }
    
private:
    /**
     * @brief Validate stock node specific requirements
     * @param node Stock node to validate
     * @return true if valid, false otherwise
     */
    bool validate_stock_node(const StrategyNode& node) const;
    
    /**
     * @brief Validate input parameters
     * @param active_mask Active mask
     * @param total_days Total days
     * @param node_weight Node weight
     * @param portfolio_history Portfolio history
     * @return true if valid, false otherwise
     */
    bool validate_inputs(
        const std::vector<bool>& active_mask,
        int total_days,
        float node_weight,
        const std::vector<DayData>& portfolio_history
    ) const;
    
    /**
     * @brief Update portfolio with stock information
     * @param portfolio_history Portfolio history to update
     * @param symbol Stock symbol
     * @param node_weight Weight for the stock
     * @param active_days Days when the stock should be active
     * @param total_days Total days in backtest
     */
    void update_portfolio(
        std::vector<DayData>& portfolio_history,
        const std::string& symbol,
        float node_weight,
        const std::vector<int>& active_days,
        int total_days
    );
    
    /**
     * @brief Find active days from boolean mask
     * @param active_mask Boolean mask
     * @return Vector of active day indices
     */
    std::vector<int> find_active_days(const std::vector<bool>& active_mask) const;
};

} // namespace atlas