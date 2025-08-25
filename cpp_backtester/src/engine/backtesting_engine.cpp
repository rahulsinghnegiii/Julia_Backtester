#include \"backtesting_engine.h\"
#include \"stock_node.h\"
#include \"conditional_node.h\"
#include \"sort_node.h\"
#include \"allocation_node.h\"
#include <algorithm>
#include <stdexcept>
#include <iomanip>
#include <sstream>
#include <nlohmann/json.hpp>

namespace atlas {

BacktestingEngine::BacktestingEngine() {
    initialize_processors();
}

void BacktestingEngine::initialize_processors() {
    processors_[\"stock\"] = std::make_unique<StockNodeProcessor>();
    processors_[\"condition\"] = std::make_unique<ConditionalNodeProcessor>();
    processors_[\"Sort\"] = std::make_unique<SortNodeProcessor>();
    processors_[\"allocation\"] = std::make_unique<AllocationNodeProcessor>();
}

BacktestResult BacktestingEngine::execute_backtest(const BacktestParams& params) {
    auto start_time = std::chrono::high_resolution_clock::now();
    BacktestResult result;
    
    try {
        // Validate parameters
        if (!validate_params(params)) {
            result.error_message = \"Invalid backtest parameters\";
            return result;
        }
        
        // Initialize data structures
        auto date_range = generate_date_range(params.period, params.end_date, params.live_execution);
        auto portfolio_history = initialize_portfolio_history(params.period);
        
        std::vector<bool> active_mask(params.period, true);
        std::unordered_map<std::string, int> flow_count;
        std::unordered_map<std::string, std::vector<DayData>> flow_stocks;
        std::unordered_map<std::string, std::vector<float>> indicator_cache;
        std::unordered_map<std::string, std::vector<float>> price_cache;
        
        // Execute post-order DFS
        int processed_days = post_order_dfs(
            params.strategy.root,
            active_mask,
            params.period,
            1.0f, // Root node weight
            portfolio_history,
            date_range,
            flow_count,
            flow_stocks,
            indicator_cache,
            price_cache,
            params.strategy,
            params.live_execution,
            params.global_cache_length
        );
        
        if (processed_days > 0) {
            result.portfolio_history = std::move(portfolio_history);
            result.flow_count = std::move(flow_count);
            result.flow_stocks = std::move(flow_stocks);
            result.success = true;
        } else {
            result.error_message = \"No days were processed\";
        }
        
    } catch (const std::exception& e) {
        result.error_message = \"Backtest execution error: \" + std::string(e.what());
    }
    
    auto end_time = std::chrono::high_resolution_clock::now();
    result.execution_time = std::chrono::duration_cast<std::chrono::milliseconds>(end_time - start_time);
    
    return result;
}

std::string BacktestingEngine::handle_backtesting_api(const std::string& json_request) {
    try {
        // Parse request
        auto request = nlohmann::json::parse(json_request);
        auto strategy = parser_.parse_strategy(request);
        
        // Create backtest parameters
        BacktestParams params;
        params.strategy = strategy;
        params.period = strategy.period;
        params.end_date = strategy.end_date;
        params.live_execution = false; // Default to historical
        params.global_cache_length = 0; // Default cache length
        
        // Execute backtest
        auto result = execute_backtest(params);
        
        // Create response JSON
        nlohmann::json response;
        response[\"success\"] = result.success;
        response[\"execution_time_ms\"] = result.execution_time.count();
        
        if (result.success) {
            // Convert portfolio history to JSON
            nlohmann::json portfolio_json = nlohmann::json::array();
            for (const auto& day : result.portfolio_history) {
                nlohmann::json day_json = nlohmann::json::array();
                for (const auto& stock : day.stock_list()) {
                    nlohmann::json stock_json;
                    stock_json[\"ticker\"] = stock.ticker();
                    stock_json[\"weight\"] = stock.weight_tomorrow();
                    day_json.push_back(stock_json);
                }
                portfolio_json.push_back(day_json);
            }
            response[\"portfolio_history\"] = portfolio_json;
            response[\"flow_count\"] = result.flow_count;
        } else {
            response[\"error\"] = result.error_message;
        }
        
        return response.dump();
        
    } catch (const std::exception& e) {
        nlohmann::json error_response;
        error_response[\"success\"] = false;
        error_response[\"error\"] = \"API error: \" + std::string(e.what());
        return error_response.dump();
    }
}

int BacktestingEngine::post_order_dfs(
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
) {
    try {
        if (node.type.empty()) {
            throw std::runtime_error(\"Node missing required 'type' field\");
        }
        
        int processed_days = common_data_span;
        
        // Process different node types
        if (node.type == \"stock\") {
            auto processor_it = processors_.find(\"stock\");
            if (processor_it != processors_.end()) {
                auto result = processor_it->second->process(
                    node, active_mask, common_data_span, node_weight,
                    portfolio_history, date_range, flow_count, flow_stocks,
                    indicator_cache, price_cache, strategy, live_execution, global_cache_length
                );
                if (result.success) {
                    processed_days = result.processed_days;
                } else {
                    throw std::runtime_error(\"Stock node processing failed: \" + result.error_message);
                }
            } else {
                throw std::runtime_error(\"No processor found for stock node\");
            }
        }
        else if (node.type == \"condition\") {
            auto processor_it = processors_.find(\"condition\");
            if (processor_it != processors_.end()) {
                auto result = processor_it->second->process(
                    node, active_mask, common_data_span, node_weight,
                    portfolio_history, date_range, flow_count, flow_stocks,
                    indicator_cache, price_cache, strategy, live_execution, global_cache_length
                );
                if (result.success) {
                    processed_days = result.processed_days;
                } else {
                    throw std::runtime_error(\"Conditional node processing failed: \" + result.error_message);
                }
            } else {
                throw std::runtime_error(\"No processor found for conditional node\");
            }
        }
        else if (node.type == \"Sort\") {
            auto processor_it = processors_.find(\"Sort\");
            if (processor_it != processors_.end()) {
                auto result = processor_it->second->process(
                    node, active_mask, common_data_span, node_weight,
                    portfolio_history, date_range, flow_count, flow_stocks,
                    indicator_cache, price_cache, strategy, live_execution, global_cache_length
                );
                if (result.success) {
                    processed_days = result.processed_days;
                } else {
                    throw std::runtime_error(\"Sort node processing failed: \" + result.error_message);
                }
            } else {
                throw std::runtime_error(\"No processor found for sort node\");
            }
        }
        else if (node.type == \"allocation\") {
            auto processor_it = processors_.find(\"allocation\");
            if (processor_it != processors_.end()) {
                auto result = processor_it->second->process(
                    node, active_mask, common_data_span, node_weight,
                    portfolio_history, date_range, flow_count, flow_stocks,
                    indicator_cache, price_cache, strategy, live_execution, global_cache_length
                );
                if (result.success) {
                    processed_days = result.processed_days;
                } else {
                    throw std::runtime_error(\"Allocation node processing failed: \" + result.error_message);
                }
            } else {
                throw std::runtime_error(\"No processor found for allocation node\");
            }
        }
        else if (node.type == \"folder\" || node.type == \"root\") {
            processed_days = process_folder_node(
                node, active_mask, common_data_span, node_weight,
                portfolio_history, date_range, flow_count, flow_stocks,
                indicator_cache, price_cache, strategy, live_execution, global_cache_length
            );
        }
        else {
            throw std::runtime_error(\"Unknown node type: \" + node.type);
        }
        
        return processed_days;
        
    } catch (const std::exception& e) {
        throw std::runtime_error(\"Post-order DFS error: \" + std::string(e.what()));
    }
}

int BacktestingEngine::process_folder_node(
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
) {
    // Increment flow count if hash exists
    if (!node.hash.empty()) {
        flow_count[node.hash]++;
    }
    
    int folder_node_span = common_data_span;
    
    // Count non-comment nodes
    int nodes_length = 0;
    for (const auto& seq_node : node.sequence) {
        if (seq_node.type != \"comment\") {
            nodes_length++;
        }
    }
    
    // Process each child node
    for (const auto& seq_node : node.sequence) {
        if (seq_node.type != \"comment\") {
            float child_weight = nodes_length > 0 ? node_weight / nodes_length : node_weight;
            
            folder_node_span = post_order_dfs(
                seq_node,
                active_mask,
                common_data_span,
                child_weight,
                portfolio_history,
                date_range,
                flow_count,
                flow_stocks,
                indicator_cache,
                price_cache,
                strategy,
                live_execution,
                global_cache_length
            );
        }
    }
    
    return folder_node_span;
}

std::vector<std::string> BacktestingEngine::generate_date_range(
    int period,
    const std::string& end_date,
    bool live_execution
) {
    // Simple implementation - just generate consecutive dates
    // In a real implementation, this would handle business days, holidays, etc.
    std::vector<std::string> dates;
    dates.reserve(period);
    
    for (int i = period - 1; i >= 0; --i) {
        std::ostringstream oss;
        oss << end_date << \"-\" << std::setfill('0') << std::setw(3) << i;
        dates.push_back(oss.str());
    }
    
    return dates;
}

std::vector<DayData> BacktestingEngine::initialize_portfolio_history(int period) {
    std::vector<DayData> history;
    history.reserve(period);
    
    for (int i = 0; i < period; ++i) {
        history.emplace_back();
    }
    
    return history;
}

bool BacktestingEngine::validate_params(const BacktestParams& params) const {
    if (params.period <= 0) {
        return false;
    }
    
    if (params.end_date.empty()) {
        return false;
    }
    
    if (params.strategy.root.type.empty()) {
        return false;
    }
    
    return true;
}

} // namespace atlas", "original_text": "", "replace_all": false}]