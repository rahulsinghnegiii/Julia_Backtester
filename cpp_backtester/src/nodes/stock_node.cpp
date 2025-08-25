#include \"stock_node.h\"
#include <algorithm>
#include <stdexcept>

namespace atlas {

NodeResult StockNodeProcessor::process(
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
        // Validate stock node
        if (!validate_stock_node(node)) {
            return NodeResult(0, false, \"Invalid stock node structure\");
        }
        
        // Validate inputs
        if (!validate_inputs(active_mask, total_days, node_weight, portfolio_history)) {
            return NodeResult(0, false, \"Invalid input parameters\");
        }
        
        // Extract symbol from properties
        std::string symbol = node.properties[\"symbol\"].get<std::string>();
        
        // Find active days
        auto active_days = find_active_days(active_mask);
        
        // Update flow count if hash exists
        if (!node.hash.empty()) {
            increment_flow_count(flow_count, node.hash);
        }
        
        // Update portfolio
        update_portfolio(portfolio_history, symbol, node_weight, active_days, total_days);
        
        // Set flow stocks if hash exists
        if (!node.hash.empty()) {
            set_flow_stocks(flow_stocks, portfolio_history, node.hash);
        }
        
        return NodeResult(total_days, true);
        
    } catch (const std::exception& e) {
        return NodeResult(0, false, \"Stock node processing error: \" + std::string(e.what()));
    }
}

bool StockNodeProcessor::validate_stock_node(const StrategyNode& node) const {
    // Must have properties
    if (node.properties.empty()) {
        return false;
    }
    
    // Must have symbol in properties
    if (!node.properties.contains(\"symbol\")) {
        return false;
    }
    
    // Symbol must be a non-empty string
    if (!node.properties[\"symbol\"].is_string()) {
        return false;
    }
    
    std::string symbol = node.properties[\"symbol\"].get<std::string>();
    if (symbol.empty()) {
        return false;
    }
    
    return true;
}

bool StockNodeProcessor::validate_inputs(
    const std::vector<bool>& active_mask,
    int total_days,
    float node_weight,
    const std::vector<DayData>& portfolio_history
) const {
    // Check active mask
    if (active_mask.empty()) {
        return false;
    }
    
    // Check total days
    if (total_days <= 0) {
        return false;
    }
    
    // Check node weight
    if (node_weight <= 0.0f || node_weight > 1.0f) {
        return false;
    }
    
    // Check portfolio history
    if (portfolio_history.empty()) {
        return false;
    }
    
    // Portfolio history must be at least as long as total days
    if (static_cast<int>(portfolio_history.size()) < total_days) {
        return false;
    }
    
    return true;
}

void StockNodeProcessor::update_portfolio(
    std::vector<DayData>& portfolio_history,
    const std::string& symbol,
    float node_weight,
    const std::vector<int>& active_days,
    int total_days
) {
    for (int day : active_days) {
        // Calculate portfolio index (Julia-style indexing from end)
        int portfolio_idx = static_cast<int>(portfolio_history.size()) - total_days + day;
        
        // Validate index
        if (portfolio_idx < 0 || portfolio_idx >= static_cast<int>(portfolio_history.size())) {
            throw std::runtime_error(\"Invalid portfolio index: \" + std::to_string(portfolio_idx));
        }
        
        // Add stock to portfolio
        StockInfo stock_info(symbol, node_weight);
        portfolio_history[portfolio_idx].add_stock(stock_info);
    }
}

std::vector<int> StockNodeProcessor::find_active_days(const std::vector<bool>& active_mask) const {
    std::vector<int> active_days;
    
    for (size_t i = 0; i < active_mask.size(); ++i) {
        if (active_mask[i]) {
            active_days.push_back(static_cast<int>(i));
        }
    }
    
    return active_days;
}

} // namespace atlas