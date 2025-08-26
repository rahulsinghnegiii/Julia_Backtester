#include <gtest/gtest.h>
#include "ta_functions.h"
#include <vector>
#include <cmath>
#include <algorithm>

using namespace atlas;

class TAFunctionsTest : public ::testing::Test {
protected:
    void SetUp() override {
        // Setup test data
        test_prices = {100.0f, 102.0f, 101.0f, 103.0f, 105.0f, 104.0f, 106.0f, 108.0f, 107.0f, 109.0f,
                      111.0f, 110.0f, 112.0f, 114.0f, 113.0f, 115.0f, 117.0f, 116.0f, 118.0f, 120.0f};
        
        // Additional test data for longer period tests
        long_prices.resize(250);
        for (size_t i = 0; i < long_prices.size(); ++i) {
            long_prices[i] = 100.0f + std::sin(i * 0.1f) * 10.0f + i * 0.05f;
        }
    }
    
    std::vector<float> test_prices;
    std::vector<float> long_prices;
    
    bool is_close(float a, float b, float tolerance = 0.001f) {
        return std::abs(a - b) < tolerance;
    }
    
    bool is_nan(float value) {
        return std::isnan(value);
    }
};

// ============================================================================
// SMA (Simple Moving Average) Tests
// ============================================================================

TEST_F(TAFunctionsTest, SMA_BasicCalculation) {
    auto sma_5 = TAFunctions::calculate_sma(test_prices, 5);
    
    EXPECT_EQ(sma_5.size(), test_prices.size());
    
    // First 4 values should be NaN
    for (int i = 0; i < 4; ++i) {
        EXPECT_TRUE(is_nan(sma_5[i])) << "Index " << i << " should be NaN";
    }
    
    // Calculate expected SMA for index 4 (first valid SMA)
    float expected_sma_4 = (100.0f + 102.0f + 101.0f + 103.0f + 105.0f) / 5.0f;
    EXPECT_TRUE(is_close(sma_5[4], expected_sma_4)) 
        << "SMA[4] expected: " << expected_sma_4 << ", got: " << sma_5[4];
    
    // Calculate expected SMA for index 5
    float expected_sma_5 = (102.0f + 101.0f + 103.0f + 105.0f + 104.0f) / 5.0f;
    EXPECT_TRUE(is_close(sma_5[5], expected_sma_5))
        << "SMA[5] expected: " << expected_sma_5 << ", got: " << sma_5[5];
}

TEST_F(TAFunctionsTest, SMA_Period1) {
    auto sma_1 = TAFunctions::calculate_sma(test_prices, 1);
    
    EXPECT_EQ(sma_1.size(), test_prices.size());
    
    // SMA with period 1 should equal original prices
    for (size_t i = 0; i < test_prices.size(); ++i) {
        EXPECT_TRUE(is_close(sma_1[i], test_prices[i]))
            << "Index " << i << " expected: " << test_prices[i] << ", got: " << sma_1[i];
    }
}

TEST_F(TAFunctionsTest, SMA_LongPeriod) {
    auto sma_200 = TAFunctions::calculate_sma(long_prices, 200);
    
    EXPECT_EQ(sma_200.size(), long_prices.size());
    
    // First 199 values should be NaN
    for (int i = 0; i < 199; ++i) {
        EXPECT_TRUE(is_nan(sma_200[i])) << "Index " << i << " should be NaN";
    }
    
    // Check that SMA values are calculated for valid indices
    for (size_t i = 199; i < long_prices.size(); ++i) {
        EXPECT_FALSE(is_nan(sma_200[i])) << "Index " << i << " should not be NaN";
        EXPECT_GT(sma_200[i], 0.0f) << "SMA should be positive at index " << i;
    }
}

TEST_F(TAFunctionsTest, SMA_InsufficientData) {
    std::vector<float> short_data = {100.0f, 101.0f, 102.0f};
    
    EXPECT_THROW({
        TAFunctions::calculate_sma(short_data, 5);
    }, TAFunctionsError);
}

TEST_F(TAFunctionsTest, SMA_EmptyData) {
    std::vector<float> empty_data;
    
    EXPECT_THROW({
        TAFunctions::calculate_sma(empty_data, 5);
    }, TAFunctionsError);
}

// ============================================================================
// RSI (Relative Strength Index) Tests
// ============================================================================

TEST_F(TAFunctionsTest, RSI_BasicCalculation) {
    auto rsi_10 = TAFunctions::calculate_rsi(test_prices, 10);
    
    EXPECT_EQ(rsi_10.size(), test_prices.size());
    
    // First 10 values should be NaN (need period+1 data points)
    for (int i = 0; i < 10; ++i) {
        EXPECT_TRUE(is_nan(rsi_10[i])) << "Index " << i << " should be NaN";
    }
    
    // RSI values should be between 0 and 100
    for (size_t i = 10; i < rsi_10.size(); ++i) {
        if (!is_nan(rsi_10[i])) {
            EXPECT_GE(rsi_10[i], 0.0f) << "RSI should be >= 0 at index " << i;
            EXPECT_LE(rsi_10[i], 100.0f) << "RSI should be <= 100 at index " << i;
        }
    }
}

TEST_F(TAFunctionsTest, RSI_TrendingUpPrices) {
    // Create strongly trending up prices
    std::vector<float> up_trend;
    for (int i = 0; i < 20; ++i) {
        up_trend.push_back(100.0f + i * 2.0f);  // Consistent upward trend
    }
    
    auto rsi_14 = TAFunctions::calculate_rsi(up_trend, 14);
    
    // RSI should be high for strongly trending up prices
    for (size_t i = 14; i < rsi_14.size(); ++i) {
        if (!is_nan(rsi_14[i])) {
            EXPECT_GT(rsi_14[i], 50.0f) << "RSI should be > 50 for uptrend at index " << i;
        }
    }
}

TEST_F(TAFunctionsTest, RSI_TrendingDownPrices) {
    // Create strongly trending down prices
    std::vector<float> down_trend;
    for (int i = 0; i < 20; ++i) {
        down_trend.push_back(120.0f - i * 2.0f);  // Consistent downward trend
    }
    
    auto rsi_14 = TAFunctions::calculate_rsi(down_trend, 14);
    
    // RSI should be low for strongly trending down prices
    for (size_t i = 14; i < rsi_14.size(); ++i) {
        if (!is_nan(rsi_14[i])) {
            EXPECT_LT(rsi_14[i], 50.0f) << "RSI should be < 50 for downtrend at index " << i;
        }
    }
}

TEST_F(TAFunctionsTest, RSI_SidewaysPrices) {
    // Create sideways/flat prices
    std::vector<float> sideways_prices;
    for (int i = 0; i < 20; ++i) {
        sideways_prices.push_back(100.0f + (i % 2 == 0 ? 0.5f : -0.5f));  // Minor oscillation
    }
    
    auto rsi_14 = TAFunctions::calculate_rsi(sideways_prices, 14);
    
    // RSI should be around 50 for sideways prices
    for (size_t i = 14; i < rsi_14.size(); ++i) {
        if (!is_nan(rsi_14[i])) {
            EXPECT_GT(rsi_14[i], 30.0f) << "RSI should be > 30 for sideways at index " << i;
            EXPECT_LT(rsi_14[i], 70.0f) << "RSI should be < 70 for sideways at index " << i;
        }
    }
}

TEST_F(TAFunctionsTest, RSI_InsufficientData) {
    std::vector<float> short_data = {100.0f, 101.0f, 102.0f};
    
    EXPECT_THROW({
        TAFunctions::calculate_rsi(short_data, 14);
    }, TAFunctionsError);
}

TEST_F(TAFunctionsTest, RSI_Period14_StandardCase) {
    auto rsi_14 = TAFunctions::calculate_rsi(long_prices, 14);
    
    EXPECT_EQ(rsi_14.size(), long_prices.size());
    
    // First 14 values should be NaN
    for (int i = 0; i < 14; ++i) {
        EXPECT_TRUE(is_nan(rsi_14[i])) << "Index " << i << " should be NaN";
    }
    
    // Check valid RSI calculations
    int valid_count = 0;
    for (size_t i = 14; i < rsi_14.size(); ++i) {
        if (!is_nan(rsi_14[i])) {
            valid_count++;
            EXPECT_GE(rsi_14[i], 0.0f) << "RSI should be >= 0 at index " << i;
            EXPECT_LE(rsi_14[i], 100.0f) << "RSI should be <= 100 at index " << i;
        }
    }
    
    EXPECT_GT(valid_count, 0) << "Should have valid RSI calculations";
}

// ============================================================================
// Helper Functions Tests
// ============================================================================

TEST_F(TAFunctionsTest, ValidateDataLength) {
    EXPECT_TRUE(TAFunctions::validate_data_length(10, 5));
    EXPECT_TRUE(TAFunctions::validate_data_length(5, 5));
    EXPECT_FALSE(TAFunctions::validate_data_length(4, 5));
    EXPECT_FALSE(TAFunctions::validate_data_length(0, 1));
}

TEST_F(TAFunctionsTest, CalculateReturns) {
    auto returns = TAFunctions::calculate_returns(test_prices);
    
    EXPECT_EQ(returns.size(), test_prices.size() - 1);
    
    // Calculate expected first return: (102-100)/100 * 100 = 2%
    float expected_first_return = 100.0f * (102.0f - 100.0f) / 100.0f;
    EXPECT_TRUE(is_close(returns[0], expected_first_return))
        << "First return expected: " << expected_first_return << ", got: " << returns[0];
    
    // Calculate expected second return: (101-102)/102 * 100
    float expected_second_return = 100.0f * (101.0f - 102.0f) / 102.0f;
    EXPECT_TRUE(is_close(returns[1], expected_second_return))
        << "Second return expected: " << expected_second_return << ", got: " << returns[1];
}

// ============================================================================
// SmallStrategy Specific Tests
// ============================================================================

TEST_F(TAFunctionsTest, SmallStrategy_SMA200_Integration) {
    // Test SMA-200 calculation specifically for SmallStrategy
    auto sma_200 = TAFunctions::calculate_sma(long_prices, 200);
    
    // Verify we get valid values after the initial period
    size_t valid_start = 199;  // 200-1
    EXPECT_LT(valid_start, long_prices.size()) << "Test data should be sufficient for SMA-200";
    
    if (valid_start < long_prices.size()) {
        EXPECT_FALSE(is_nan(sma_200[valid_start])) << "First valid SMA-200 should not be NaN";
        EXPECT_GT(sma_200[valid_start], 0.0f) << "SMA-200 should be positive";
        
        // Verify SMA value is reasonable compared to price range
        float min_price = *std::min_element(long_prices.begin(), long_prices.begin() + 200);
        float max_price = *std::max_element(long_prices.begin(), long_prices.begin() + 200);
        
        EXPECT_GE(sma_200[valid_start], min_price) << "SMA should be >= minimum price in period";
        EXPECT_LE(sma_200[valid_start], max_price) << "SMA should be <= maximum price in period";
    }
}

TEST_F(TAFunctionsTest, SmallStrategy_SMA20_Integration) {
    // Test SMA-20 calculation specifically for SmallStrategy
    auto sma_20 = TAFunctions::calculate_sma(test_prices, 20);
    
    // Since test_prices has only 20 elements, only the last element should be valid
    for (int i = 0; i < 19; ++i) {
        EXPECT_TRUE(is_nan(sma_20[i])) << "Index " << i << " should be NaN";
    }
    
    if (test_prices.size() >= 20) {
        EXPECT_FALSE(is_nan(sma_20[19])) << "Last SMA-20 value should be valid";
        
        // Manual calculation for verification
        float expected_sma = 0.0f;
        for (const auto& price : test_prices) {
            expected_sma += price;
        }
        expected_sma /= test_prices.size();
        
        EXPECT_TRUE(is_close(sma_20[19], expected_sma))
            << "SMA-20 expected: " << expected_sma << ", got: " << sma_20[19];
    }
}

TEST_F(TAFunctionsTest, SmallStrategy_RSI10_Integration) {
    // Test RSI-10 calculation specifically for SmallStrategy
    auto rsi_10 = TAFunctions::calculate_rsi(test_prices, 10);
    
    // Verify structure
    EXPECT_EQ(rsi_10.size(), test_prices.size());
    
    // First 10 values should be NaN
    for (int i = 0; i < 10; ++i) {
        EXPECT_TRUE(is_nan(rsi_10[i])) << "Index " << i << " should be NaN for RSI-10";
    }
    
    // Check valid RSI values
    for (size_t i = 10; i < rsi_10.size(); ++i) {
        if (!is_nan(rsi_10[i])) {
            EXPECT_GE(rsi_10[i], 0.0f) << "RSI-10 should be >= 0 at index " << i;
            EXPECT_LE(rsi_10[i], 100.0f) << "RSI-10 should be <= 100 at index " << i;
        }
    }
}

// ============================================================================
// Performance and Edge Cases
// ============================================================================

TEST_F(TAFunctionsTest, Performance_LargeDataset) {
    // Test with larger dataset (simulating real-world scenario)
    std::vector<float> large_dataset(1000);
    for (size_t i = 0; i < large_dataset.size(); ++i) {
        large_dataset[i] = 100.0f + std::sin(i * 0.01f) * 20.0f + (i % 10) * 0.5f;
    }
    
    auto start = std::chrono::high_resolution_clock::now();
    auto sma_50 = TAFunctions::calculate_sma(large_dataset, 50);
    auto rsi_14 = TAFunctions::calculate_rsi(large_dataset, 14);
    auto end = std::chrono::high_resolution_clock::now();
    
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);
    
    EXPECT_LT(duration.count(), 100) << "TA calculations should be fast (< 100ms for 1000 data points)";
    EXPECT_EQ(sma_50.size(), large_dataset.size());
    EXPECT_EQ(rsi_14.size(), large_dataset.size());
}

TEST_F(TAFunctionsTest, EdgeCase_ZeroPrices) {
    std::vector<float> zero_prices = {0.0f, 0.0f, 0.0f, 0.0f, 0.0f};
    
    // SMA of zeros should be zero
    auto sma_3 = TAFunctions::calculate_sma(zero_prices, 3);
    for (size_t i = 2; i < sma_3.size(); ++i) {
        EXPECT_TRUE(is_close(sma_3[i], 0.0f)) << "SMA of zeros should be zero at index " << i;
    }
    
    // RSI with zero prices should handle gracefully
    EXPECT_NO_THROW({
        auto rsi_3 = TAFunctions::calculate_rsi(zero_prices, 3);
    });
}

TEST_F(TAFunctionsTest, EdgeCase_ConstantPrices) {
    std::vector<float> constant_prices(20, 100.0f);
    
    // SMA of constant prices should equal the constant
    auto sma_5 = TAFunctions::calculate_sma(constant_prices, 5);
    for (size_t i = 4; i < sma_5.size(); ++i) {
        EXPECT_TRUE(is_close(sma_5[i], 100.0f)) << "SMA of constant should be constant at index " << i;
    }
    
    // RSI of constant prices should be around 50 (or NaN due to zero gains/losses)
    auto rsi_10 = TAFunctions::calculate_rsi(constant_prices, 10);
    for (size_t i = 10; i < rsi_10.size(); ++i) {
        // Either NaN (no price changes) or around 50
        if (!is_nan(rsi_10[i])) {
            EXPECT_TRUE(is_close(rsi_10[i], 50.0f, 5.0f)) 
                << "RSI of constant prices should be around 50 at index " << i;
        }
    }
}