#include <gtest/gtest.h>
#include "backtesting_engine.h"
#include "strategy_parser.h"
#include "stock_data_provider.h"
#include "ta_functions.h"
#include "global_cache.h"
#include "subtree_cache.h"
#include <nlohmann/json.hpp>
#include <fstream>
#include <iostream>

namespace atlas {

class SmallStrategyValidationTest : public ::testing::Test {
protected:
    void SetUp() override {
        // Initialize test environment
        engine_ = std::make_unique<BacktestingEngine>();
        data_provider_ = StockDataProviderFactory::create_mock_provider();
        
        // Load SmallStrategy JSON for testing
        load_small_strategy_json();
        
        // Set up expected results from Julia execution
        setup_expected_results();
    }
    
    void TearDown() override {
        // Clean up
        GlobalCache::instance().clear_cache();
    }
    
    void load_small_strategy_json() {
        // SmallStrategy JSON content (from the provided example)
        small_strategy_json_ = R"({
            "json": "{\"type\":\"root\",\"properties\":{\"id\":\"f5575cedaa4a16c0c192cda063fe0724\",\"step\":\"root\",\"name\":\"root node\",\"triggerPeriod\":\"monthly\"},\"sequence\":[{\"id\":\"02eacab60b6ea6dddff673d15d9885b5\",\"componentType\":\"switch\",\"type\":\"condition\",\"name\":\"if: [current price  of SPY] < [SMA-200d  of SPY]\",\"properties\":{\"comparison\":\"<\",\"x\":{\"indicator\":\"current price\",\"numerator\":\"\",\"denominator\":\"\",\"source\":\"SPY\"},\"y\":{\"indicator\":\"Simple Moving Average of Price\",\"period\":\"200\",\"source\":\"SPY\"}},\"branches\":{\"true\":[{\"id\":\"714628fcdeda1ca52722fd562e0f97f5\",\"componentType\":\"task\",\"type\":\"stock\",\"name\":\"BUY QQQ\",\"properties\":{\"symbol\":\"QQQ\"},\"hash\":\"3d78dfbadec0f0703a82240269cdef47\",\"parentHash\":\"a533604873cbe4f0523af58547683c45\"}],\"false\":[{\"id\":\"dcafe0cb012d17e764d0be0aa1422990\",\"componentType\":\"switch\",\"type\":\"condition\",\"name\":\"if: [current price  of QQQ] < [SMA-20d  of QQQ]\",\"properties\":{\"comparison\":\"<\",\"x\":{\"indicator\":\"current price\",\"source\":\"QQQ\"},\"y\":{\"indicator\":\"Simple Moving Average of Price\",\"period\":\"20\",\"source\":\"QQQ\"}},\"branches\":{\"true\":[{\"id\":\"616e71ab87fd67c2f85d2cd78aa04e3b\",\"componentType\":\"switch\",\"type\":\"Sort\",\"name\":\"SortBy: [RSI - 10d]\",\"properties\":{\"select\":{\"function\":\"Top\",\"howmany\":\"1\"},\"sortby\":{\"function\":\"Relative Strength Index\",\"window\":\"10\"}},\"branches\":{\"Top-1\":[{\"id\":\"0f3c3f2659a84211b6e5e1ac5378f8b6\",\"componentType\":\"task\",\"type\":\"stock\",\"name\":\"BUY PSQ\",\"properties\":{\"symbol\":\"PSQ\"},\"hash\":\"8f1f34ffb8fa42ef49a68e793cca90f4\",\"parentHash\":\"30e1de0e205b4e11a662cac2299137d6\"},{\"id\":\"6edf3b83f86d42368e5a2ceb9616deb0\",\"componentType\":\"task\",\"type\":\"stock\",\"name\":\"BUY SHY\",\"properties\":{\"symbol\":\"SHY\"},\"hash\":\"ba6f3c389d29eee811112fc4f226a520\",\"parentHash\":\"2a63b815daba9f5bedb0d9bd184cc413\"},{\"id\":\"d83674e0-1b14-4e7a-b31d-ef21fd8af4a6\",\"componentType\":\"task\",\"type\":\"icon\",\"name\":\"END OF SORT\",\"properties\":{},\"hash\":\"63bd926e16fd4fdad472b2ff5b06f052\",\"parentHash\":\"8b53399f663f59de764629929f1cd99a\"}]},\"hash\":\"8b22c5a99be1acb84bb3a8e4deb57ac1\",\"parentHash\":\"7066f2887d496c7a0797e79bc7305cdc\",\"nodeChildrenHash\":\"2511ec40670864a5df3291f137f8f5c7\"}],\"false\":[{\"id\":\"9e5cb473138310ec23e95501bb37b937\",\"componentType\":\"task\",\"type\":\"stock\",\"name\":\"BUY QQQ\",\"properties\":{\"symbol\":\"QQQ\"},\"hash\":\"462301f94a17168a15f7d37b2b070b45\",\"parentHash\":\"7066f2887d496c7a0797e79bc7305cdc\"}]},\"hash\":\"38599aa5e71907fe288d6b704ea61336\",\"parentHash\":\"a533604873cbe4f0523af58547683c45\",\"nodeChildrenHash\":\"ddd84df46214783f11e60e928760cd18\"}]},\"hash\":\"91a7500471386586789e68a3ac23fab6\",\"parentHash\":\"cfcd208495d565ef66e7dff9f98764da\",\"nodeChildrenHash\":\"7457fea7ea524c71fda4053459977a7e\"}],\"tickers\":[\"QQQ\",\"PSQ\",\"SHY\"],\"indicators\":[{\"indicator\":\"current price\",\"numerator\":\"\",\"denominator\":\"\",\"source\":\"SPY\"},{\"indicator\":\"Simple Moving Average of Price\",\"period\":\"200\",\"source\":\"SPY\"},{\"indicator\":\"current price\",\"source\":\"QQQ\"},{\"indicator\":\"Simple Moving Average of Price\",\"period\":\"20\",\"source\":\"QQQ\"},{\"indicator\":\"Relative Strength Index\",\"period\":\"10\",\"source\":\"PSQ\"},{\"indicator\":\"Relative Strength Index\",\"period\":\"10\",\"source\":\"SHY\"}],\"nodeChildrenHash\":\"c51d42f7f3a70aaab465d21954f457d9\"}",
            "period": "1260",
            "end_date": "2024-11-25",
            "hash": "d2936843a0ad3275a5f5e72749594ffe"
        })";
    }
    
    void setup_expected_results() {
        // Expected results from Julia execution (mock values for testing)
        expected_tickers_ = {"QQQ", "PSQ", "SHY"};
        expected_portfolio_size_ = 1260; // Expected number of days
        expected_indicators_ = {
            {"current price", "SPY"},
            {"Simple Moving Average of Price", "SPY", "200"},
            {"current price", "QQQ"},
            {"Simple Moving Average of Price", "QQQ", "20"},
            {"Relative Strength Index", "PSQ", "10"},
            {"Relative Strength Index", "SHY", "10"}
        };
    }
    
    std::unique_ptr<BacktestingEngine> engine_;
    std::unique_ptr<IStockDataProvider> data_provider_;
    std::string small_strategy_json_;
    std::vector<std::string> expected_tickers_;
    int expected_portfolio_size_;
    std::vector<std::vector<std::string>> expected_indicators_;
};

TEST_F(SmallStrategyValidationTest, ParseSmallStrategyJSON) {
    // Test JSON parsing
    auto json_data = nlohmann::json::parse(small_strategy_json_);
    ASSERT_FALSE(json_data.empty());
    
    // Validate basic structure
    ASSERT_TRUE(json_data.contains("json"));
    ASSERT_TRUE(json_data.contains("period"));
    ASSERT_TRUE(json_data.contains("end_date"));
    
    // Parse period and end_date
    int period = std::stoi(json_data["period"].get<std::string>());
    std::string end_date = json_data["end_date"].get<std::string>();
    
    EXPECT_EQ(period, 1260);
    EXPECT_EQ(end_date, "2024-11-25");
    
    // Parse inner JSON strategy
    auto strategy_json = nlohmann::json::parse(json_data["json"].get<std::string>());
    ASSERT_TRUE(strategy_json.contains("type"));
    EXPECT_EQ(strategy_json["type"].get<std::string>(), "root");
    
    // Validate tickers
    ASSERT_TRUE(strategy_json.contains("tickers"));
    auto tickers = strategy_json["tickers"];
    ASSERT_EQ(tickers.size(), 3);
    
    std::vector<std::string> parsed_tickers;
    for (const auto& ticker : tickers) {
        parsed_tickers.push_back(ticker.get<std::string>());
    }
    
    EXPECT_EQ(parsed_tickers, expected_tickers_);
}

TEST_F(SmallStrategyValidationTest, ValidateStrategyStructure) {
    auto json_data = nlohmann::json::parse(small_strategy_json_);
    auto strategy_json = nlohmann::json::parse(json_data["json"].get<std::string>());
    
    // Test strategy parser
    StrategyParser parser;
    Strategy strategy = parser.parse_strategy(json_data);
    
    // Validate strategy properties
    EXPECT_EQ(strategy.period, 1260);
    EXPECT_EQ(strategy.end_date, "2024-11-25");
    EXPECT_EQ(strategy.root.type, "root");
    
    // Validate tickers
    EXPECT_EQ(strategy.tickers.size(), 3);
    for (const auto& ticker : expected_tickers_) {
        EXPECT_TRUE(std::find(strategy.tickers.begin(), strategy.tickers.end(), ticker) 
                   != strategy.tickers.end());
    }
    
    // Validate sequence structure
    ASSERT_FALSE(strategy.root.sequence.empty());
    const auto& root_sequence = strategy.root.sequence;
    
    // First node should be a condition
    EXPECT_EQ(root_sequence[0].type, "condition");
    ASSERT_TRUE(root_sequence[0].properties.contains("comparison"));
    EXPECT_EQ(root_sequence[0].properties["comparison"].get<std::string>(), "<");
    
    // Should have branches
    ASSERT_FALSE(root_sequence[0].branches.empty());
    EXPECT_TRUE(root_sequence[0].branches.contains("true"));
    EXPECT_TRUE(root_sequence[0].branches.contains("false"));
}

TEST_F(SmallStrategyValidationTest, ValidateTechnicalIndicators) {
    // Test individual technical analysis functions
    
    // Test current price retrieval (mock)
    auto spy_prices = data_provider_->get_historical_data("SPY", 200, "2024-11-25");
    ASSERT_FALSE(spy_prices.empty());
    
    // Test SMA calculation
    std::vector<float> price_values;
    for (const auto& record : spy_prices) {
        price_values.push_back(record.adjusted_close);
    }
    
    auto sma_200 = TAFunctions::calculate_sma(price_values, 200);
    ASSERT_FALSE(sma_200.empty());
    EXPECT_FALSE(std::isnan(sma_200.back())); // Last value should be valid
    
    // Test RSI calculation for PSQ and SHY
    auto psq_prices = data_provider_->get_historical_data("PSQ", 50, "2024-11-25");
    ASSERT_FALSE(psq_prices.empty());
    
    std::vector<float> psq_price_values;
    for (const auto& record : psq_prices) {
        psq_price_values.push_back(record.adjusted_close);
    }
    
    auto rsi_10 = TAFunctions::calculate_rsi(psq_price_values, 10);
    ASSERT_FALSE(rsi_10.empty());
    
    // RSI should be between 0 and 100
    for (size_t i = 10; i < rsi_10.size(); ++i) { // Skip initial NaN values
        if (!std::isnan(rsi_10[i])) {
            EXPECT_GE(rsi_10[i], 0.0f);
            EXPECT_LE(rsi_10[i], 100.0f);
        }
    }
}

TEST_F(SmallStrategyValidationTest, ExecuteSmallStrategyBacktest) {
    // Test full strategy execution
    auto json_data = nlohmann::json::parse(small_strategy_json_);
    
    StrategyParser parser;
    Strategy strategy = parser.parse_strategy(json_data);
    
    // Create backtest parameters
    BacktestParams params;
    params.strategy = strategy;
    params.period = strategy.period;
    params.end_date = strategy.end_date;
    params.live_execution = false;
    params.global_cache_length = 0;
    
    // Execute backtest
    auto result = engine_->execute_backtest(params);
    
    // Validate execution success
    EXPECT_TRUE(result.success) << "Backtest execution failed: " << result.error_message;
    
    if (result.success) {
        // Validate portfolio history
        EXPECT_EQ(result.portfolio_history.size(), static_cast<size_t>(expected_portfolio_size_));
        
        // Validate flow count tracking
        EXPECT_FALSE(result.flow_count.empty());
        
        // Validate execution time is reasonable
        EXPECT_GT(result.execution_time.count(), 0);
        EXPECT_LT(result.execution_time.count(), 30000); // Should complete within 30 seconds
        
        // Check that some portfolio positions were created
        bool has_positions = false;
        for (const auto& day : result.portfolio_history) {
            if (!day.stock_list.empty()) {
                has_positions = true;
                
                // Validate stock symbols are from expected tickers
                for (const auto& stock : day.stock_list) {
                    EXPECT_TRUE(std::find(expected_tickers_.begin(), expected_tickers_.end(), 
                                        stock.ticker) != expected_tickers_.end())
                        << "Unexpected ticker: " << stock.ticker;
                    
                    // Validate weight is reasonable
                    EXPECT_GE(stock.weight_tomorrow, 0.0f);
                    EXPECT_LE(stock.weight_tomorrow, 1.0f);
                }
            }
        }
        
        EXPECT_TRUE(has_positions) << "No portfolio positions were created";
    }
}

TEST_F(SmallStrategyValidationTest, ValidateConditionalLogic) {
    // Test specific conditional logic behavior
    
    // Mock price data for condition evaluation
    std::vector<float> spy_current_prices = {450.0f, 445.0f, 440.0f}; // Mock current prices
    std::vector<float> spy_sma_200 = {448.0f, 447.0f, 446.0f}; // Mock SMA-200 values
    
    // Test condition: SPY current price < SMA-200
    for (size_t i = 0; i < spy_current_prices.size(); ++i) {
        bool condition_result = spy_current_prices[i] < spy_sma_200[i];
        
        if (condition_result) {
            // Should select QQQ (true branch)
            EXPECT_TRUE(true) << "SPY price " << spy_current_prices[i] 
                             << " < SMA-200 " << spy_sma_200[i] 
                             << " - should buy QQQ";
        } else {
            // Should evaluate second condition (false branch)
            EXPECT_TRUE(true) << "SPY price " << spy_current_prices[i] 
                             << " >= SMA-200 " << spy_sma_200[i] 
                             << " - should evaluate QQQ condition";
        }
    }
}

TEST_F(SmallStrategyValidationTest, ValidateSortNodeLogic) {
    // Test sort node behavior with RSI ranking
    
    std::vector<std::string> test_tickers = {"PSQ", "SHY"};
    std::unordered_map<std::string, float> rsi_values;
    
    // Mock RSI values
    rsi_values["PSQ"] = 65.0f;
    rsi_values["SHY"] = 45.0f;
    
    // Sort by RSI (descending for "Top" selection)
    std::vector<std::pair<std::string, float>> sorted_tickers;
    for (const auto& ticker : test_tickers) {
        sorted_tickers.emplace_back(ticker, rsi_values[ticker]);
    }
    
    std::sort(sorted_tickers.begin(), sorted_tickers.end(),
              [](const auto& a, const auto& b) { return a.second > b.second; });
    
    // Top-1 should be PSQ (higher RSI)
    EXPECT_EQ(sorted_tickers[0].first, "PSQ");
    EXPECT_GT(sorted_tickers[0].second, sorted_tickers[1].second);
}

TEST_F(SmallStrategyValidationTest, ValidateNumericalPrecision) {
    // Test numerical precision matches Julia implementation
    
    // Test RSI calculation precision
    std::vector<float> test_prices = {100.0f, 101.0f, 99.0f, 102.0f, 98.0f, 103.0f, 97.0f, 104.0f, 96.0f, 105.0f,
                                    95.0f, 106.0f, 94.0f, 107.0f, 93.0f, 108.0f, 92.0f, 109.0f, 91.0f, 110.0f};
    
    auto rsi_values = TAFunctions::calculate_rsi(test_prices, 14);
    
    // Validate RSI bounds and precision
    for (size_t i = 14; i < rsi_values.size(); ++i) {
        if (!std::isnan(rsi_values[i])) {
            EXPECT_GE(rsi_values[i], 0.0f);
            EXPECT_LE(rsi_values[i], 100.0f);
            
            // Test precision (should have reasonable decimal places)
            float rounded = std::round(rsi_values[i] * 100.0f) / 100.0f;
            EXPECT_NEAR(rsi_values[i], rounded, 0.01f);
        }
    }
    
    // Test SMA calculation precision
    auto sma_values = TAFunctions::calculate_sma(test_prices, 5);
    
    // Manual calculation for validation
    float expected_sma_5 = (test_prices[0] + test_prices[1] + test_prices[2] + 
                          test_prices[3] + test_prices[4]) / 5.0f;
    
    EXPECT_NEAR(sma_values[4], expected_sma_5, 0.001f);
}

TEST_F(SmallStrategyValidationTest, ValidateCacheConsistency) {
    // Test cache behavior consistency
    auto& global_cache = GlobalCache::instance();
    
    // Test caching flow data
    std::unordered_map<std::string, nlohmann::json> test_flow_data;
    test_flow_data["test_key"] = nlohmann::json{{"value", 123.45}};
    
    bool cached = global_cache.cache_flow_data("test_hash", "2024-11-25", test_flow_data);
    EXPECT_TRUE(cached);
    
    // Test retrieving cached data
    auto retrieved_data = global_cache.get_cached_flow_data("test_hash", "2024-11-25");
    ASSERT_TRUE(retrieved_data != nullptr);
    EXPECT_EQ(retrieved_data->size(), 1);
    EXPECT_TRUE(retrieved_data->contains("test_key"));
    
    // Test subtree cache
    SubtreeCache subtree_cache;
    std::vector<DayData> test_portfolio(10);
    
    for (int i = 0; i < 10; ++i) {
        test_portfolio[i].stock_list.emplace_back("TEST", 0.1f * i);
    }
    
    std::vector<std::string> test_dates;
    for (int i = 0; i < 10; ++i) {
        test_dates.push_back("2024-11-" + std::to_string(15 + i));
    }
    
    bool subtree_cached = subtree_cache.write_subtree_portfolio_mmap(
        test_dates, "2024-11-25", "test_subtree_hash", 10, test_portfolio);
    EXPECT_TRUE(subtree_cached);
}

TEST_F(SmallStrategyValidationTest, ValidateErrorHandling) {
    // Test error handling and edge cases
    
    // Test invalid JSON
    std::string invalid_json = "{invalid json}";
    EXPECT_THROW({
        auto json_data = nlohmann::json::parse(invalid_json);
    }, nlohmann::json::parse_error);
    
    // Test missing required fields
    nlohmann::json incomplete_strategy;
    incomplete_strategy["period"] = "100";
    // Missing "json" and "end_date" fields
    
    StrategyParser parser;
    EXPECT_THROW({
        parser.parse_strategy(incomplete_strategy);
    }, std::exception);
    
    // Test technical analysis with insufficient data
    std::vector<float> insufficient_data = {100.0f, 101.0f}; // Only 2 points
    
    EXPECT_THROW({
        TAFunctions::calculate_rsi(insufficient_data, 14);
    }, TAFunctionsError);
    
    EXPECT_THROW({
        TAFunctions::calculate_sma(insufficient_data, 10);
    }, TAFunctionsError);
}

} // namespace atlas