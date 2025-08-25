#include "allocation_node.h"
#include "backtesting_engine.h"
#include <algorithm>
#include <numeric>
#include <cmath>
#include <stdexcept>

namespace atlas {

NodeResult AllocationNodeProcessor::process(
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
        if (!validate_allocation_node(node)) {
            throw AllocationNodeError("Invalid allocation node structure");
        }
        
        // Track flow count if node has hash
        if (node.properties.contains("hash")) {
            auto hash = node.properties["hash"].get<std::string>();
            flow_count[hash]++;
        }
        
        // Determine allocation function type
        AllocationFunction alloc_func = parse_allocation_function(node.properties);
        int min_days = total_days;
        
        switch (alloc_func) {
            case AllocationFunction::EQUAL_ALLOCATION:
                min_days = process_equal_allocation(
                    node, active_mask, total_days, node_weight, portfolio_history,
                    date_range, flow_count, flow_stocks, strategy, live_execution, global_cache_length
                );
                break;
                
            case AllocationFunction::INVERSE_VOLATILITY:
                min_days = process_inverse_volatility(
                    node, active_mask, total_days, node_weight, portfolio_history,
                    date_range, flow_count, flow_stocks, indicator_cache, price_cache,
                    strategy, live_execution, global_cache_length
                );
                break;
                
            case AllocationFunction::MARKET_CAP:
                min_days = process_market_cap(
                    node, active_mask, total_days, node_weight, portfolio_history,
                    date_range, flow_count, flow_stocks, indicator_cache, price_cache,
                    strategy, live_execution
                );
                break;
                
            case AllocationFunction::ALLOCATION:
                // Manual allocation with specified weights
                min_days = process_children(
                    node, active_mask, total_days, node_weight, portfolio_history,
                    date_range, flow_count, flow_stocks, indicator_cache, price_cache,
                    strategy, live_execution, global_cache_length
                );
                break;
                
            default:
                throw AllocationNodeError("Unknown allocation function");
        }
        
        // Set flow stocks if node has hash
        if (node.properties.contains("hash")) {
            auto hash = node.properties["hash"].get<std::string>();
            flow_stocks[hash] = portfolio_history;
        }
        
        return NodeResult{min_days, true};
        
    } catch (const std::exception& e) {
        throw AllocationNodeError("Failed to process allocation node: " + std::string(e.what()));
    }
}

bool AllocationNodeProcessor::validate_allocation_node(const StrategyNode& node) const {
    // Check if node has required properties
    if (!node.properties.contains("function") && !node.properties.contains("allocation_function")) {
        return false;
    }
    
    // Check if node has branches for processing
    if (node.branches.empty() && node.sequence.empty()) {
        return false;
    }
    
    return true;
}

AllocationFunction AllocationNodeProcessor::parse_allocation_function(const nlohmann::json& properties) const {
    std::string function_name;
    
    if (properties.contains("function")) {
        function_name = properties["function"].get<std::string>();
    } else if (properties.contains("allocation_function")) {
        function_name = properties["allocation_function"].get<std::string>();
    } else {
        throw AllocationNodeError("No allocation function specified");
    }
    
    if (function_name == "Equal Allocation" || function_name == "equal") {
        return AllocationFunction::EQUAL_ALLOCATION;
    } else if (function_name == "Inverse Volatility" || function_name == "inverse_volatility") {
        return AllocationFunction::INVERSE_VOLATILITY;
    } else if (function_name == "Market Cap" || function_name == "market_cap") {
        return AllocationFunction::MARKET_CAP;
    } else if (function_name == "Allocation" || function_name == "manual") {
        return AllocationFunction::ALLOCATION;
    } else {
        throw AllocationNodeError("Unknown allocation function: " + function_name);
    }
}

int AllocationNodeProcessor::process_equal_allocation(
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
) {
    try {
        int min_days = total_days;
        int num_branches = node.branches.empty() ? node.sequence.size() : node.branches.size();
        
        if (num_branches == 0) {
            throw AllocationNodeError("No branches to allocate");
        }
        
        float equal_weight = node_weight / num_branches;
        
        // Process branches with equal weights
        if (!node.branches.empty()) {
            for (const auto& [branch_name, branch_nodes] : node.branches) {
                if (!branch_nodes.empty()) {
                    // Note: This would require the backtesting engine to process the node
                    // For now, we'll simulate equal allocation by adjusting weights
                    int branch_min_days = total_days; // placeholder
                    min_days = std::min(min_days, branch_min_days);
                }
            }
        } else {
            // Process sequence nodes
            for (const auto& seq_node : node.sequence) {
                // Process each sequence node with equal weight
                int seq_min_days = total_days; // placeholder  
                min_days = std::min(min_days, seq_min_days);
            }
        }
        
        // Apply equal weights to portfolio
        std::unordered_map<std::string, float> equal_weights;
        
        // For equal allocation, we distribute weight equally among all stocks in portfolio
        for (int day = 0; day < total_days && day < static_cast<int>(portfolio_history.size()); ++day) {
            if (active_mask[day]) {
                auto& day_data = portfolio_history[day];
                if (!day_data.stock_list.empty()) {
                    float stock_weight = equal_weight / day_data.stock_list.size();
                    for (auto& stock : day_data.stock_list) {
                        stock.weight_tomorrow = stock_weight;
                    }
                }
            }
        }
        
        return min_days;
        
    } catch (const std::exception& e) {
        throw AllocationNodeError("Failed to process equal allocation: " + std::string(e.what()));
    }
}

int AllocationNodeProcessor::process_inverse_volatility(
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
        // Get volatility period from properties
        if (!node.properties.contains("period")) {
            throw AllocationNodeError("Missing period for inverse volatility calculation");
        }
        
        int volatility_period = std::stoi(node.properties["period"].get<std::string>());
        int min_days = total_days;
        
        // Adjust total days if needed for volatility calculation
        int original_total_days = total_days;
        bool flag = false;
        
        if (total_days <= volatility_period) {
            total_days += volatility_period;
            // Expand active mask
            std::vector<bool> new_active_mask(total_days, true);
            for (size_t i = 0; i < active_mask.size(); ++i) {
                new_active_mask[new_active_mask.size() - i - 1] = active_mask[active_mask.size() - i - 1];
            }
            active_mask = new_active_mask;
            flag = true;
        }
        
        // Process each branch to get portfolio vectors
        std::vector<std::vector<DayData>> temp_portfolio_vectors;
        int branch_index = 0;
        
        for (const auto& [branch_name, branch_nodes] : node.branches) {
            if (!branch_nodes.empty()) {
                std::vector<DayData> branch_portfolio(total_days);
                // Initialize empty portfolio
                for (auto& day : branch_portfolio) {
                    day = DayData{};
                }
                
                // Process branch (would need backtesting engine integration)
                temp_portfolio_vectors.push_back(branch_portfolio);
                branch_index++;
            }
        }
        
        // Calculate volatilities for each branch
        auto volatilities = calculate_volatilities(temp_portfolio_vectors, volatility_period, price_cache);
        
        // Calculate inverse volatility weights
        std::unordered_map<std::string, float> inv_vol_weights;
        float total_inv_vol = 0.0f;
        
        for (const auto& [ticker, vol] : volatilities) {
            if (vol > 0.0f) {
                float inv_vol = 1.0f / vol;
                inv_vol_weights[ticker] = inv_vol;
                total_inv_vol += inv_vol;
            }
        }
        
        // Normalize weights
        if (total_inv_vol > 0.0f) {
            for (auto& [ticker, weight] : inv_vol_weights) {
                weight = (weight / total_inv_vol) * node_weight;
            }
        }
        
        // Apply weights to portfolio
        apply_allocation_weights(portfolio_history, inv_vol_weights, active_mask, 
                               flag ? original_total_days : total_days, node_weight);
        
        return flag ? original_total_days : min_days;
        
    } catch (const std::exception& e) {
        throw AllocationNodeError("Failed to process inverse volatility: " + std::string(e.what()));
    }
}

int AllocationNodeProcessor::process_market_cap(
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
) {
    try {
        int min_days = total_days;
        std::unordered_map<std::string, std::vector<DayData>> branch_portfolios;
        std::vector<std::string> tickers;
        
        // Process each branch to collect stock symbols
        for (const auto& [branch_name, branch_nodes] : node.branches) {
            if (!branch_nodes.empty() && branch_nodes[0].type == "stock") {
                if (branch_nodes[0].properties.contains("symbol")) {
                    std::string symbol = branch_nodes[0].properties["symbol"].get<std::string>();
                    tickers.push_back(symbol);
                    
                    // Process branch
                    std::vector<DayData> branch_portfolio(total_days);
                    branch_portfolios[branch_name] = branch_portfolio;
                }
            }
        }
        
        // Get market cap data for all tickers
        auto market_caps = get_market_caps(tickers);
        
        // Calculate market cap weights
        float total_market_cap = 0.0f;
        for (const auto& [ticker, market_cap] : market_caps) {
            total_market_cap += market_cap;
        }
        
        std::unordered_map<std::string, float> market_cap_weights;
        if (total_market_cap > 0.0f) {
            for (const auto& [ticker, market_cap] : market_caps) {
                market_cap_weights[ticker] = (market_cap / total_market_cap) * node_weight;
            }
        }
        
        // Apply market cap weights to portfolio
        apply_allocation_weights(portfolio_history, market_cap_weights, active_mask, total_days, node_weight);
        
        return min_days;
        
    } catch (const std::exception& e) {
        throw AllocationNodeError("Failed to process market cap allocation: " + std::string(e.what()));
    }
}

std::unordered_map<std::string, float> AllocationNodeProcessor::calculate_volatilities(
    const std::vector<std::vector<DayData>>& portfolio_history,
    int period,
    std::unordered_map<std::string, std::vector<float>>& price_cache
) {
    std::unordered_map<std::string, float> volatilities;
    
    try {
        // Extract unique tickers from all portfolios
        std::set<std::string> unique_tickers;
        for (const auto& portfolio : portfolio_history) {
            for (const auto& day : portfolio) {
                for (const auto& stock : day.stock_list) {
                    unique_tickers.insert(stock.ticker);
                }
            }
        }
        
        // Calculate volatility for each ticker
        for (const auto& ticker : unique_tickers) {
            if (price_cache.find(ticker) != price_cache.end()) {
                const auto& prices = price_cache[ticker];
                if (prices.size() >= static_cast<size_t>(period)) {
                    // Get last 'period' prices
                    std::vector<float> recent_prices(prices.end() - period, prices.end());
                    auto returns = calculate_returns(recent_prices);
                    float volatility = calculate_volatility(returns);
                    volatilities[ticker] = volatility;
                }
            }
        }
        
        return volatilities;
        
    } catch (const std::exception& e) {
        throw AllocationNodeError("Failed to calculate volatilities: " + std::string(e.what()));
    }
}

std::unordered_map<std::string, float> AllocationNodeProcessor::get_market_caps(
    const std::vector<std::string>& tickers
) {
    std::unordered_map<std::string, float> market_caps;
    
    // Placeholder implementation - in a real system, this would fetch from a data provider
    for (const auto& ticker : tickers) {
        // Use mock market cap data for testing
        if (ticker == "AAPL") {
            market_caps[ticker] = 3000000.0f; // 3T market cap
        } else if (ticker == "MSFT") {
            market_caps[ticker] = 2800000.0f; // 2.8T market cap
        } else if (ticker == "GOOGL") {
            market_caps[ticker] = 1700000.0f; // 1.7T market cap
        } else if (ticker == "SPY") {
            market_caps[ticker] = 400000.0f; // 400B market cap
        } else if (ticker == "QQQ") {
            market_caps[ticker] = 200000.0f; // 200B market cap
        } else {
            market_caps[ticker] = 100000.0f; // Default 100B market cap
        }
    }
    
    return market_caps;
}

void AllocationNodeProcessor::apply_allocation_weights(
    std::vector<DayData>& portfolio_history,
    const std::unordered_map<std::string, float>& weights,
    const std::vector<bool>& active_mask,
    int total_days,
    float node_weight
) {
    try {
        for (int day = 0; day < total_days && day < static_cast<int>(portfolio_history.size()); ++day) {
            if (active_mask[day]) {
                auto& day_data = portfolio_history[day];
                for (auto& stock : day_data.stock_list) {
                    auto weight_it = weights.find(stock.ticker);
                    if (weight_it != weights.end()) {
                        stock.weight_tomorrow = weight_it->second;
                    } else {
                        stock.weight_tomorrow = 0.0f;
                    }
                    // Round to 6 decimal places as in Julia version
                    stock.weight_tomorrow = std::round(stock.weight_tomorrow * 1000000.0f) / 1000000.0f;
                }
            }
        }
    } catch (const std::exception& e) {
        throw AllocationNodeError("Failed to apply allocation weights: " + std::string(e.what()));
    }
}

std::vector<float> AllocationNodeProcessor::calculate_returns(const std::vector<float>& prices) {
    std::vector<float> returns;
    
    if (prices.size() < 2) {
        return returns;
    }
    
    returns.reserve(prices.size() - 1);
    for (size_t i = 1; i < prices.size(); ++i) {
        if (prices[i-1] != 0.0f) {
            float return_val = (prices[i] - prices[i-1]) / prices[i-1];
            returns.push_back(return_val);
        } else {
            returns.push_back(0.0f);
        }
    }
    
    return returns;
}

float AllocationNodeProcessor::calculate_volatility(const std::vector<float>& returns) {
    if (returns.empty()) {
        return 0.0f;
    }
    
    // Calculate mean
    float mean = std::accumulate(returns.begin(), returns.end(), 0.0f) / returns.size();
    
    // Calculate variance
    float variance = 0.0f;
    for (float ret : returns) {
        float diff = ret - mean;
        variance += diff * diff;
    }
    variance /= returns.size();
    
    // Return standard deviation (volatility)
    return std::sqrt(variance);
}

int AllocationNodeProcessor::process_children(
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
        int min_days = total_days;
        
        // Process manual allocation with specified weights
        if (node.properties.contains("values")) {
            auto values = node.properties["values"];
            float total_weight = 0.0f;
            
            // Validate total weight is 100%
            for (auto& [key, value] : values.items()) {
                total_weight += value.get<float>();
            }
            
            if (std::abs(total_weight - 100.0f) > 1e-2f) {
                throw AllocationNodeError("Total allocation weight must be 100%, got: " + std::to_string(total_weight));
            }
            
            // Process each branch with its specified weight
            for (auto& [branch_name, branch_weight] : values.items()) {
                float weight_fraction = branch_weight.get<float>() / 100.0f;
                float new_weight = node_weight * weight_fraction;
                
                // Find corresponding branch
                auto branch_it = node.branches.find(branch_name);
                if (branch_it != node.branches.end() && !branch_it->second.empty()) {
                    // Process branch with calculated weight
                    // This would require integration with the backtesting engine
                    // For now, apply the weight directly
                    
                    // Apply weight to all stocks in portfolio for this branch
                    for (int day = 0; day < total_days && day < static_cast<int>(portfolio_history.size()); ++day) {
                        if (active_mask[day]) {
                            auto& day_data = portfolio_history[day];
                            for (auto& stock : day_data.stock_list) {
                                stock.weight_tomorrow *= new_weight;
                                stock.weight_tomorrow = std::round(stock.weight_tomorrow * 1000000.0f) / 1000000.0f;
                            }
                        }
                    }
                }
            }
        }
        
        return min_days;
        
    } catch (const std::exception& e) {
        throw AllocationNodeError("Failed to process allocation children: " + std::string(e.what()));
    }
}

} // namespace atlas