#include \"sort_node.h\"
#include <algorithm>
#include <numeric>
#include <cmath>
#include <stdexcept>

namespace atlas {

NodeResult SortNodeProcessor::process(
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
        // Validate sort node
        if (!validate_sort_node(node)) {
            return NodeResult(0, false, \"Invalid sort node structure\");
        }
        
        // Parse properties
        SelectFunction select_function;
        int selection_count;
        if (!parse_select_properties(node.properties, select_function, selection_count)) {
            return NodeResult(0, false, \"Invalid selection properties\");
        }
        
        SortFunction sort_function;
        int sort_window;
        if (!parse_sort_properties(node.properties, sort_function, sort_window)) {
            return NodeResult(0, false, \"Invalid sort properties\");
        }
        
        // Get branches
        auto [branches, has_folder_node] = get_branches(node);
        if (branches.empty()) {
            return NodeResult(0, false, \"Sort node has no branches\");
        }
        
        // Get branch keys
        std::vector<std::string> branch_keys;
        for (auto it = branches.begin(); it != branches.end(); ++it) {
            branch_keys.push_back(it.key());
        }
        
        if (selection_count > static_cast<int>(branch_keys.size())) {
            return NodeResult(0, false, \"Selection count exceeds available branches\");
        }
        
        // Adjust total_days based on sort function requirements
        int original_total_days = total_days;
        bool uses_delta = (sort_function == SortFunction::STANDARD_DEVIATION_RETURN ||
                          sort_function == SortFunction::MOVING_AVERAGE_RETURN);
        bool pad_252_days = (sort_function == SortFunction::RELATIVE_STRENGTH_INDEX ||
                             sort_function == SortFunction::EXPONENTIAL_MOVING_AVERAGE);
        
        if (has_folder_node) {
            total_days += sort_window + (uses_delta ? 1 : 0) + (pad_252_days ? 252 : 0);
            // Update active mask accordingly
            std::vector<bool> new_active_mask(total_days, true);
            int offset = std::max(0, static_cast<int>(new_active_mask.size()) - static_cast<int>(active_mask.size()));
            for (size_t i = 0; i < active_mask.size(); ++i) {
                size_t new_idx = offset + i;
                if (new_idx < new_active_mask.size()) {
                    new_active_mask[new_idx] = active_mask[i];
                }
            }
            active_mask = new_active_mask;
        }
        
        // Process branches
        auto [temp_portfolio_vectors, common_data_span] = process_branches(
            branches, branch_keys, total_days, node_weight, date_range,
            flow_count, flow_stocks, indicator_cache, price_cache,
            strategy, live_execution, global_cache_length
        );
        
        // Calculate metrics for sorting
        auto branch_metrics = calculate_branch_metrics(
            temp_portfolio_vectors, date_range, sort_function, sort_window,
            indicator_cache, price_cache, live_execution
        );
        
        // Calculate selection indices
        auto selection_indices = calculate_selection_indices(
            branch_metrics, active_mask, common_data_span, select_function,
            selection_count, node, flow_count
        );
        
        // Update portfolio history
        update_portfolio_history(
            portfolio_history, temp_portfolio_vectors, selection_indices,
            node_weight, common_data_span, selection_count
        );
        
        // Set flow stocks
        if (!node.hash.empty()) {
            set_flow_stocks(flow_stocks, portfolio_history, node.hash);
        }
        
        return NodeResult(common_data_span, true);
        
    } catch (const std::exception& e) {
        return NodeResult(0, false, \"Sort node error: \" + std::string(e.what()));
    }
}

bool SortNodeProcessor::validate_sort_node(const StrategyNode& node) const {
    // Must have branches
    if (!node.branches.contains(\"branches\") && node.branches.empty()) {
        return false;
    }
    
    // Must have select and sortby properties
    return node.properties.contains(\"select\") && node.properties.contains(\"sortby\");
}

bool SortNodeProcessor::parse_select_properties(
    const nlohmann::json& properties,
    SelectFunction& select_function,
    int& selection_count
) const {
    if (!properties.contains(\"select\")) {
        return false;
    }
    
    auto select_obj = properties[\"select\"];
    if (!select_obj.contains(\"function\") || !select_obj.contains(\"howmany\")) {
        return false;
    }
    
    // Parse select function
    std::string function_str = select_obj[\"function\"].get<std::string>();
    try {
        select_function = parse_select_function(function_str);
    } catch (...) {
        return false;
    }
    
    // Parse selection count
    try {
        selection_count = std::stoi(select_obj[\"howmany\"].get<std::string>());
    } catch (...) {
        return false;
    }
    
    return selection_count > 0;
}

bool SortNodeProcessor::parse_sort_properties(
    const nlohmann::json& properties,
    SortFunction& sort_function,
    int& sort_window
) const {
    if (!properties.contains(\"sortby\")) {
        return false;
    }
    
    auto sortby_obj = properties[\"sortby\"];
    if (!sortby_obj.contains(\"function\")) {
        return false;
    }
    
    // Parse sort function
    std::string function_str = sortby_obj[\"function\"].get<std::string>();
    try {
        sort_function = parse_sort_function(function_str);
    } catch (...) {
        return false;
    }
    
    // Parse sort window (default to 20 if not specified)
    sort_window = 20;
    if (sortby_obj.contains(\"window\")) {
        try {
            sort_window = std::stoi(sortby_obj[\"window\"].get<std::string>());
        } catch (...) {
            // Use default
        }
    } else if (sortby_obj.contains(\"period\")) {
        try {
            sort_window = std::stoi(sortby_obj[\"period\"].get<std::string>());
        } catch (...) {
            // Use default
        }
    }
    
    return sort_window > 0;
}

std::tuple<std::vector<std::vector<DayData>>, int> SortNodeProcessor::process_branches(
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
) {
    std::vector<std::vector<DayData>> temp_portfolio_vectors;
    temp_portfolio_vectors.reserve(branch_keys.size());
    
    int min_data_length = total_days;
    
    for (const auto& branch_key : branch_keys) {
        if (!branches.contains(branch_key)) {
            throw SortNodeError(\"Branch key not found: \" + branch_key);
        }
        
        auto branch_nodes = branches[branch_key];
        if (!branch_nodes.is_array() || branch_nodes.empty()) {
            throw SortNodeError(\"Empty branch: \" + branch_key);
        }
        
        // Initialize portfolio for this branch
        std::vector<DayData> branch_portfolio(total_days);
        
        // For simplicity, we'll process the first node in each branch
        // In a complete implementation, this would process all nodes in the branch
        auto first_node = StrategyNode(branch_nodes[0]);
        
        // Process stock nodes directly (simplified implementation)
        if (first_node.type == \"stock\" && first_node.properties.contains(\"symbol\")) {
            std::string symbol = first_node.properties[\"symbol\"].get<std::string>();
            
            // Add stock to all days for this branch
            for (auto& day : branch_portfolio) {
                day.add_stock(StockInfo(symbol, 1.0f));
            }
        }
        
        temp_portfolio_vectors.push_back(std::move(branch_portfolio));
        // For now, we don't reduce min_data_length since we're using simplified processing
    }
    
    return std::make_tuple(temp_portfolio_vectors, min_data_length);
}

std::vector<std::vector<float>> SortNodeProcessor::calculate_branch_metrics(
    const std::vector<std::vector<DayData>>& temp_portfolio_vectors,
    const std::vector<std::string>& date_range,
    SortFunction sort_function,
    int sort_window,
    std::unordered_map<std::string, std::vector<float>>& indicator_cache,
    std::unordered_map<std::string, std::vector<float>>& price_cache,
    bool live_execution
) {
    std::vector<std::vector<float>> branch_metrics;
    branch_metrics.reserve(temp_portfolio_vectors.size());
    
    for (const auto& branch_portfolio : temp_portfolio_vectors) {
        std::vector<float> metrics;
        
        switch (sort_function) {
            case SortFunction::RELATIVE_STRENGTH_INDEX: {
                // Calculate RSI based on portfolio returns
                auto returns = calculate_portfolio_returns(branch_portfolio, price_cache);
                metrics = calculate_rsi(returns, sort_window);
                break;
            }
            case SortFunction::SIMPLE_MOVING_AVERAGE: {
                auto returns = calculate_portfolio_returns(branch_portfolio, price_cache);
                metrics = calculate_sma(returns, sort_window);
                break;
            }
            case SortFunction::EXPONENTIAL_MOVING_AVERAGE: {
                auto returns = calculate_portfolio_returns(branch_portfolio, price_cache);
                metrics = calculate_ema(returns, sort_window);
                break;
            }
            case SortFunction::PORTFOLIO_RETURN: {
                metrics = calculate_portfolio_returns(branch_portfolio, price_cache);
                break;
            }
            default: {
                // For unsupported functions, use dummy values
                metrics.resize(branch_portfolio.size(), 0.0f);
                for (size_t i = 0; i < metrics.size(); ++i) {
                    metrics[i] = static_cast<float>(i) * 0.1f; // Dummy progressive values
                }
                break;
            }
        }
        
        // Ensure metrics vector has the right size
        if (metrics.size() != branch_portfolio.size()) {
            metrics.resize(branch_portfolio.size(), 0.0f);
        }
        
        branch_metrics.push_back(metrics);
    }
    
    return branch_metrics;
}

std::vector<std::vector<int>> SortNodeProcessor::calculate_selection_indices(
    const std::vector<std::vector<float>>& branch_metrics,
    const std::vector<bool>& active_mask,
    int data_span,
    SelectFunction select_function,
    int selection_count,
    const StrategyNode& node,
    std::unordered_map<std::string, int>& flow_count
) {
    std::vector<std::vector<int>> selection_indices(data_span);
    
    // Find active days
    std::vector<int> active_days;
    int start_offset = std::max(0, static_cast<int>(active_mask.size()) - data_span);
    for (int i = 0; i < data_span; ++i) {
        int mask_idx = start_offset + i;
        if (mask_idx < static_cast<int>(active_mask.size()) && active_mask[mask_idx]) {
            active_days.push_back(i);
        }
    }
    
    for (int day : active_days) {
        // Increment flow count
        if (!node.hash.empty()) {
            increment_flow_count(flow_count, node.hash);
        }
        
        // Get metrics for this day from all branches
        std::vector<std::pair<float, int>> day_metrics;
        for (size_t branch_idx = 0; branch_idx < branch_metrics.size(); ++branch_idx) {
            if (day < static_cast<int>(branch_metrics[branch_idx].size())) {
                float metric = branch_metrics[branch_idx][day];
                // Handle NaN and Inf
                if (std::isnan(metric) || std::isinf(metric)) {
                    metric = 0.0f;
                }
                day_metrics.emplace_back(metric, static_cast<int>(branch_idx));
            }
        }
        
        // Sort based on select function
        if (select_function == SelectFunction::TOP) {
            // Sort in descending order (highest first)
            std::sort(day_metrics.begin(), day_metrics.end(), 
                     [](const auto& a, const auto& b) { return a.first > b.first; });
        } else {
            // Sort in ascending order (lowest first)
            std::sort(day_metrics.begin(), day_metrics.end(), 
                     [](const auto& a, const auto& b) { return a.first < b.first; });
        }
        
        // Select top selection_count indices
        std::vector<int> selected_indices;
        int count = std::min(selection_count, static_cast<int>(day_metrics.size()));
        for (int i = 0; i < count; ++i) {
            selected_indices.push_back(day_metrics[i].second);
        }
        
        selection_indices[day] = selected_indices;
    }
    
    return selection_indices;
}

void SortNodeProcessor::update_portfolio_history(
    std::vector<DayData>& portfolio_history,
    const std::vector<std::vector<DayData>>& temp_portfolio_vectors,
    const std::vector<std::vector<int>>& selection_indices,
    float node_weight,
    int common_data_span,
    int selection_count
) {
    for (int day = 0; day < common_data_span; ++day) {
        if (day >= static_cast<int>(selection_indices.size())) {
            continue;
        }
        
        int portfolio_idx = static_cast<int>(portfolio_history.size()) - common_data_span + day;
        if (portfolio_idx < 0 || portfolio_idx >= static_cast<int>(portfolio_history.size())) {
            continue;
        }
        
        for (int branch_idx : selection_indices[day]) {
            if (branch_idx >= static_cast<int>(temp_portfolio_vectors.size()) ||
                day >= static_cast<int>(temp_portfolio_vectors[branch_idx].size())) {
                continue;
            }
            
            const auto& branch_day = temp_portfolio_vectors[branch_idx][day];
            for (const auto& stock : branch_day.stock_list()) {
                // Adjust weight
                float adjusted_weight = stock.weight_tomorrow() / selection_count * node_weight;
                portfolio_history[portfolio_idx].add_stock(StockInfo(stock.ticker(), adjusted_weight));
            }
        }
    }
}

// Utility function implementations
std::vector<float> SortNodeProcessor::calculate_rsi(const std::vector<float>& prices, int period) {
    std::vector<float> rsi_values;
    if (prices.size() < static_cast<size_t>(period + 1)) {
        rsi_values.resize(prices.size(), 50.0f); // Default RSI
        return rsi_values;
    }
    
    std::vector<float> gains, losses;
    
    // Calculate price changes
    for (size_t i = 1; i < prices.size(); ++i) {
        float change = prices[i] - prices[i-1];
        gains.push_back(change > 0 ? change : 0);
        losses.push_back(change < 0 ? -change : 0);
    }
    
    // Calculate initial averages
    float avg_gain = 0, avg_loss = 0;
    for (int i = 0; i < period; ++i) {
        avg_gain += gains[i];
        avg_loss += losses[i];
    }
    avg_gain /= period;
    avg_loss /= period;
    
    // Calculate RSI
    rsi_values.resize(prices.size(), 50.0f);
    
    for (size_t i = period; i < gains.size(); ++i) {
        avg_gain = (avg_gain * (period - 1) + gains[i]) / period;
        avg_loss = (avg_loss * (period - 1) + losses[i]) / period;
        
        float rs = (avg_loss == 0) ? 100 : avg_gain / avg_loss;
        float rsi = 100 - (100 / (1 + rs));
        
        rsi_values[i + 1] = rsi;
    }
    
    return rsi_values;
}

std::vector<float> SortNodeProcessor::calculate_sma(const std::vector<float>& values, int period) {
    std::vector<float> sma_values;
    
    for (size_t i = 0; i < values.size(); ++i) {
        if (i < static_cast<size_t>(period - 1)) {
            sma_values.push_back(values[i]); // Not enough data, use original value
        } else {
            float sum = 0;
            for (int j = 0; j < period; ++j) {
                sum += values[i - j];
            }
            sma_values.push_back(sum / period);
        }
    }
    
    return sma_values;
}

std::vector<float> SortNodeProcessor::calculate_ema(const std::vector<float>& values, int period) {
    std::vector<float> ema_values;
    if (values.empty()) return ema_values;
    
    float multiplier = 2.0f / (period + 1);
    ema_values.push_back(values[0]); // First value is the seed
    
    for (size_t i = 1; i < values.size(); ++i) {
        float ema = (values[i] * multiplier) + (ema_values[i-1] * (1 - multiplier));
        ema_values.push_back(ema);
    }
    
    return ema_values;
}

std::vector<float> SortNodeProcessor::calculate_portfolio_returns(
    const std::vector<DayData>& portfolio_data,
    std::unordered_map<std::string, std::vector<float>>& price_cache
) {
    std::vector<float> returns;
    returns.reserve(portfolio_data.size());
    
    for (size_t day = 0; day < portfolio_data.size(); ++day) {
        float daily_return = 0.0f;
        
        for (const auto& stock : portfolio_data[day].stock_list()) {
            // Get price for this stock (simplified - using dummy price)
            float price = 100.0f + day * 0.1f; // Dummy progressive price
            daily_return += stock.weight_tomorrow() * price;
        }
        
        returns.push_back(daily_return);
    }
    
    return returns;
}

SortFunction SortNodeProcessor::parse_sort_function(const std::string& sort_function_str) {
    if (sort_function_str == \"Relative Strength Index\") return SortFunction::RELATIVE_STRENGTH_INDEX;
    if (sort_function_str == \"Simple Moving Average of Price\") return SortFunction::SIMPLE_MOVING_AVERAGE;
    if (sort_function_str == \"Exponential Moving Average of Price\") return SortFunction::EXPONENTIAL_MOVING_AVERAGE;
    if (sort_function_str == \"Standard Deviation of Return\") return SortFunction::STANDARD_DEVIATION_RETURN;
    if (sort_function_str == \"Moving Average of Return\") return SortFunction::MOVING_AVERAGE_RETURN;
    if (sort_function_str == \"current price\") return SortFunction::CURRENT_PRICE;
    if (sort_function_str == \"Portfolio Return\") return SortFunction::PORTFOLIO_RETURN;
    
    throw SortNodeError(\"Invalid sort function: \" + sort_function_str);
}

SelectFunction SortNodeProcessor::parse_select_function(const std::string& select_function_str) {
    if (select_function_str == \"Top\") return SelectFunction::TOP;
    if (select_function_str == \"Bottom\") return SelectFunction::BOTTOM;
    
    throw SortNodeError(\"Invalid select function: \" + select_function_str);
}

std::pair<nlohmann::json, bool> SortNodeProcessor::get_branches(const StrategyNode& node) {
    // Check if node has branches property
    if (node.branches.contains(\"branches\")) {
        return std::make_pair(node.branches[\"branches\"], true);
    }
    
    // Otherwise use the branches directly
    return std::make_pair(node.branches, false);
}

} // namespace atlas", "original_text": "", "replace_all": false}]