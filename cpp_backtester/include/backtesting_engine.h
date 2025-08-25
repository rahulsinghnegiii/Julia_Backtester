#pragma once

#include \"types.h\"
#include \"strategy_parser.h\"
#include \"node_processor.h\"
#include <memory>
#include <unordered_map>
#include <chrono>

namespace atlas {

/**
 * @brief Result of backtesting execution
 */
struct BacktestResult {
    std::vector<DayData> portfolio_history;
    std::unordered_map<std::string, int> flow_count;
    std::unordered_map<std::string, std::vector<DayData>> flow_stocks;
    bool success;
    std::string error_message;
    std::chrono::milliseconds execution_time;
    
    BacktestResult() : success(false), execution_time(0) {}
};

/**
 * @brief Parameters for backtesting execution
 */
struct BacktestParams {
    Strategy strategy;
    int period;
    std::string end_date;
    bool live_execution;
    int global_cache_length;
    
    BacktestParams() : period(0), live_execution(false), global_cache_length(0) {}
};

/**
 * @brief Main backtesting engine
 * Equivalent to Julia's Main.jl functionality
 */
class BacktestingEngine {
public:
    BacktestingEngine();
    ~BacktestingEngine() = default;
    
    /**
     * @brief Execute backtest for a strategy
     * @param params Backtesting parameters
     * @return Backtest results
     */
    BacktestResult execute_backtest(const BacktestParams& params);
    
    /**
     * @brief Handle backtesting API request (equivalent to Julia's handle_backtesting_api)
     * @param json_request JSON request string
     * @return JSON response string
     */
    std::string handle_backtesting_api(const std::string& json_request);
    
    /**
     * @brief Post-order DFS traversal (equivalent to Julia's post_order_dfs)
     * @param node Current node to process
     * @param active_mask Boolean mask of active days
     * @param common_data_span Data span
     * @param node_weight Weight of the node
     * @param portfolio_history Portfolio history
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
    int post_order_dfs(
        const StrategyNode& node,
        std::vector<bool>& active_mask,
        int common_data_span,
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
    );
    
private:
    // Node processors
    std::unordered_map<std::string, std::unique_ptr<NodeProcessor>> processors_;
    
    // Strategy parser
    StrategyParser parser_;
    
    /**
     * @brief Initialize node processors
     */
    void initialize_processors();
    
    /**
     * @brief Generate date range for backtest
     * @param period Number of days
     * @param end_date End date string
     * @param live_execution Live execution flag
     * @return Vector of date strings
     */
    std::vector<std::string> generate_date_range(
        int period, 
        const std::string& end_date, 
        bool live_execution
    );
    
    /**
     * @brief Initialize portfolio history
     * @param period Number of days
     * @return Vector of empty DayData
     */
    std::vector<DayData> initialize_portfolio_history(int period);
    
    /**
     * @brief Process folder node
     * @param node Folder node
     * @param active_mask Active mask
     * @param common_data_span Data span
     * @param node_weight Node weight
     * @param portfolio_history Portfolio history
     * @param date_range Date range
     * @param flow_count Flow count
     * @param flow_stocks Flow stocks
     * @param indicator_cache Indicator cache
     * @param price_cache Price cache
     * @param strategy Strategy
     * @param live_execution Live execution
     * @param global_cache_length Global cache length
     * @return Processed days
     */
    int process_folder_node(
        const StrategyNode& node,
        std::vector<bool>& active_mask,
        int common_data_span,
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
     * @brief Validate backtest parameters
     * @param params Parameters to validate
     * @return true if valid
     */
    bool validate_params(const BacktestParams& params) const;
};

} // namespace atlas