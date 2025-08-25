#pragma once

#include \"node_processor.h\"
#include <vector>
#include <string>
#include <unordered_map>
#include <tuple>

namespace atlas {

/**
 * @brief Selection function types for sorting
 */
enum class SelectFunction {
    TOP,     // Select top N items
    BOTTOM   // Select bottom N items
};

/**
 * @brief Sort functions for ranking criteria
 */
enum class SortFunction {
    RELATIVE_STRENGTH_INDEX,        // RSI
    SIMPLE_MOVING_AVERAGE,          // SMA
    EXPONENTIAL_MOVING_AVERAGE,     // EMA
    STANDARD_DEVIATION_RETURN,      // Std dev of returns
    MOVING_AVERAGE_RETURN,          // Moving avg of returns
    CURRENT_PRICE,                  // Current price
    PORTFOLIO_RETURN                // Portfolio return
};

/**
 * @brief Processor for sort nodes (ranking and selection)
 * Equivalent to Julia's SortNode.jl functionality
 */
class SortNodeProcessor : public NodeProcessor {
public:
    SortNodeProcessor() = default;
    
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
    
    std::string get_node_type() const override { return \"Sort\"; }
    
private:
    /**
     * @brief Validate sort node structure
     * @param node Sort node to validate
     * @return true if valid, false otherwise
     */
    bool validate_sort_node(const StrategyNode& node) const;
    
    /**
     * @brief Extract and validate selection properties (select function and count)
     * @param properties Node properties
     * @param select_function Output: selection function
     * @param selection_count Output: number of items to select
     * @return true if valid, false otherwise
     */
    bool parse_select_properties(
        const nlohmann::json& properties,
        SelectFunction& select_function,
        int& selection_count
    ) const;
    
    /**
     * @brief Extract and validate sort properties (sort function and window)
     * @param properties Node properties
     * @param sort_function Output: sort function
     * @param sort_window Output: sort window size
     * @return true if valid, false otherwise
     */
    bool parse_sort_properties(
        const nlohmann::json& properties,
        SortFunction& sort_function,
        int& sort_window
    ) const;
    
    /**
     * @brief Process all branches and collect portfolio data
     * @param branches Branch definitions from node
     * @param branch_keys Keys of branches to process
     * @param total_days Total number of days
     * @param node_weight Weight for nodes
     * @param date_range Date range for processing
     * @param flow_count Flow count tracking
     * @param flow_stocks Flow stocks tracking
     * @param indicator_cache Indicator cache
     * @param price_cache Price cache
     * @param strategy Strategy context
     * @param live_execution Live execution flag
     * @param global_cache_length Global cache length
     * @return Tuple of (temp portfolio vectors, min data length)
     */
    std::tuple<std::vector<std::vector<DayData>>, int> process_branches(
        const nlohmann::json& branches,
        const std::vector<std::string>& branch_keys,
        int total_days,
        float node_weight,
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
     * @brief Calculate metrics for each branch based on sort function
     * @param temp_portfolio_vectors Portfolio data for each branch
     * @param date_range Date range
     * @param sort_function Sort function to apply
     * @param sort_window Window size for calculations
     * @param indicator_cache Indicator cache
     * @param price_cache Price cache
     * @param live_execution Live execution flag
     * @return Vector of metrics for each branch (one metric per day)
     */
    std::vector<std::vector<float>> calculate_branch_metrics(
        const std::vector<std::vector<DayData>>& temp_portfolio_vectors,
        const std::vector<std::string>& date_range,
        SortFunction sort_function,
        int sort_window,
        std::unordered_map<std::string, std::vector<float>>& indicator_cache,
        std::unordered_map<std::string, std::vector<float>>& price_cache,
        bool live_execution
    );
    
    /**
     * @brief Calculate selection indices based on metrics and selection criteria
     * @param branch_metrics Metrics for each branch
     * @param active_mask Active days mask
     * @param data_span Data span
     * @param select_function Selection function (top/bottom)
     * @param selection_count Number of items to select
     * @param node Sort node for flow count
     * @param flow_count Flow count tracking
     * @return Selection indices for each day
     */
    std::vector<std::vector<int>> calculate_selection_indices(
        const std::vector<std::vector<float>>& branch_metrics,
        const std::vector<bool>& active_mask,
        int data_span,
        SelectFunction select_function,
        int selection_count,
        const StrategyNode& node,
        std::unordered_map<std::string, int>& flow_count
    );
    
    /**
     * @brief Update portfolio history with selected branches
     * @param portfolio_history Main portfolio history to update
     * @param temp_portfolio_vectors Temporary portfolio data for each branch
     * @param selection_indices Selected branch indices for each day
     * @param node_weight Weight for this node
     * @param common_data_span Data span
     * @param selection_count Number of selected items
     */
    void update_portfolio_history(
        std::vector<DayData>& portfolio_history,
        const std::vector<std::vector<DayData>>& temp_portfolio_vectors,
        const std::vector<std::vector<int>>& selection_indices,
        float node_weight,
        int common_data_span,
        int selection_count
    );
    
    /**
     * @brief Calculate RSI for a given price series
     * @param prices Price data
     * @param period RSI period
     * @return RSI values
     */
    std::vector<float> calculate_rsi(const std::vector<float>& prices, int period);
    
    /**
     * @brief Calculate Simple Moving Average
     * @param values Input values
     * @param period SMA period
     * @return SMA values
     */
    std::vector<float> calculate_sma(const std::vector<float>& values, int period);
    
    /**
     * @brief Calculate Exponential Moving Average
     * @param values Input values
     * @param period EMA period
     * @return EMA values
     */
    std::vector<float> calculate_ema(const std::vector<float>& values, int period);
    
    /**
     * @brief Calculate portfolio returns from DayData
     * @param portfolio_data Portfolio data for multiple days
     * @param price_cache Price cache for stock prices
     * @return Portfolio return values
     */
    std::vector<float> calculate_portfolio_returns(
        const std::vector<DayData>& portfolio_data,
        std::unordered_map<std::string, std::vector<float>>& price_cache
    );
    
    /**
     * @brief Parse sort function string to enum
     * @param sort_function_str Sort function string
     * @return Sort function enum
     */
    SortFunction parse_sort_function(const std::string& sort_function_str);
    
    /**
     * @brief Parse select function string to enum
     * @param select_function_str Select function string
     * @return Select function enum
     */
    SelectFunction parse_select_function(const std::string& select_function_str);
    
    /**
     * @brief Get branches from sort node
     * @param node Sort node
     * @return Pair of (branches JSON, has_folder_node flag)
     */
    std::pair<nlohmann::json, bool> get_branches(const StrategyNode& node);
};

/**
 * @brief Exception for sort node processing errors
 */
class SortNodeError : public NodeProcessingError {
public:
    explicit SortNodeError(const std::string& message) 
        : NodeProcessingError(\"Sort node error: \" + message) {}
};

} // namespace atlas