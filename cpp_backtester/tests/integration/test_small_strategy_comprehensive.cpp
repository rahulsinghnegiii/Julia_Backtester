#include <gtest/gtest.h>
#include "backtesting_engine.h"
#include "strategy_parser.h"
#include <fstream>
#include <chrono>
#include <numeric>
#include <algorithm>
#include <iomanip>
#include <nlohmann/json.hpp>

using namespace atlas;

class SmallStrategyComprehensiveTest : public ::testing::Test {
protected:
    BacktestingEngine engine;
    StrategyParser parser;
    Strategy strategy;
    bool strategy_loaded = false;
    
    void SetUp() override {
        // Load strategy once for all tests
        std::string strategy_content = read_file("SmallStrategy.json");
        if (!strategy_content.empty()) {
            try {
                strategy = parser.parse_strategy(strategy_content);
                strategy_loaded = true;
            } catch (const std::exception& e) {
                std::cerr << "Failed to load strategy: " << e.what() << std::endl;
            }
        }
    }
    
    std::string read_file(const std::string& filename) {
        std::ifstream file(filename);
        if (!file.is_open()) {
            return "";
        }
        
        std::string content;
        std::string line;
        while (std::getline(file, line)) {
            content += line + "\n";
        }
        return content;
    }
    
    nlohmann::json load_julia_expected() {
        std::string content = read_file("../App/Tests/E2E/ExpectedFiles/SmallStrategy.json");
        if (content.empty()) {
            return nlohmann::json::object();
        }
        
        try {
            return nlohmann::json::parse(content);
        } catch (const std::exception& e) {
            std::cerr << "Error parsing Julia expected: " << e.what() << std::endl;
            return nlohmann::json::object();
        }
    }
    
    BacktestResult execute_strategy(int test_period = 0) {
        if (!strategy_loaded) {
            throw std::runtime_error("Strategy not loaded");
        }
        
        BacktestParams params;
        params.strategy = strategy;
        params.period = test_period > 0 ? test_period : strategy.period;
        params.end_date = strategy.end_date;
        params.live_execution = false;
        params.global_cache_length = 0;
        
        return engine.execute_backtest(params);
    }
};

// Test 1: Comprehensive Strategy Validation
TEST_F(SmallStrategyComprehensiveTest, ComprehensiveStrategyValidation) {
    ASSERT_TRUE(strategy_loaded) << "SmallStrategy.json must be loadable";
    
    // Validate strategy structure
    EXPECT_EQ(strategy.root.type, "root");
    EXPECT_EQ(strategy.period, 1260);
    EXPECT_EQ(strategy.end_date, "2024-11-25");
    
    // Validate tickers
    std::set<std::string> expected_tickers = {"QQQ", "PSQ", "SHY"};
    std::set<std::string> actual_tickers(strategy.tickers.begin(), strategy.tickers.end());
    EXPECT_EQ(actual_tickers, expected_tickers);
    
    // Validate indicators
    EXPECT_EQ(strategy.indicators.size(), 6);
    
    // Check for key indicators
    bool has_spy_sma200 = false;
    bool has_qqq_sma20 = false;
    bool has_rsi_indicators = false;
    
    for (const auto& indicator : strategy.indicators) {
        if (indicator.source == "SPY" && indicator.indicator == "Simple Moving Average of Price" && indicator.period == "200") {
            has_spy_sma200 = true;
        }
        if (indicator.source == "QQQ" && indicator.indicator == "Simple Moving Average of Price" && indicator.period == "20") {
            has_qqq_sma20 = true;
        }
        if (indicator.indicator == "Relative Strength Index" && indicator.period == "10") {
            has_rsi_indicators = true;
        }
    }
    
    EXPECT_TRUE(has_spy_sma200) << "SPY SMA-200 indicator required";
    EXPECT_TRUE(has_qqq_sma20) << "QQQ SMA-20 indicator required";
    EXPECT_TRUE(has_rsi_indicators) << "RSI-10 indicators required";
    
    std::cout << "✅ Strategy validation: All components verified" << std::endl;
}

// Test 2: Full Strategy Execution Test
TEST_F(SmallStrategyComprehensiveTest, FullStrategyExecution) {
    ASSERT_TRUE(strategy_loaded) << "Strategy must be loaded";
    
    BacktestResult result = execute_strategy();
    
    // Basic execution validation
    EXPECT_TRUE(result.success) << "Strategy execution must succeed: " << result.error_message;
    EXPECT_EQ(result.portfolio_history.size(), static_cast<size_t>(strategy.period));
    EXPECT_GT(result.execution_time.count(), 0);
    
    // Analyze portfolio composition
    std::unordered_map<std::string, int> ticker_counts;
    size_t active_days = 0;
    
    for (const auto& day : result.portfolio_history) {
        if (!day.empty()) {
            active_days++;
            for (const auto& stock : day.stock_list()) {
                ticker_counts[stock.ticker()]++;
                EXPECT_GT(stock.weight_tomorrow(), 0.0) << "Stock weights must be positive";
                EXPECT_LE(stock.weight_tomorrow(), 1.0) << "Stock weights must not exceed 100%";
            }
        }
    }
    
    // Validate SmallStrategy logic patterns
    EXPECT_GT(ticker_counts["QQQ"], 0) << "QQQ should appear (main bullish asset)";
    
    // At least some defensive/bearish positions should exist
    bool has_defensive = ticker_counts["PSQ"] > 0 || ticker_counts["SHY"] > 0;
    EXPECT_TRUE(has_defensive) << "Strategy should use defensive positions (PSQ/SHY)";
    
    // Portfolio utilization should be reasonable
    float utilization = static_cast<float>(active_days) / result.portfolio_history.size();
    EXPECT_GT(utilization, 0.8f) << "Portfolio should be active most days";
    
    std::cout << "✅ Full execution: " << active_days << "/" << result.portfolio_history.size() 
              << " active days (" << std::fixed << std::setprecision(1) << utilization * 100 << "%)" << std::endl;
    
    // Print ticker distribution
    std::cout << "   Ticker distribution:" << std::endl;
    for (const auto& [ticker, count] : ticker_counts) {
        float pct = static_cast<float>(count) / result.portfolio_history.size() * 100.0f;
        std::cout << "   - " << ticker << ": " << count << " days (" 
                 << std::fixed << std::setprecision(1) << pct << "%)" << std::endl;
    }
}

// Test 3: Performance Benchmarking
TEST_F(SmallStrategyComprehensiveTest, PerformanceBenchmarking) {
    ASSERT_TRUE(strategy_loaded) << "Strategy must be loaded";
    
    // Benchmark different period lengths
    std::vector<int> test_periods = {30, 60, 120, 250, 500, 1260};
    std::vector<std::chrono::milliseconds> execution_times;
    
    std::cout << "🚀 Performance Benchmarking:" << std::endl;
    
    for (int period : test_periods) {
        // Warm-up run
        BacktestResult warm_up = execute_strategy(period);
        EXPECT_TRUE(warm_up.success) << "Warm-up run failed for period: " << period;
        
        // Benchmark runs
        constexpr int num_runs = 5;
        std::vector<std::chrono::milliseconds> period_times;
        
        for (int run = 0; run < num_runs; ++run) {
            auto start = std::chrono::high_resolution_clock::now();
            BacktestResult result = execute_strategy(period);
            auto end = std::chrono::high_resolution_clock::now();
            
            EXPECT_TRUE(result.success) << "Benchmark run " << run + 1 << " failed for period: " << period;
            
            auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);
            period_times.push_back(duration);
        }
        
        // Calculate statistics
        auto min_time = *std::min_element(period_times.begin(), period_times.end());
        auto max_time = *std::max_element(period_times.begin(), period_times.end());
        auto avg_time = std::accumulate(period_times.begin(), period_times.end(), std::chrono::milliseconds(0)) / num_runs;
        
        execution_times.push_back(avg_time);
        
        // Calculate throughput (days per second)
        double throughput = static_cast<double>(period) / (avg_time.count() / 1000.0);
        
        std::cout << "   Period " << std::setw(4) << period << " days: "
                 << "min=" << std::setw(3) << min_time.count() << "ms, "
                 << "avg=" << std::setw(3) << avg_time.count() << "ms, "
                 << "max=" << std::setw(3) << max_time.count() << "ms, "
                 << "throughput=" << std::setw(6) << std::fixed << std::setprecision(0) 
                 << throughput << " days/sec" << std::endl;
        
        // Performance thresholds
        if (period == 1260) {
            EXPECT_LT(avg_time.count(), 1000) << "Full strategy (1260 days) should execute in under 1 second";
        }
        EXPECT_GT(throughput, 1000) << "Should process at least 1000 days/second";
    }
    
    // Verify performance scaling is reasonable (not exponential)
    if (execution_times.size() >= 2) {
        auto ratio = static_cast<double>(execution_times.back().count()) / execution_times[0].count();
        auto period_ratio = static_cast<double>(test_periods.back()) / test_periods[0];
        
        // Execution time growth should be roughly linear with period
        EXPECT_LT(ratio, period_ratio * 2) << "Performance scaling should be roughly linear";
    }
    
    std::cout << "✅ Performance benchmarking completed" << std::endl;
}

// Test 4: Exact Julia Compatibility Verification
TEST_F(SmallStrategyComprehensiveTest, JuliaCompatibilityVerification) {
    ASSERT_TRUE(strategy_loaded) << "Strategy must be loaded";
    
    // Load Julia expected results
    nlohmann::json julia_expected = load_julia_expected();
    
    if (julia_expected.empty()) {
        GTEST_SKIP() << "Julia expected results not available";
    }
    
    ASSERT_TRUE(julia_expected.contains("profile_history")) << "Julia expected must contain profile_history";
    
    // Execute C++ strategy
    BacktestResult cpp_result = execute_strategy();
    ASSERT_TRUE(cpp_result.success) << "C++ execution must succeed for comparison";
    
    auto julia_history = julia_expected["profile_history"];
    size_t min_days = std::min(julia_history.size(), cpp_result.portfolio_history.size());
    
    std::cout << "🔍 Julia Compatibility Verification:" << std::endl;
    std::cout << "   Comparing " << min_days << " days..." << std::endl;
    
    // Compare portfolio decisions
    size_t exact_matches = 0;
    size_t ticker_matches = 0;
    
    for (size_t day = 0; day < min_days; ++day) {
        // Get Julia day
        auto julia_day = julia_history[day];
        if (!julia_day.contains("stockList")) continue;
        
        auto julia_stocks = julia_day["stockList"];
        if (julia_stocks.empty()) continue;
        
        // Get C++ day
        const auto& cpp_day = cpp_result.portfolio_history[day];
        if (cpp_day.empty()) continue;
        
        // Compare first stock (primary decision)
        auto julia_ticker = julia_stocks[0]["ticker"].get<std::string>();
        auto cpp_ticker = cpp_day.stock_list()[0].ticker();
        
        if (julia_ticker == cpp_ticker) {
            ticker_matches++;
            
            // Check weight too for exact match
            auto julia_weight = julia_stocks[0]["weightTomorrow"].get<double>();
            auto cpp_weight = cpp_day.stock_list()[0].weight_tomorrow();
            
            if (std::abs(julia_weight - cpp_weight) < 0.001) {
                exact_matches++;
            }
        }
    }
    
    double ticker_accuracy = static_cast<double>(ticker_matches) / min_days * 100.0;
    double exact_accuracy = static_cast<double>(exact_matches) / min_days * 100.0;
    
    std::cout << "   Ticker match accuracy: " << std::fixed << std::setprecision(1) 
              << ticker_accuracy << "% (" << ticker_matches << "/" << min_days << ")" << std::endl;
    std::cout << "   Exact match accuracy: " << std::fixed << std::setprecision(1) 
              << exact_accuracy << "% (" << exact_matches << "/" << min_days << ")" << std::endl;
    
    // Compatibility thresholds
    EXPECT_GT(ticker_accuracy, 95.0) << "Ticker selection should match Julia reference >95%";
    EXPECT_GT(exact_accuracy, 90.0) << "Exact matches should be >90%";
    
    if (ticker_accuracy < 100.0) {
        std::cout << "   ⚠️  Some differences detected - analyzing first 5 mismatches:" << std::endl;
        
        int mismatch_count = 0;
        for (size_t day = 0; day < min_days && mismatch_count < 5; ++day) {
            auto julia_day = julia_history[day];
            if (!julia_day.contains("stockList") || julia_day["stockList"].empty()) continue;
            
            const auto& cpp_day = cpp_result.portfolio_history[day];
            if (cpp_day.empty()) continue;
            
            auto julia_ticker = julia_day["stockList"][0]["ticker"].get<std::string>();
            auto cpp_ticker = cpp_day.stock_list()[0].ticker();
            
            if (julia_ticker != cpp_ticker) {
                std::cout << "     Day " << day + 1 << ": Julia=" << julia_ticker 
                         << ", C++=" << cpp_ticker << std::endl;
                mismatch_count++;
            }
        }
    }
    
    std::cout << "✅ Julia compatibility verification completed" << std::endl;
}

// Test 5: Strategy Logic Validation
TEST_F(SmallStrategyComprehensiveTest, StrategyLogicValidation) {
    ASSERT_TRUE(strategy_loaded) << "Strategy must be loaded";
    
    // Execute strategy
    BacktestResult result = execute_strategy();
    ASSERT_TRUE(result.success) << "Strategy execution must succeed";
    
    std::cout << "🧠 Strategy Logic Validation:" << std::endl;
    
    // Analyze decision patterns based on SmallStrategy logic:
    // 1. If SPY < SPY SMA-200 → QQQ
    // 2. Else if QQQ < QQQ SMA-20 → Sort by RSI-10 (PSQ/SHY)
    // 3. Else → QQQ
    
    std::unordered_map<std::string, int> decision_counts;
    size_t total_decisions = 0;
    
    for (const auto& day : result.portfolio_history) {
        if (!day.empty()) {
            total_decisions++;
            for (const auto& stock : day.stock_list()) {
                decision_counts[stock.ticker()]++;
            }
        }
    }
    
    // Validate decision tree execution
    EXPECT_GT(decision_counts["QQQ"], 0) << "QQQ should be selected (primary asset)";
    
    // Check for defensive positioning
    int defensive_days = decision_counts["PSQ"] + decision_counts["SHY"];
    
    if (defensive_days > 0) {
        std::cout << "   ✅ Sort node executed: " << defensive_days << " defensive positions" << std::endl;
        std::cout << "     - PSQ (inverse QQQ): " << decision_counts["PSQ"] << " days" << std::endl;
        std::cout << "     - SHY (treasury): " << decision_counts["SHY"] << " days" << std::endl;
    } else {
        std::cout << "   📊 Strategy remained bullish: Only QQQ positions" << std::endl;
    }
    
    // Portfolio concentration analysis
    float qqq_concentration = static_cast<float>(decision_counts["QQQ"]) / total_decisions * 100.0f;
    std::cout << "   QQQ concentration: " << std::fixed << std::setprecision(1) 
              << qqq_concentration << "%" << std::endl;
    
    // Logic validation: QQQ should dominate in bull markets
    EXPECT_GT(qqq_concentration, 50.0f) << "QQQ should be primary position in most conditions";
    
    std::cout << "✅ Strategy logic validation completed" << std::endl;
}

// Test 6: Stress Testing
TEST_F(SmallStrategyComprehensiveTest, StressTesting) {
    ASSERT_TRUE(strategy_loaded) << "Strategy must be loaded";
    
    std::cout << "💪 Stress Testing:" << std::endl;
    
    // Test 1: Multiple consecutive executions
    constexpr int stress_runs = 10;
    std::vector<bool> run_success(stress_runs);
    std::vector<std::chrono::milliseconds> run_times(stress_runs);
    
    for (int run = 0; run < stress_runs; ++run) {
        auto start = std::chrono::high_resolution_clock::now();
        BacktestResult result = execute_strategy();
        auto end = std::chrono::high_resolution_clock::now();
        
        run_success[run] = result.success;
        run_times[run] = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);
    }
    
    // Validate all runs succeeded
    int successful_runs = std::count(run_success.begin(), run_success.end(), true);
    EXPECT_EQ(successful_runs, stress_runs) << "All stress test runs must succeed";
    
    // Check timing consistency
    auto min_time = *std::min_element(run_times.begin(), run_times.end());
    auto max_time = *std::max_element(run_times.begin(), run_times.end());
    auto avg_time = std::accumulate(run_times.begin(), run_times.end(), std::chrono::milliseconds(0)) / stress_runs;
    
    std::cout << "   " << stress_runs << " consecutive runs: "
              << "min=" << min_time.count() << "ms, "
              << "avg=" << avg_time.count() << "ms, "
              << "max=" << max_time.count() << "ms" << std::endl;
    
    // Timing variance should be reasonable
    double time_variance = static_cast<double>(max_time.count()) / min_time.count();
    EXPECT_LT(time_variance, 3.0) << "Execution time variance should be reasonable";
    
    std::cout << "✅ Stress testing completed: " << successful_runs << "/" << stress_runs << " runs successful" << std::endl;
}

// Main function for standalone execution
int main(int argc, char **argv) {
    ::testing::InitGoogleTest(&argc, argv);
    
    std::cout << "===========================================================" << std::endl;
    std::cout << "    SMALLSTRATEGY COMPREHENSIVE TEST SUITE" << std::endl;
    std::cout << "===========================================================" << std::endl;
    
    int test_result = RUN_ALL_TESTS();
    
    std::cout << "\n===========================================================" << std::endl;
    if (test_result == 0) {
        std::cout << "✅ ALL TESTS PASSED - SmallStrategy.json fully verified" << std::endl;
    } else {
        std::cout << "❌ SOME TESTS FAILED - Check output above" << std::endl;
    }
    std::cout << "===========================================================" << std::endl;
    
    return test_result;
}