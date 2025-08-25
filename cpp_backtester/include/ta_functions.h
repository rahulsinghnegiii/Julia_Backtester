#pragma once

#include <vector>
#include <string>
#include <memory>
#include <cmath>
#include <numeric>

namespace atlas {

/**
 * @brief Technical Analysis Functions
 * Equivalent to Julia's TAFunctions.jl functionality
 */
class TAFunctions {
public:
    /**
     * @brief Calculate Relative Strength Index (RSI)
     * @param prices Vector of price data
     * @param period RSI period (typically 14)
     * @return Vector of RSI values
     */
    static std::vector<float> calculate_rsi(const std::vector<float>& prices, int period);
    
    /**
     * @brief Calculate Simple Moving Average (SMA)
     * @param data Vector of input data
     * @param period SMA period
     * @return Vector of SMA values
     */
    static std::vector<float> calculate_sma(const std::vector<float>& data, int period);
    
    /**
     * @brief Calculate Exponential Moving Average (EMA)
     * @param data Vector of input data
     * @param period EMA period
     * @return Vector of EMA values
     */
    static std::vector<float> calculate_ema(const std::vector<float>& data, int period);
    
    /**
     * @brief Calculate Standard Deviation
     * @param data Vector of input data
     * @param period Period for rolling standard deviation
     * @return Vector of standard deviation values
     */
    static std::vector<float> calculate_standard_deviation(const std::vector<float>& data, int period);
    
    /**
     * @brief Calculate price returns
     * @param prices Vector of price data
     * @return Vector of percentage returns
     */
    static std::vector<float> calculate_returns(const std::vector<float>& prices);
    
    /**
     * @brief Calculate SMA of returns
     * @param prices Vector of price data
     * @param period SMA period
     * @return Vector of SMA return values
     */
    static std::vector<float> calculate_sma_returns(const std::vector<float>& prices, int period);
    
    /**
     * @brief Calculate standard deviation of returns
     * @param prices Vector of price data
     * @param period Period for rolling calculation
     * @return Vector of return standard deviation values
     */
    static std::vector<float> calculate_returns_standard_deviation(const std::vector<float>& prices, int period);
    
    /**
     * @brief Calculate cumulative returns
     * @param returns Vector of return data
     * @return Vector of cumulative return values
     */
    static std::vector<float> calculate_cumulative_returns(const std::vector<float>& returns);
    
    /**
     * @brief Calculate maximum drawdown
     * @param returns Vector of return data
     * @return Maximum drawdown value
     */
    static float calculate_max_drawdown(const std::vector<float>& returns);
    
    /**
     * @brief Calculate rolling maximum drawdown
     * @param returns Vector of return data
     * @param period Period for rolling calculation
     * @return Vector of maximum drawdown values
     */
    static std::vector<float> calculate_rolling_max_drawdown(const std::vector<float>& returns, int period);
    
    /**
     * @brief Calculate market cap weighting
     * @param market_caps Map of ticker to market cap
     * @return Map of ticker to weight
     */
    static std::vector<float> calculate_market_cap_weighting(const std::vector<float>& market_caps);
    
    /**
     * @brief Calculate inverse volatility weighting
     * @param volatilities Vector of volatility values
     * @return Vector of inverse volatility weights
     */
    static std::vector<float> calculate_inverse_volatility_weighting(const std::vector<float>& volatilities);
    
    /**
     * @brief Calculate portfolio daily returns
     * @param portfolio_values Vector of portfolio value data
     * @return Vector of daily return values
     */
    static std::vector<float> calculate_portfolio_daily_returns(const std::vector<float>& portfolio_values);
    
    // Utility functions
    
    /**
     * @brief Check if data has sufficient length for calculation
     * @param data_length Length of data
     * @param required_length Required minimum length
     * @return true if sufficient
     */
    static bool validate_data_length(size_t data_length, size_t required_length);
    
    /**
     * @brief Fill initial values with NaN for incomplete periods
     * @param result Vector to fill
     * @param nan_count Number of NaN values to set
     */
    static void fill_initial_nan(std::vector<float>& result, size_t nan_count);
    
    /**
     * @brief Calculate simple statistics for a window
     * @param data Vector of input data
     * @param start Start index
     * @param end End index
     * @return Pair of mean and variance
     */
    static std::pair<float, float> calculate_window_stats(const std::vector<float>& data, 
                                                         size_t start, size_t end);
    
    /**
     * @brief Apply Wilder's smoothing (used in RSI calculation)
     * @param previous_value Previous smoothed value
     * @param current_value Current value
     * @param period Smoothing period
     * @return Smoothed value
     */
    static float apply_wilders_smoothing(float previous_value, float current_value, int period);

private:
    // Constants
    static constexpr float NAN_VALUE = std::numeric_limits<float>::quiet_NaN();
    static constexpr float EPSILON = 1e-8f;
    
    // Private helper functions
    static std::vector<float> calculate_price_changes(const std::vector<float>& prices);
    static std::pair<std::vector<float>, std::vector<float>> separate_gains_losses(const std::vector<float>& changes);
    static float calculate_rs(float avg_gain, float avg_loss);
    static float calculate_ema_multiplier(int period);
};

/**
 * @brief Exception for technical analysis calculation errors
 */
class TAFunctionsError : public std::runtime_error {
public:
    explicit TAFunctionsError(const std::string& message) 
        : std::runtime_error("TA Functions error: " + message) {}
};

/**
 * @brief Indicator result structure
 */
struct IndicatorResult {
    std::vector<float> values;
    std::vector<std::string> dates;
    bool success;
    std::string error_message;
    
    IndicatorResult() : success(false) {}
    IndicatorResult(const std::vector<float>& vals) : values(vals), success(true) {}
};

/**
 * @brief High-level indicator calculation interface
 */
class TechnicalIndicators {
public:
    /**
     * @brief Get RSI for a ticker
     * @param ticker Stock ticker symbol
     * @param length_data Number of data points needed
     * @param period RSI period
     * @param end_date End date for data
     * @param live_data Live data flag
     * @return RSI indicator result
     */
    static IndicatorResult get_rsi(const std::string& ticker, int length_data, 
                                  int period, const std::string& end_date, 
                                  bool live_data = false);
    
    /**
     * @brief Get SMA for a ticker
     * @param ticker Stock ticker symbol
     * @param length_data Number of data points needed
     * @param period SMA period
     * @param end_date End date for data
     * @param live_data Live data flag
     * @return SMA indicator result
     */
    static IndicatorResult get_sma(const std::string& ticker, int length_data, 
                                  int period, const std::string& end_date, 
                                  bool live_data = false);
    
    /**
     * @brief Get EMA for a ticker
     * @param ticker Stock ticker symbol
     * @param length_data Number of data points needed
     * @param period EMA period
     * @param end_date End date for data
     * @param live_data Live data flag
     * @return EMA indicator result
     */
    static IndicatorResult get_ema(const std::string& ticker, int length_data, 
                                  int period, const std::string& end_date, 
                                  bool live_data = false);
    
    /**
     * @brief Get standard deviation for a ticker
     * @param ticker Stock ticker symbol
     * @param length_data Number of data points needed
     * @param period Standard deviation period
     * @param end_date End date for data
     * @param live_data Live data flag
     * @return Standard deviation indicator result
     */
    static IndicatorResult get_standard_deviation(const std::string& ticker, int length_data, 
                                                 int period, const std::string& end_date, 
                                                 bool live_data = false);

private:
    // Mock data provider - in real implementation, this would fetch from data source
    static std::vector<float> get_historical_prices(const std::string& ticker, 
                                                   const std::string& end_date, 
                                                   int length_data, 
                                                   bool live_data = false);
};

} // namespace atlas