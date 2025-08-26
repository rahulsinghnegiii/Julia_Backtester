#include <gtest/gtest.h>
#include "backtesting_engine.h"
#include "strategy_parser.h"
#include <chrono>
#include <vector>
#include <fstream>
#include <iostream>
#include <iomanip>

using namespace atlas;

class SmallStrategyPerformanceTest : public ::testing::Test {
protected:
    BacktestingEngine engine;
    StrategyParser parser;
    
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
    
    void print_performance_metrics(const std::vector<std::chrono::milliseconds>& times, 
                                 const std::string& test_name) {
        if (times.empty()) return;
        
        auto min_time = *std::min_element(times.begin(), times.end());
        auto max_time = *std::max_element(times.begin(), times.end());
        auto total_time = std::accumulate(times.begin(), times.end(), std::chrono::milliseconds(0));
        auto avg_time = total_time / times.size();
        
        // Calculate standard deviation
        double variance = 0.0;
        for (const auto& time : times) {
            double diff = time.count() - avg_time.count();
            variance += diff * diff;
        }
        variance /= times.size();
        double std_dev = std::sqrt(variance);
        
        std::cout << "\n=== " << test_name << " Performance Results ===" << std::endl;
        std::cout << "Runs: " << times.size() << std::endl;
        std::cout << "Min Time: " << min_time.count() << " ms" << std::endl;
        std::cout << "Max Time: " << max_time.count() << " ms" << std::endl;
        std::cout << "Avg Time: " << avg_time.count() << " ms" << std::endl;
        std::cout << "Std Dev: " << std::fixed << std::setprecision(2) << std_dev << " ms" << std::endl;
        
        // Performance classification
        if (avg_time.count() < 100) {
            std::cout << "Performance: ⚡ EXCELLENT (< 100ms)" << std::endl;
        } else if (avg_time.count() < 500) {
            std::cout << "Performance: ✅ GOOD (< 500ms)" << std::endl;
        } else if (avg_time.count() < 1000) {
            std::cout << "Performance: ⚠️  ACCEPTABLE (< 1s)" << std::endl;
        } else {
            std::cout << "Performance: ❌ SLOW (>= 1s)" << std::endl;
        }
    }
};

TEST_F(SmallStrategyPerformanceTest, BasicExecutionSpeed) {
    std::string strategy_content = read_file("SmallStrategy.json");
    
    if (strategy_content.empty()) {
        GTEST_SKIP() << "SmallStrategy.json not found, skipping performance test";
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
        
        // Performance test runs
        constexpr int num_runs = 10;
        std::vector<std::chrono::milliseconds> execution_times;
        
        for (int i = 0; i < num_runs; ++i) {
            auto start = std::chrono::high_resolution_clock::now();
            BacktestResult result = engine.execute_backtest(params);
            auto end = std::chrono::high_resolution_clock::now();
            
            EXPECT_TRUE(result.success) << "Run " << i+1 << " failed";
            
            auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);
            execution_times.push_back(duration);
        }
        
        print_performance_metrics(execution_times, "SmallStrategy Basic Execution");
        
        // Performance criteria validation
        auto avg_time = std::accumulate(execution_times.begin(), execution_times.end(), 
                                      std::chrono::milliseconds(0)) / num_runs;
        
        EXPECT_LT(avg_time.count(), 5000) << "Average execution time should be under 5 seconds";
        
        // Log individual run times for analysis
        std::cout << "\nIndividual run times (ms): ";
        for (size_t i = 0; i < execution_times.size(); ++i) {
            if (i > 0) std::cout << ", ";
            std::cout << execution_times[i].count();
        }
        std::cout << std::endl;
        
    } catch (const std::exception& e) {
        FAIL() << "Exception during performance test: " << e.what();
    }
}

TEST_F(SmallStrategyPerformanceTest, ColdStartPerformance) {
    std::string strategy_content = read_file("SmallStrategy.json");
    
    if (strategy_content.empty()) {
        GTEST_SKIP() << "SmallStrategy.json not found, skipping cold start test";
    }
    
    try {
        // Test cold start performance (no warm-up)
        Strategy strategy = parser.parse_strategy(strategy_content);
        
        BacktestParams params;
        params.strategy = strategy;
        params.period = strategy.period;
        params.end_date = strategy.end_date;
        params.live_execution = false;
        params.global_cache_length = 0;
        
        auto start = std::chrono::high_resolution_clock::now();
        BacktestResult result = engine.execute_backtest(params);
        auto end = std::chrono::high_resolution_clock::now();
        
        EXPECT_TRUE(result.success) << "Cold start execution failed";
        
        auto cold_start_time = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);
        
        std::cout << "\n=== Cold Start Performance ===" << std::endl;
        std::cout << "Cold Start Time: " << cold_start_time.count() << " ms" << std::endl;
        
        // Cold start should complete within reasonable time
        EXPECT_LT(cold_start_time.count(), 10000) << "Cold start should complete within 10 seconds";
        
        if (cold_start_time.count() < 1000) {
            std::cout << "Cold Start Performance: ⚡ EXCELLENT (< 1s)" << std::endl;
        } else if (cold_start_time.count() < 3000) {
            std::cout << "Cold Start Performance: ✅ GOOD (< 3s)" << std::endl;
        } else if (cold_start_time.count() < 5000) {
            std::cout << "Cold Start Performance: ⚠️  ACCEPTABLE (< 5s)" << std::endl;
        } else {
            std::cout << "Cold Start Performance: ❌ SLOW (>= 5s)" << std::endl;
        }
        
    } catch (const std::exception& e) {
        FAIL() << "Exception during cold start test: " << e.what();
    }
}

TEST_F(SmallStrategyPerformanceTest, MemoryUsageValidation) {
    std::string strategy_content = read_file("SmallStrategy.json");
    
    if (strategy_content.empty()) {
        GTEST_SKIP() << "SmallStrategy.json not found, skipping memory test";
    }
    
    try {
        Strategy strategy = parser.parse_strategy(strategy_content);
        
        BacktestParams params;
        params.strategy = strategy;
        params.period = strategy.period;
        params.end_date = strategy.end_date;
        params.live_execution = false;
        params.global_cache_length = 0;
        
        // Execute and validate memory usage
        BacktestResult result = engine.execute_backtest(params);
        
        EXPECT_TRUE(result.success) << "Memory validation execution failed";
        
        // Validate result structure for memory leaks
        EXPECT_EQ(result.portfolio_history.size(), static_cast<size_t>(strategy.period));
        
        // Check that portfolio data is properly populated
        size_t non_empty_days = 0;
        for (const auto& day : result.portfolio_history) {
            if (!day.empty()) {
                non_empty_days++;
                
                // Validate each stock entry
                for (const auto& stock : day.stock_list()) {
                    EXPECT_FALSE(stock.ticker().empty()) << "Stock ticker should not be empty";
                    EXPECT_GE(stock.weight_tomorrow(), 0.0f) << "Weight should be non-negative";
                    EXPECT_LE(stock.weight_tomorrow(), 1.0f) << "Weight should not exceed 1.0";
                }
            }
        }
        
        std::cout << "\n=== Memory Usage Validation ===" << std::endl;
        std::cout << "Total days: " << result.portfolio_history.size() << std::endl;
        std::cout << "Non-empty days: " << non_empty_days << std::endl;
        std::cout << "Portfolio utilization: " << std::fixed << std::setprecision(1) 
                 << (static_cast<float>(non_empty_days) / result.portfolio_history.size() * 100.0f) 
                 << "%" << std::endl;
        
        // Expect reasonable portfolio utilization
        float utilization = static_cast<float>(non_empty_days) / result.portfolio_history.size();
        EXPECT_GT(utilization, 0.5f) << "Portfolio should be active on most days";
        
    } catch (const std::exception& e) {
        FAIL() << "Exception during memory validation: " << e.what();
    }
}

TEST_F(SmallStrategyPerformanceTest, ScalabilityTest) {
    std::string strategy_content = read_file("SmallStrategy.json");
    
    if (strategy_content.empty()) {
        GTEST_SKIP() << "SmallStrategy.json not found, skipping scalability test";
    }
    
    try {
        Strategy strategy = parser.parse_strategy(strategy_content);
        
        // Test different period lengths
        std::vector<int> test_periods = {30, 60, 120, 250}; // Days
        std::vector<std::chrono::milliseconds> scalability_times;
        
        for (int period : test_periods) {
            BacktestParams params;
            params.strategy = strategy;
            params.period = period;
            params.end_date = strategy.end_date;
            params.live_execution = false;
            params.global_cache_length = 0;
            
            auto start = std::chrono::high_resolution_clock::now();
            BacktestResult result = engine.execute_backtest(params);
            auto end = std::chrono::high_resolution_clock::now();
            
            EXPECT_TRUE(result.success) << "Scalability test failed for period: " << period;
            
            auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);
            scalability_times.push_back(duration);
            
            std::cout << "Period " << period << " days: " << duration.count() << " ms" << std::endl;
        }
        
        std::cout << "\n=== Scalability Analysis ===" << std::endl;
        
        // Check that execution time scales reasonably
        for (size_t i = 1; i < scalability_times.size(); ++i) {
            float time_ratio = static_cast<float>(scalability_times[i].count()) / scalability_times[i-1].count();
            float period_ratio = static_cast<float>(test_periods[i]) / test_periods[i-1];
            
            std::cout << "Period ratio " << test_periods[i-1] << "->" << test_periods[i] 
                     << ": " << std::fixed << std::setprecision(2) << period_ratio 
                     << ", Time ratio: " << time_ratio << std::endl;
            
            // Time should scale sub-linearly or linearly with period
            EXPECT_LT(time_ratio, period_ratio * 2.0f) 
                << "Execution time should not scale worse than 2x linear with period";
        }
        
    } catch (const std::exception& e) {
        FAIL() << "Exception during scalability test: " << e.what();
    }
}

TEST_F(SmallStrategyPerformanceTest, CacheEfficiencyTest) {
    std::string strategy_content = read_file("SmallStrategy.json");
    
    if (strategy_content.empty()) {
        GTEST_SKIP() << "SmallStrategy.json not found, skipping cache test";
    }
    
    try {
        Strategy strategy = parser.parse_strategy(strategy_content);
        
        // Test with different cache configurations
        std::vector<int> cache_lengths = {0, 50, 100, 200};
        std::vector<std::chrono::milliseconds> cache_times;
        
        for (int cache_length : cache_lengths) {
            BacktestParams params;
            params.strategy = strategy;
            params.period = strategy.period;
            params.end_date = strategy.end_date;
            params.live_execution = false;
            params.global_cache_length = cache_length;
            
            // Run multiple times and take average
            constexpr int runs = 3;
            std::chrono::milliseconds total_time(0);
            
            for (int run = 0; run < runs; ++run) {
                auto start = std::chrono::high_resolution_clock::now();
                BacktestResult result = engine.execute_backtest(params);
                auto end = std::chrono::high_resolution_clock::now();
                
                EXPECT_TRUE(result.success) << "Cache test failed for cache_length: " << cache_length;
                
                total_time += std::chrono::duration_cast<std::chrono::milliseconds>(end - start);
            }
            
            auto avg_time = total_time / runs;
            cache_times.push_back(avg_time);
            
            std::cout << "Cache length " << cache_length << ": " << avg_time.count() << " ms (avg)" << std::endl;
        }
        
        std::cout << "\n=== Cache Efficiency Analysis ===" << std::endl;
        
        // Compare cache performance
        auto no_cache_time = cache_times[0];
        for (size_t i = 1; i < cache_times.size(); ++i) {
            float improvement = static_cast<float>(no_cache_time.count() - cache_times[i].count()) / 
                              no_cache_time.count() * 100.0f;
            
            std::cout << "Cache " << cache_lengths[i] << " vs no cache: ";
            if (improvement > 0) {
                std::cout << "+" << std::fixed << std::setprecision(1) << improvement << "% faster";
            } else {
                std::cout << std::fixed << std::setprecision(1) << -improvement << "% slower";
            }
            std::cout << std::endl;
        }
        
    } catch (const std::exception& e) {
        FAIL() << "Exception during cache efficiency test: " << e.what();
    }
}

TEST_F(SmallStrategyPerformanceTest, ComprehensivePerformanceReport) {
    std::string strategy_content = read_file("SmallStrategy.json");
    
    if (strategy_content.empty()) {
        GTEST_SKIP() << "SmallStrategy.json not found, skipping comprehensive test";
    }
    
    try {
        Strategy strategy = parser.parse_strategy(strategy_content);
        
        std::cout << "\n=====================================================" << std::endl;
        std::cout << "    COMPREHENSIVE SMALLSTRATEGY PERFORMANCE REPORT" << std::endl;
        std::cout << "=====================================================" << std::endl;
        
        // Strategy information
        std::cout << "\n=== Strategy Information ===" << std::endl;
        std::cout << "Period: " << strategy.period << " days" << std::endl;
        std::cout << "End Date: " << strategy.end_date << std::endl;
        std::cout << "Tickers: ";
        for (size_t i = 0; i < strategy.tickers.size(); ++i) {
            if (i > 0) std::cout << ", ";
            std::cout << strategy.tickers[i];
        }
        std::cout << std::endl;
        
        // Execute comprehensive test
        BacktestParams params;
        params.strategy = strategy;
        params.period = strategy.period;
        params.end_date = strategy.end_date;
        params.live_execution = false;
        params.global_cache_length = 0;
        
        auto start = std::chrono::high_resolution_clock::now();
        BacktestResult result = engine.execute_backtest(params);
        auto end = std::chrono::high_resolution_clock::now();
        
        EXPECT_TRUE(result.success) << "Comprehensive test execution failed";
        
        auto execution_time = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);
        
        // Performance summary
        std::cout << "\n=== Performance Summary ===" << std::endl;
        std::cout << "Total Execution Time: " << execution_time.count() << " ms" << std::endl;
        std::cout << "Days per Second: " << std::fixed << std::setprecision(0) 
                 << (static_cast<float>(strategy.period) / execution_time.count() * 1000.0f) << std::endl;
        std::cout << "Time per Day: " << std::fixed << std::setprecision(3) 
                 << (static_cast<float>(execution_time.count()) / strategy.period) << " ms" << std::endl;
        
        // Results validation
        std::cout << "\n=== Results Validation ===" << std::endl;
        std::cout << "Portfolio History Size: " << result.portfolio_history.size() << std::endl;
        
        size_t active_days = 0;
        std::unordered_map<std::string, int> ticker_frequency;
        
        for (const auto& day : result.portfolio_history) {
            if (!day.empty()) {
                active_days++;
                for (const auto& stock : day.stock_list()) {
                    ticker_frequency[stock.ticker()]++;
                }
            }
        }
        
        std::cout << "Active Days: " << active_days << " (" 
                 << std::fixed << std::setprecision(1) 
                 << (static_cast<float>(active_days) / result.portfolio_history.size() * 100.0f) 
                 << "%)" << std::endl;
        
        std::cout << "Ticker Frequency:" << std::endl;
        for (const auto& [ticker, count] : ticker_frequency) {
            std::cout << "  " << ticker << ": " << count << " days (" 
                     << std::fixed << std::setprecision(1) 
                     << (static_cast<float>(count) / result.portfolio_history.size() * 100.0f) 
                     << "%)" << std::endl;
        }
        
        // Performance grade
        std::cout << "\n=== Performance Grade ===" << std::endl;
        if (execution_time.count() < 100) {
            std::cout << "🏆 GRADE A: EXCELLENT PERFORMANCE" << std::endl;
        } else if (execution_time.count() < 500) {
            std::cout << "🥈 GRADE B: GOOD PERFORMANCE" << std::endl;
        } else if (execution_time.count() < 1000) {
            std::cout << "🥉 GRADE C: ACCEPTABLE PERFORMANCE" << std::endl;
        } else if (execution_time.count() < 5000) {
            std::cout << "⚠️  GRADE D: NEEDS OPTIMIZATION" << std::endl;
        } else {
            std::cout << "❌ GRADE F: POOR PERFORMANCE" << std::endl;
        }
        
        std::cout << "=====================================================" << std::endl;
        
    } catch (const std::exception& e) {
        FAIL() << "Exception during comprehensive performance test: " << e.what();
    }
}