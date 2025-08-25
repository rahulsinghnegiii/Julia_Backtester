#include "ta_functions.h"
#include <algorithm>
#include <stdexcept>
#include <iostream>
#include <cmath>

namespace atlas {

// TAFunctions implementation

std::vector<float> TAFunctions::calculate_rsi(const std::vector<float>& prices, int period) {
    if (!validate_data_length(prices.size(), static_cast<size_t>(period + 1))) {
        throw TAFunctionsError("Insufficient data for RSI calculation");
    }
    
    std::vector<float> rsi_values(prices.size(), NAN_VALUE);
    auto price_changes = calculate_price_changes(prices);
    auto [gains, losses] = separate_gains_losses(price_changes);
    
    // Calculate initial average gain and loss for the first period
    float sum_gains = 0.0f, sum_losses = 0.0f;
    for (int i = 0; i < period; ++i) {
        sum_gains += gains[i];
        sum_losses += losses[i];
    }
    
    float avg_gain = sum_gains / period;
    float avg_loss = sum_losses / period;
    
    // Calculate RSI for the first valid point
    if (avg_loss > EPSILON) {
        float rs = calculate_rs(avg_gain, avg_loss);
        rsi_values[period] = 100.0f - (100.0f / (1.0f + rs));
    }
    
    // Calculate RSI for subsequent points using Wilder's smoothing
    for (size_t i = period + 1; i < prices.size(); ++i) {
        avg_gain = apply_wilders_smoothing(avg_gain, gains[i-1], period);
        avg_loss = apply_wilders_smoothing(avg_loss, losses[i-1], period);
        
        if (avg_loss > EPSILON) {
            float rs = calculate_rs(avg_gain, avg_loss);
            rsi_values[i] = 100.0f - (100.0f / (1.0f + rs));
        }
    }
    
    return rsi_values;
}

std::vector<float> TAFunctions::calculate_sma(const std::vector<float>& data, int period) {
    if (!validate_data_length(data.size(), static_cast<size_t>(period))) {
        throw TAFunctionsError("Insufficient data for SMA calculation");
    }
    
    std::vector<float> sma_values(data.size(), NAN_VALUE);
    
    for (size_t i = period - 1; i < data.size(); ++i) {
        float sum = 0.0f;
        for (int j = 0; j < period; ++j) {
            sum += data[i - j];
        }
        sma_values[i] = sum / period;
    }
    
    return sma_values;
}

std::vector<float> TAFunctions::calculate_ema(const std::vector<float>& data, int period) {
    if (!validate_data_length(data.size(), static_cast<size_t>(period))) {
        throw TAFunctionsError("Insufficient data for EMA calculation");
    }
    
    std::vector<float> ema_values(data.size(), NAN_VALUE);
    float multiplier = calculate_ema_multiplier(period);
    
    // Initialize with SMA for the first value
    float sum = 0.0f;
    for (int i = 0; i < period; ++i) {
        sum += data[i];
    }
    ema_values[period - 1] = sum / period;
    
    // Calculate EMA for subsequent values
    for (size_t i = period; i < data.size(); ++i) {
        ema_values[i] = (data[i] * multiplier) + (ema_values[i-1] * (1.0f - multiplier));
    }
    
    return ema_values;
}

std::vector<float> TAFunctions::calculate_standard_deviation(const std::vector<float>& data, int period) {
    if (!validate_data_length(data.size(), static_cast<size_t>(period))) {
        throw TAFunctionsError("Insufficient data for standard deviation calculation");
    }
    
    std::vector<float> std_dev_values(data.size(), NAN_VALUE);
    
    for (size_t i = period - 1; i < data.size(); ++i) {
        auto [mean, variance] = calculate_window_stats(data, i - period + 1, i + 1);
        std_dev_values[i] = std::sqrt(variance);
    }
    
    return std_dev_values;
}

std::vector<float> TAFunctions::calculate_returns(const std::vector<float>& prices) {
    if (prices.size() < 2) {
        throw TAFunctionsError("Insufficient data for return calculation");
    }
    
    std::vector<float> returns;
    returns.reserve(prices.size() - 1);
    
    for (size_t i = 1; i < prices.size(); ++i) {
        if (prices[i-1] > EPSILON) {
            float return_val = 100.0f * (prices[i] - prices[i-1]) / prices[i-1];
            returns.push_back(return_val);
        } else {
            returns.push_back(0.0f);
        }
    }
    
    return returns;
}

std::vector<float> TAFunctions::calculate_sma_returns(const std::vector<float>& prices, int period) {
    if (!validate_data_length(prices.size(), static_cast<size_t>(period + 2))) {
        throw TAFunctionsError("Insufficient data for SMA returns calculation");
    }
    
    auto returns = calculate_returns(prices);
    return calculate_sma(returns, period);
}

std::vector<float> TAFunctions::calculate_returns_standard_deviation(const std::vector<float>& prices, int period) {
    if (!validate_data_length(prices.size(), static_cast<size_t>(period + 2))) {
        throw TAFunctionsError("Insufficient data for returns standard deviation calculation");
    }
    
    auto returns = calculate_returns(prices);
    std::vector<float> std_dev_values(prices.size() - 1, NAN_VALUE);
    
    for (size_t i = period - 1; i < returns.size(); ++i) {
        auto [mean, variance] = calculate_window_stats(returns, i - period + 1, i + 1);
        // Use sample standard deviation (n-1 denominator)
        float sample_variance = variance * period / (period - 1);
        std_dev_values[i] = std::sqrt(sample_variance) * 100.0f;
    }
    
    return std_dev_values;
}

std::vector<float> TAFunctions::calculate_cumulative_returns(const std::vector<float>& returns) {
    std::vector<float> cumulative_returns;
    cumulative_returns.reserve(returns.size());
    
    float cumulative = 0.0f;
    for (float ret : returns) {
        cumulative += ret;
        cumulative_returns.push_back(cumulative);
    }
    
    return cumulative_returns;
}

float TAFunctions::calculate_max_drawdown(const std::vector<float>& returns) {
    if (returns.empty()) {
        return 0.0f;
    }
    
    float peak = returns[0];
    float max_drawdown = 0.0f;
    
    for (float value : returns) {
        if (value > peak) {
            peak = value;
        }
        
        float drawdown = (peak - value) / peak * 100.0f;
        if (drawdown > max_drawdown) {
            max_drawdown = drawdown;
        }
    }
    
    return max_drawdown;
}

std::vector<float> TAFunctions::calculate_rolling_max_drawdown(const std::vector<float>& returns, int period) {
    std::vector<float> rolling_drawdowns(returns.size(), NAN_VALUE);
    
    for (size_t i = period - 1; i < returns.size(); ++i) {
        std::vector<float> window(returns.begin() + i - period + 1, returns.begin() + i + 1);
        rolling_drawdowns[i] = calculate_max_drawdown(window);
    }
    
    return rolling_drawdowns;
}

std::vector<float> TAFunctions::calculate_market_cap_weighting(const std::vector<float>& market_caps) {
    float total_market_cap = std::accumulate(market_caps.begin(), market_caps.end(), 0.0f);
    
    if (total_market_cap <= EPSILON) {
        throw TAFunctionsError("Total market cap must be positive");
    }
    
    std::vector<float> weights;
    weights.reserve(market_caps.size());
    
    for (float market_cap : market_caps) {
        weights.push_back(market_cap / total_market_cap);
    }
    
    return weights;
}

std::vector<float> TAFunctions::calculate_inverse_volatility_weighting(const std::vector<float>& volatilities) {
    std::vector<float> inverse_vols;
    inverse_vols.reserve(volatilities.size());
    
    float total_inverse_vol = 0.0f;
    
    // Calculate inverse volatilities
    for (float vol : volatilities) {
        if (vol > EPSILON) {
            float inv_vol = 1.0f / vol;
            inverse_vols.push_back(inv_vol);
            total_inverse_vol += inv_vol;
        } else {
            inverse_vols.push_back(0.0f);
        }
    }
    
    if (total_inverse_vol <= EPSILON) {
        throw TAFunctionsError("Total inverse volatility must be positive");
    }
    
    // Normalize to get weights
    for (float& inv_vol : inverse_vols) {
        inv_vol /= total_inverse_vol;
    }
    
    return inverse_vols;
}

std::vector<float> TAFunctions::calculate_portfolio_daily_returns(const std::vector<float>& portfolio_values) {
    return calculate_returns(portfolio_values);
}

// Utility functions

bool TAFunctions::validate_data_length(size_t data_length, size_t required_length) {
    return data_length >= required_length;
}

void TAFunctions::fill_initial_nan(std::vector<float>& result, size_t nan_count) {
    for (size_t i = 0; i < nan_count && i < result.size(); ++i) {
        result[i] = NAN_VALUE;
    }
}

std::pair<float, float> TAFunctions::calculate_window_stats(const std::vector<float>& data, 
                                                           size_t start, size_t end) {
    if (start >= end || end > data.size()) {
        throw TAFunctionsError("Invalid window indices");
    }
    
    float sum = 0.0f;
    size_t count = end - start;
    
    for (size_t i = start; i < end; ++i) {
        sum += data[i];
    }
    
    float mean = sum / count;
    
    float variance_sum = 0.0f;
    for (size_t i = start; i < end; ++i) {
        float diff = data[i] - mean;
        variance_sum += diff * diff;
    }
    
    float variance = variance_sum / count;
    
    return {mean, variance};
}

float TAFunctions::apply_wilders_smoothing(float previous_value, float current_value, int period) {
    return ((previous_value * (period - 1)) + current_value) / period;
}

// Private helper functions

std::vector<float> TAFunctions::calculate_price_changes(const std::vector<float>& prices) {
    std::vector<float> changes;
    changes.reserve(prices.size() - 1);
    
    for (size_t i = 1; i < prices.size(); ++i) {
        changes.push_back(prices[i] - prices[i-1]);
    }
    
    return changes;
}

std::pair<std::vector<float>, std::vector<float>> TAFunctions::separate_gains_losses(
    const std::vector<float>& changes) {
    
    std::vector<float> gains, losses;
    gains.reserve(changes.size());
    losses.reserve(changes.size());
    
    for (float change : changes) {
        if (change > 0) {
            gains.push_back(change);
            losses.push_back(0.0f);
        } else {
            gains.push_back(0.0f);
            losses.push_back(-change);  // Store as positive value
        }
    }
    
    return {gains, losses};
}

float TAFunctions::calculate_rs(float avg_gain, float avg_loss) {
    if (avg_loss <= EPSILON) {
        return 100.0f;  // Maximum RS when no losses
    }
    return avg_gain / avg_loss;
}

float TAFunctions::calculate_ema_multiplier(int period) {
    return 2.0f / (period + 1.0f);
}

// TechnicalIndicators implementation

IndicatorResult TechnicalIndicators::get_rsi(const std::string& ticker, int length_data, 
                                           int period, const std::string& end_date, 
                                           bool live_data) {
    try {
        auto prices = get_historical_prices(ticker, end_date, length_data + period, live_data);
        auto rsi_values = TAFunctions::calculate_rsi(prices, period);
        
        // Extract the requested length of data
        size_t start_idx = rsi_values.size() >= static_cast<size_t>(length_data) ? 
                          rsi_values.size() - length_data : 0;
        
        std::vector<float> result(rsi_values.begin() + start_idx, rsi_values.end());
        
        return IndicatorResult(result);
        
    } catch (const std::exception& e) {
        IndicatorResult error_result;
        error_result.error_message = "Error in get_rsi: " + std::string(e.what());
        return error_result;
    }
}

IndicatorResult TechnicalIndicators::get_sma(const std::string& ticker, int length_data, 
                                           int period, const std::string& end_date, 
                                           bool live_data) {
    try {
        auto prices = get_historical_prices(ticker, end_date, length_data + period, live_data);
        auto sma_values = TAFunctions::calculate_sma(prices, period);
        
        // Extract the requested length of data
        size_t start_idx = sma_values.size() >= static_cast<size_t>(length_data) ? 
                          sma_values.size() - length_data : 0;
        
        std::vector<float> result(sma_values.begin() + start_idx, sma_values.end());
        
        return IndicatorResult(result);
        
    } catch (const std::exception& e) {
        IndicatorResult error_result;
        error_result.error_message = "Error in get_sma: " + std::string(e.what());
        return error_result;
    }
}

IndicatorResult TechnicalIndicators::get_ema(const std::string& ticker, int length_data, 
                                           int period, const std::string& end_date, 
                                           bool live_data) {
    try {
        auto prices = get_historical_prices(ticker, end_date, length_data + period, live_data);
        auto ema_values = TAFunctions::calculate_ema(prices, period);
        
        // Extract the requested length of data
        size_t start_idx = ema_values.size() >= static_cast<size_t>(length_data) ? 
                          ema_values.size() - length_data : 0;
        
        std::vector<float> result(ema_values.begin() + start_idx, ema_values.end());
        
        return IndicatorResult(result);
        
    } catch (const std::exception& e) {
        IndicatorResult error_result;
        error_result.error_message = "Error in get_ema: " + std::string(e.what());
        return error_result;
    }
}

IndicatorResult TechnicalIndicators::get_standard_deviation(const std::string& ticker, int length_data, 
                                                          int period, const std::string& end_date, 
                                                          bool live_data) {
    try {
        auto prices = get_historical_prices(ticker, end_date, length_data + period, live_data);
        auto std_dev_values = TAFunctions::calculate_standard_deviation(prices, period);
        
        // Extract the requested length of data
        size_t start_idx = std_dev_values.size() >= static_cast<size_t>(length_data) ? 
                          std_dev_values.size() - length_data : 0;
        
        std::vector<float> result(std_dev_values.begin() + start_idx, std_dev_values.end());
        
        return IndicatorResult(result);
        
    } catch (const std::exception& e) {
        IndicatorResult error_result;
        error_result.error_message = "Error in get_standard_deviation: " + std::string(e.what());
        return error_result;
    }
}

// Mock data provider implementation
std::vector<float> TechnicalIndicators::get_historical_prices(const std::string& ticker, 
                                                            const std::string& end_date, 
                                                            int length_data, 
                                                            bool live_data) {
    // Mock implementation - in a real system, this would fetch from a data provider
    std::vector<float> prices;
    prices.reserve(length_data);
    
    // Generate mock price data with some realistic variation
    float base_price = 100.0f;
    if (ticker == "SPY") base_price = 450.0f;
    else if (ticker == "QQQ") base_price = 380.0f;
    else if (ticker == "AAPL") base_price = 180.0f;
    else if (ticker == "MSFT") base_price = 350.0f;
    
    // Generate synthetic price series with some volatility
    for (int i = 0; i < length_data; ++i) {
        float variation = (std::sin(i * 0.1f) + std::cos(i * 0.05f)) * 5.0f;
        float trend = i * 0.1f;  // Slight upward trend
        prices.push_back(base_price + variation + trend);
    }
    
    return prices;
}

} // namespace atlas