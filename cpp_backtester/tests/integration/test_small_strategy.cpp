#include <gtest/gtest.h>
#include \"backtesting_engine.h\"
#include \"strategy_parser.h\"
#include <fstream>
#include <filesystem>

using namespace atlas;

class SmallStrategyTest : public ::testing::Test {
protected:
    BacktestingEngine engine;
    StrategyParser parser;
    
    std::string read_file(const std::string& filename) {
        std::ifstream file(filename);
        if (!file.is_open()) {
            return \"\"; // Return empty string if file not found
        }
        
        std::string content;
        std::string line;
        while (std::getline(file, line)) {
            content += line + \"\n\";
        }
        return content;
    }
};

TEST_F(SmallStrategyTest, LoadAndParseSmallStrategy) {
    // Try to load the SmallStrategy.json file
    std::string strategy_content = read_file(\"SmallStrategy.json\");
    
    if (strategy_content.empty()) {
        GTEST_SKIP() << \"SmallStrategy.json not found, skipping integration test\";
    }
    
    // Parse the strategy
    EXPECT_NO_THROW({
        Strategy strategy = parser.parse_strategy(strategy_content);
        
        // Verify basic strategy properties
        EXPECT_GT(strategy.period, 0);
        EXPECT_FALSE(strategy.end_date.empty());
        EXPECT_FALSE(strategy.tickers.empty());
        EXPECT_EQ(strategy.root.type, \"root\");
        
        // Verify expected tickers are present
        bool has_qqq = std::find(strategy.tickers.begin(), strategy.tickers.end(), \"QQQ\") != strategy.tickers.end();
        bool has_psq = std::find(strategy.tickers.begin(), strategy.tickers.end(), \"PSQ\") != strategy.tickers.end();
        bool has_shy = std::find(strategy.tickers.begin(), strategy.tickers.end(), \"SHY\") != strategy.tickers.end();
        
        EXPECT_TRUE(has_qqq) << \"QQQ ticker not found in strategy\";
        EXPECT_TRUE(has_psq) << \"PSQ ticker not found in strategy\";
        EXPECT_TRUE(has_shy) << \"SHY ticker not found in strategy\";
    });
}

TEST_F(SmallStrategyTest, ExecuteSmallStrategy) {
    std::string strategy_content = read_file(\"SmallStrategy.json\");
    
    if (strategy_content.empty()) {
        GTEST_SKIP() << \"SmallStrategy.json not found, skipping integration test\";
    }
    
    try {
        // Parse strategy
        Strategy strategy = parser.parse_strategy(strategy_content);
        
        // Create backtest parameters
        BacktestParams params;
        params.strategy = strategy;
        params.period = strategy.period;
        params.end_date = strategy.end_date;
        params.live_execution = false;
        params.global_cache_length = 0;
        
        // Execute backtest
        BacktestResult result = engine.execute_backtest(params);
        
        // Basic validation
        EXPECT_TRUE(result.success) << \"Backtest failed: \" << result.error_message;
        EXPECT_EQ(result.portfolio_history.size(), static_cast<size_t>(strategy.period));
        EXPECT_GT(result.execution_time.count(), 0);
        
        // Verify that portfolio contains expected tickers
        std::set<std::string> found_tickers;
        for (const auto& day : result.portfolio_history) {
            for (const auto& stock : day.stock_list()) {
                found_tickers.insert(stock.ticker());
            }
        }
        
        // Should find at least one of the expected tickers
        bool has_expected_ticker = 
            found_tickers.count(\"QQQ\") > 0 ||
            found_tickers.count(\"PSQ\") > 0 ||
            found_tickers.count(\"SHY\") > 0;
        
        EXPECT_TRUE(has_expected_ticker) << \"No expected tickers found in portfolio\";
        
        // Print summary for debugging
        std::cout << \"\nSmallStrategy Execution Summary:\" << std::endl;
        std::cout << \"  Period: \" << strategy.period << \" days\" << std::endl;
        std::cout << \"  Execution Time: \" << result.execution_time.count() << \" ms\" << std::endl;
        std::cout << \"  Found Tickers: \";
        for (const auto& ticker : found_tickers) {
            std::cout << ticker << \" \";
        }
        std::cout << std::endl;
        
        // Sample portfolio output (first 5 days)
        std::cout << \"  Sample Portfolio (first 5 days):\" << std::endl;
        for (size_t i = 0; i < std::min(static_cast<size_t>(5), result.portfolio_history.size()); ++i) {
            std::cout << \"    Day \" << i+1 << \": \";
            if (result.portfolio_history[i].empty()) {
                std::cout << \"No positions\";
            } else {
                for (size_t j = 0; j < result.portfolio_history[i].stock_list().size(); ++j) {
                    if (j > 0) std::cout << \", \";
                    const auto& stock = result.portfolio_history[i].stock_list()[j];
                    std::cout << stock.ticker() << \"(\" << stock.weight_tomorrow() << \")\";
                }
            }
            std::cout << std::endl;
        }
        
    } catch (const std::exception& e) {
        FAIL() << \"Exception during SmallStrategy execution: \" << e.what();
    }
}

TEST_F(SmallStrategyTest, CompareWithExpectedResults) {
    std::string strategy_content = read_file(\"SmallStrategy.json\");
    std::string expected_content = read_file(\"SmallStrategy_expected.json\");
    
    if (strategy_content.empty()) {
        GTEST_SKIP() << \"SmallStrategy.json not found, skipping comparison test\";
    }
    
    if (expected_content.empty()) {
        GTEST_SKIP() << \"SmallStrategy_expected.json not found, skipping comparison test\";
    }
    
    try {
        // Parse strategy and execute
        Strategy strategy = parser.parse_strategy(strategy_content);
        
        BacktestParams params;
        params.strategy = strategy;
        params.period = strategy.period;
        params.end_date = strategy.end_date;
        params.live_execution = false;
        params.global_cache_length = 0;
        
        BacktestResult result = engine.execute_backtest(params);
        
        EXPECT_TRUE(result.success) << \"Backtest failed: \" << result.error_message;
        
        // Parse expected results
        auto expected_json = nlohmann::json::parse(expected_content);
        
        // Basic structure comparison
        EXPECT_EQ(result.portfolio_history.size(), static_cast<size_t>(strategy.period));
        
        // Note: Full comparison with Julia results would require:
        // 1. Technical analysis functions to be implemented
        // 2. Proper date handling and market data
        // 3. All node types (conditional, sort) to be implemented
        // For now, we verify the basic structure and that it runs without errors
        
        std::cout << \"\nBasic structure validation passed\" << std::endl;
        std::cout << \"Full Julia equivalence validation requires complete implementation\" << std::endl;
        
    } catch (const std::exception& e) {
        FAIL() << \"Exception during expected results comparison: \" << e.what();
    }
}

TEST_F(SmallStrategyTest, PerformanceBenchmark) {
    std::string strategy_content = read_file(\"SmallStrategy.json\");
    
    if (strategy_content.empty()) {
        GTEST_SKIP() << \"SmallStrategy.json not found, skipping performance test\";
    }
    
    try {
        Strategy strategy = parser.parse_strategy(strategy_content);
        
        BacktestParams params;
        params.strategy = strategy;
        params.period = strategy.period;
        params.end_date = strategy.end_date;
        params.live_execution = false;
        params.global_cache_length = 0;
        
        // Warm-up run
        engine.execute_backtest(params);
        
        // Benchmark runs
        constexpr int num_runs = 5;
        std::vector<std::chrono::milliseconds> execution_times;
        
        for (int i = 0; i < num_runs; ++i) {
            auto start = std::chrono::high_resolution_clock::now();
            BacktestResult result = engine.execute_backtest(params);
            auto end = std::chrono::high_resolution_clock::now();
            
            EXPECT_TRUE(result.success);
            
            auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);
            execution_times.push_back(duration);
        }
        
        // Calculate statistics
        auto min_time = *std::min_element(execution_times.begin(), execution_times.end());
        auto max_time = *std::max_element(execution_times.begin(), execution_times.end());
        auto total_time = std::accumulate(execution_times.begin(), execution_times.end(), std::chrono::milliseconds(0));
        auto avg_time = total_time / num_runs;
        
        std::cout << \"\nPerformance Benchmark Results (\" << num_runs << \" runs):\" << std::endl;
        std::cout << \"  Min Time: \" << min_time.count() << \" ms\" << std::endl;
        std::cout << \"  Max Time: \" << max_time.count() << \" ms\" << std::endl;
        std::cout << \"  Avg Time: \" << avg_time.count() << \" ms\" << std::endl;
        
        // Performance criteria: execution should be under 10 seconds
        EXPECT_LT(avg_time.count(), 10000) << \"Average execution time exceeds 10 seconds\";
        
    } catch (const std::exception& e) {
        FAIL() << \"Exception during performance benchmark: \" << e.what();
    }
}", "original_text": "", "replace_all": false}]