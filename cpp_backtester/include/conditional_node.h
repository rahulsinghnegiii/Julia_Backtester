#pragma once

#include \"node_processor.h\"
#include <vector>
#include <string>
#include <functional>

namespace atlas {

/**
 * @brief Comparison operators for conditional evaluation
 */
enum class ComparisonOperator {
    GREATER_THAN,      // >
    LESS_THAN,         // <
    EQUAL,             // ==
    GREATER_EQUAL,     // >=
    LESS_EQUAL,        // <=
    NOT_EQUAL          // !=
};

/**
 * @brief Processor for conditional nodes (if/then/else logic)
 * Equivalent to Julia's ConditionalNode.jl functionality
 */
class ConditionalNodeProcessor : public NodeProcessor {
public:
    ConditionalNodeProcessor() = default;
    
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
    
    std::string get_node_type() const override { return \"condition\"; }
    
private:
    /**
     * @brief Validate conditional node structure
     * @param node Conditional node to validate
     * @return true if valid, false otherwise
     */
    bool validate_conditional_node(const StrategyNode& node) const;
    
    /**
     * @brief Validate condition properties (x, y, comparison)
     * @param properties Node properties to validate
     * @return true if valid, false otherwise
     */
    bool validate_condition_properties(const nlohmann::json& properties) const;
    
    /**
     * @brief Evaluate the condition to get boolean result for each day
     * @param node Conditional node with comparison properties
     * @param date_range Date range for evaluation
     * @param total_days Total number of days
     * @param indicator_cache Indicator value cache
     * @param price_cache Price data cache
     * @param strategy Strategy context
     * @param live_execution Live execution flag
     * @return Boolean vector indicating condition result for each day
     */
    std::vector<bool> evaluate_condition(
        const StrategyNode& node,
        const std::vector<std::string>& date_range,
        int total_days,
        std::unordered_map<std::string, std::vector<float>>& indicator_cache,
        std::unordered_map<std::string, std::vector<float>>& price_cache,
        const Strategy& strategy,
        bool live_execution
    );
    
    /**
     * @brief Process a branch (true or false path)
     * @param nodes Vector of nodes in the branch
     * @param active_mask Active days mask for this branch
     * @param total_days Total number of days
     * @param node_weight Weight for this branch
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
    int process_branch(
        const std::vector<StrategyNode>& nodes,
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
     * @brief Get indicator values for condition evaluation
     * @param indicator_def Indicator definition from JSON
     * @param date_range Date range
     * @param total_days Total number of days
     * @param indicator_cache Indicator cache
     * @param price_cache Price cache
     * @param live_execution Live execution flag
     * @return Vector of indicator values
     */
    std::vector<float> get_indicator_value(
        const nlohmann::json& indicator_def,
        const std::vector<std::string>& date_range,
        int total_days,
        std::unordered_map<std::string, std::vector<float>>& indicator_cache,
        std::unordered_map<std::string, std::vector<float>>& price_cache,
        bool live_execution
    );
    
    /**
     * @brief Compare two indicator value vectors
     * @param x First indicator values
     * @param y Second indicator values
     * @param comparison_str Comparison operator as string
     * @return Boolean vector of comparison results
     */
    std::vector<bool> compare_values(
        const std::vector<float>& x,
        const std::vector<float>& y,
        const std::string& comparison_str
    );
    
    /**
     * @brief Parse comparison operator from string
     * @param comparison_str Comparison operator string (\">\", \"<\", \"==\", etc.)
     * @return Comparison operator enum
     */
    ComparisonOperator parse_comparison_operator(const std::string& comparison_str);
    
    /**
     * @brief Align two vectors to the same length (truncate longer one)
     * @param x First vector (modified in place if needed)
     * @param y Second vector (modified in place if needed)
     */
    void align_indicator_lengths(std::vector<float>& x, std::vector<float>& y);
    
    /**
     * @brief Extract branches from conditional node
     * @param node Conditional node
     * @param true_branch Output: true branch nodes
     * @param false_branch Output: false branch nodes
     */
    void extract_branches(
        const StrategyNode& node,
        std::vector<StrategyNode>& true_branch,
        std::vector<StrategyNode>& false_branch
    );
};

/**
 * @brief Exception for conditional node processing errors
 */
class ConditionalNodeError : public NodeProcessingError {
public:
    explicit ConditionalNodeError(const std::string& message) 
        : NodeProcessingError(\"Conditional node error: \" + message) {}
};

/**
 * @brief Exception for condition evaluation errors
 */
class ConditionEvalError : public NodeProcessingError {
public:
    explicit ConditionEvalError(const std::string& message) 
        : NodeProcessingError(\"Condition evaluation error: \" + message) {}
};

} // namespace atlas