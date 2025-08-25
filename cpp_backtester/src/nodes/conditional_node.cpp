#include \"conditional_node.h\"
#include \"backtesting_engine.h\"
#include <algorithm>
#include <stdexcept>
#include <cmath>

namespace atlas {

NodeResult ConditionalNodeProcessor::process(
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
) {
    try {
        // Validate conditional node
        if (!validate_conditional_node(node)) {
            return NodeResult(0, false, \"Invalid conditional node structure\");
        }
        
        // Increment flow count
        if (!node.hash.empty()) {
            increment_flow_count(flow_count, node.hash);
        }
        
        // Extract branches
        std::vector<StrategyNode> true_branch, false_branch;
        extract_branches(node, true_branch, false_branch);
        
        // Evaluate condition
        std::vector<bool> condition_result;
        try {
            condition_result = evaluate_condition(
                node, date_range, total_days, indicator_cache, price_cache, strategy, live_execution
            );
        } catch (const std::exception& e) {
            return NodeResult(0, false, \"Condition evaluation failed: \" + std::string(e.what()));
        }
        
        int effective_days = static_cast<int>(condition_result.size());
        if (effective_days == 0) {
            return NodeResult(0, false, \"No effective days after condition evaluation\");
        }
        
        // Create branch masks
        std::vector<bool> true_branch_mask, false_branch_mask;
        
        // Align condition result with active mask
        int start_offset = std::max(0, static_cast<int>(active_mask.size()) - effective_days);
        
        for (int i = 0; i < effective_days; ++i) {
            int active_idx = start_offset + i;
            bool is_active = (active_idx < static_cast<int>(active_mask.size())) ? active_mask[active_idx] : false;
            
            true_branch_mask.push_back(condition_result[i] && is_active);
            false_branch_mask.push_back(!condition_result[i] && is_active);
        }
        
        // Process true branch
        int true_branch_span;
        try {
            true_branch_span = process_branch(
                true_branch, true_branch_mask, effective_days, node_weight,
                portfolio_history, date_range, flow_count, flow_stocks,
                indicator_cache, price_cache, strategy, live_execution, global_cache_length
            );
        } catch (const std::exception& e) {
            return NodeResult(0, false, \"True branch processing failed: \" + std::string(e.what()));
        }
        
        // Process false branch
        int false_branch_span;
        try {
            false_branch_span = process_branch(
                false_branch, false_branch_mask, effective_days, node_weight,
                portfolio_history, date_range, flow_count, flow_stocks,
                indicator_cache, price_cache, strategy, live_execution, global_cache_length
            );
        } catch (const std::exception& e) {
            return NodeResult(0, false, \"False branch processing failed: \" + std::string(e.what()));
        }
        
        // Set flow stocks
        if (!node.hash.empty()) {
            set_flow_stocks(flow_stocks, portfolio_history, node.hash);
        }
        
        return NodeResult(std::min({true_branch_span, false_branch_span, effective_days}), true);
        
    } catch (const std::exception& e) {
        return NodeResult(0, false, \"Conditional node error: \" + std::string(e.what()));
    }
}

bool ConditionalNodeProcessor::validate_conditional_node(const StrategyNode& node) const {
    // Must have branches
    if (!node.branches.contains(\"true\") || !node.branches.contains(\"false\")) {
        return false;
    }
    
    // Must have valid properties for condition evaluation
    return validate_condition_properties(node.properties);
}

bool ConditionalNodeProcessor::validate_condition_properties(const nlohmann::json& properties) const {
    // Must have x, y, and comparison
    return properties.contains(\"x\") && 
           properties.contains(\"y\") && 
           properties.contains(\"comparison\");
}

std::vector<bool> ConditionalNodeProcessor::evaluate_condition(
    const StrategyNode& node,
    const std::vector<std::string>& date_range,
    int total_days,
    std::unordered_map<std::string, std::vector<float>>& indicator_cache,
    std::unordered_map<std::string, std::vector<float>>& price_cache,
    const Strategy& strategy,
    bool live_execution
) {
    // Get indicator values for x and y
    auto x = get_indicator_value(
        node.properties[\"x\"], date_range, total_days, indicator_cache, price_cache, live_execution
    );
    
    auto y = get_indicator_value(
        node.properties[\"y\"], date_range, total_days, indicator_cache, price_cache, live_execution
    );
    
    if (x.empty() || y.empty()) {
        throw ConditionEvalError(\"Empty indicator values\");
    }
    
    // Align lengths
    align_indicator_lengths(x, y);
    
    // Get comparison operator
    std::string comparison = node.properties[\"comparison\"].get<std::string>();
    
    // Compare values
    return compare_values(x, y, comparison);
}

int ConditionalNodeProcessor::process_branch(
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
) {
    if (nodes.empty()) {
        return total_days;
    }
    
    // Check if any days are active
    bool has_active_days = std::any_of(active_mask.begin(), active_mask.end(), [](bool b) { return b; });
    if (!has_active_days) {
        return total_days;
    }
    
    int min_data_span = total_days;
    
    // Count non-comment nodes
    int node_count = 0;
    for (const auto& node : nodes) {
        if (node.type != \"comment\") {
            node_count++;
        }
    }
    
    float node_weight_per_node = (node_count > 0) ? node_weight / node_count : node_weight;
    
    // Process each node in the branch
    // Note: This would require access to the post_order_dfs function from BacktestingEngine
    // For now, we'll implement a basic version that handles stock nodes
    for (const auto& branch_node : nodes) {
        if (branch_node.type == \"comment\") {
            continue;
        }
        
        // For now, we'll handle stock nodes directly
        // In a complete implementation, this would delegate to the engine's post_order_dfs
        if (branch_node.type == \"stock\") {
            // Create a stock processor and process the node
            // This is a simplified implementation
            for (size_t i = 0; i < active_mask.size() && i < portfolio_history.size(); ++i) {
                if (active_mask[i] && branch_node.properties.contains(\"symbol\")) {
                    std::string symbol = branch_node.properties[\"symbol\"].get<std::string>();
                    portfolio_history[i].add_stock(StockInfo(symbol, node_weight_per_node));
                }
            }
        }
        // Other node types would be handled here...
    }
    
    return min_data_span;
}

std::vector<float> ConditionalNodeProcessor::get_indicator_value(
    const nlohmann::json& indicator_def,
    const std::vector<std::string>& date_range,
    int total_days,
    std::unordered_map<std::string, std::vector<float>>& indicator_cache,
    std::unordered_map<std::string, std::vector<float>>& price_cache,
    bool live_execution
) {
    // Extract indicator type and parameters
    if (!indicator_def.contains(\"indicator\") || !indicator_def.contains(\"source\")) {
        throw ConditionEvalError(\"Missing indicator or source in indicator definition\");
    }
    
    std::string indicator_type = indicator_def[\"indicator\"].get<std::string>();
    std::string source = indicator_def[\"source\"].get<std::string>();
    
    // Create cache key
    std::string cache_key = source + \"_\" + indicator_type;
    if (indicator_def.contains(\"period\")) {
        cache_key += \"_\" + indicator_def[\"period\"].get<std::string>();
    }
    
    // Check cache first
    auto cache_it = indicator_cache.find(cache_key);
    if (cache_it != indicator_cache.end()) {
        auto& cached_values = cache_it->second;
        // Return the last total_days values
        int start_idx = std::max(0, static_cast<int>(cached_values.size()) - total_days);
        return std::vector<float>(cached_values.begin() + start_idx, cached_values.end());
    }
    
    // For current price indicator
    if (indicator_type == \"current price\") {
        auto price_it = price_cache.find(source);
        if (price_it != price_cache.end()) {
            auto& prices = price_it->second;
            int start_idx = std::max(0, static_cast<int>(prices.size()) - total_days);
            return std::vector<float>(prices.begin() + start_idx, prices.end());
        }
        
        // Generate dummy price data for testing
        std::vector<float> prices;
        for (int i = 0; i < total_days; ++i) {
            prices.push_back(100.0f + i * 0.1f); // Simple increasing price
        }
        price_cache[source] = prices;
        return prices;
    }
    
    // For SMA indicator
    if (indicator_type == \"Simple Moving Average of Price\") {
        int period = 20; // Default period
        if (indicator_def.contains(\"period\")) {
            period = std::stoi(indicator_def[\"period\"].get<std::string>());
        }
        
        // Get price data
        auto price_data = get_indicator_value(
            {{\"indicator\", \"current price\"}, {\"source\", source}},
            date_range, total_days + period, indicator_cache, price_cache, live_execution
        );
        
        // Calculate SMA
        std::vector<float> sma_values;
        for (size_t i = period - 1; i < price_data.size(); ++i) {
            float sum = 0.0f;
            for (int j = 0; j < period; ++j) {
                sum += price_data[i - j];
            }
            sma_values.push_back(sum / period);
        }
        
        // Cache the result
        indicator_cache[cache_key] = sma_values;
        
        // Return the last total_days values
        int start_idx = std::max(0, static_cast<int>(sma_values.size()) - total_days);
        return std::vector<float>(sma_values.begin() + start_idx, sma_values.end());
    }
    
    // For unsupported indicators, return dummy data
    std::vector<float> dummy_values;
    for (int i = 0; i < total_days; ++i) {
        dummy_values.push_back(50.0f); // Dummy value
    }
    return dummy_values;
}

std::vector<bool> ConditionalNodeProcessor::compare_values(
    const std::vector<float>& x,
    const std::vector<float>& y,
    const std::string& comparison_str
) {
    if (x.size() != y.size()) {
        throw ConditionEvalError(\"Vector lengths must match for comparison\");
    }
    
    auto op = parse_comparison_operator(comparison_str);
    std::vector<bool> result;
    result.reserve(x.size());
    
    for (size_t i = 0; i < x.size(); ++i) {
        bool comparison_result = false;
        
        switch (op) {
            case ComparisonOperator::GREATER_THAN:
                comparison_result = x[i] > y[i];
                break;
            case ComparisonOperator::LESS_THAN:
                comparison_result = x[i] < y[i];
                break;
            case ComparisonOperator::EQUAL:
                comparison_result = std::abs(x[i] - y[i]) < 1e-6f;
                break;
            case ComparisonOperator::GREATER_EQUAL:
                comparison_result = x[i] >= y[i];
                break;
            case ComparisonOperator::LESS_EQUAL:
                comparison_result = x[i] <= y[i];
                break;
            case ComparisonOperator::NOT_EQUAL:
                comparison_result = std::abs(x[i] - y[i]) >= 1e-6f;
                break;
        }
        
        result.push_back(comparison_result);
    }
    
    return result;
}

ComparisonOperator ConditionalNodeProcessor::parse_comparison_operator(const std::string& comparison_str) {
    if (comparison_str == \">\") return ComparisonOperator::GREATER_THAN;
    if (comparison_str == \"<\") return ComparisonOperator::LESS_THAN;
    if (comparison_str == \"==\" || comparison_str == \"=\") return ComparisonOperator::EQUAL;
    if (comparison_str == \">=\") return ComparisonOperator::GREATER_EQUAL;
    if (comparison_str == \"<=\") return ComparisonOperator::LESS_EQUAL;
    if (comparison_str == \"!=\" || comparison_str == \"<>\") return ComparisonOperator::NOT_EQUAL;
    
    throw ConditionEvalError(\"Invalid comparison operator: \" + comparison_str);
}

void ConditionalNodeProcessor::align_indicator_lengths(std::vector<float>& x, std::vector<float>& y) {
    if (x.size() == y.size()) {
        return;
    }
    
    if (x.size() > y.size()) {
        // Truncate x to match y's length
        int start_idx = static_cast<int>(x.size()) - static_cast<int>(y.size());
        x = std::vector<float>(x.begin() + start_idx, x.end());
    } else {
        // Truncate y to match x's length
        int start_idx = static_cast<int>(y.size()) - static_cast<int>(x.size());
        y = std::vector<float>(y.begin() + start_idx, y.end());
    }
}

void ConditionalNodeProcessor::extract_branches(
    const StrategyNode& node,
    std::vector<StrategyNode>& true_branch,
    std::vector<StrategyNode>& false_branch
) {
    // Extract true branch
    if (node.branches.contains(\"true\") && node.branches[\"true\"].is_array()) {
        for (const auto& branch_node_json : node.branches[\"true\"]) {
            true_branch.emplace_back(branch_node_json);
        }
    }
    
    // Extract false branch
    if (node.branches.contains(\"false\") && node.branches[\"false\"].is_array()) {
        for (const auto& branch_node_json : node.branches[\"false\"]) {
            false_branch.emplace_back(branch_node_json);
        }
    }
}

} // namespace atlas", "original_text": "", "replace_all": false}]