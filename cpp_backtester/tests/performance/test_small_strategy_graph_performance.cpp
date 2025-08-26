#include <gtest/gtest.h>
#include "backtesting_engine.h"
#include "strategy_parser.h"
#include <fstream>
#include <chrono>
#include <vector>
#include <numeric>
#include <algorithm>
#include <iomanip>

using namespace atlas;

class SmallStrategyPerformanceTest : public ::testing::Test {
protected:
    BacktestingEngine engine;
    StrategyParser parser;
    Strategy strategy;
    bool strategy_loaded = false;
    
    void SetUp() override {
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
    
    BacktestResult execute_strategy_timed(int test_period = 0) {
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

// Test 1: Graph Execution Speed Benchmarking
TEST_F(SmallStrategyPerformanceTest, GraphExecutionSpeedBenchmark) {
    ASSERT_TRUE(strategy_loaded) << "Strategy must be loaded for performance testing";
    
    std::cout << "\n🚀 GRAPH EXECUTION SPEED BENCHMARKING" << std::endl;
    std::cout << "==============================================" << std::endl;
    
    // Test different period lengths to measure scalability
    std::vector<int> test_periods = {10, 30, 60, 120, 250, 500, 1260};
    
    struct PerformanceResult {
        int period;
        std::chrono::milliseconds min_time;
        std::chrono::milliseconds avg_time;
        std::chrono::milliseconds max_time;
        double throughput_days_per_second;
        double throughput_nodes_per_second;
    };
    
    std::vector<PerformanceResult> results;
    
    for (int period : test_periods) {
        std::cout << "\nTesting period: " << period << " days" << std::endl;
        
        // Warm-up runs
        for (int warmup = 0; warmup < 2; ++warmup) {
            BacktestResult warm_result = execute_strategy_timed(period);
            ASSERT_TRUE(warm_result.success) << "Warm-up run failed for period: " << period;
        }
        
        // Performance measurement runs
        constexpr int num_runs = 10;
        std::vector<std::chrono::milliseconds> execution_times;
        
        for (int run = 0; run < num_runs; ++run) {
            auto start = std::chrono::high_resolution_clock::now();
            BacktestResult result = execute_strategy_timed(period);
            auto end = std::chrono::high_resolution_clock::now();
            
            ASSERT_TRUE(result.success) << "Performance run " << run + 1 << " failed for period: " << period;
            
            auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);
            execution_times.push_back(duration);
        }
        
        // Calculate statistics
        auto min_time = *std::min_element(execution_times.begin(), execution_times.end());
        auto max_time = *std::max_element(execution_times.begin(), execution_times.end());
        auto avg_time = std::accumulate(execution_times.begin(), execution_times.end(), std::chrono::milliseconds(0)) / num_runs;
        
        // Calculate throughput metrics
        double days_per_second = static_cast<double>(period) / (avg_time.count() / 1000.0);
        
        // Estimate nodes processed per second (each day processes multiple nodes)
        // SmallStrategy has: 1 root + 2 conditional + 1 sort + 3 stock nodes = ~7 nodes per day average
        double estimated_nodes_per_day = 7.0;
        double nodes_per_second = days_per_second * estimated_nodes_per_day;
        
        PerformanceResult perf_result = {
            period, min_time, avg_time, max_time, days_per_second, nodes_per_second
        };
        results.push_back(perf_result);
        
        std::cout << "  Min: " << std::setw(4) << min_time.count() << "ms  "
                 << "Avg: " << std::setw(4) << avg_time.count() << "ms  "
                 << "Max: " << std::setw(4) << max_time.count() << "ms  "
                 << "Throughput: " << std::setw(8) << std::fixed << std::setprecision(0) 
                 << days_per_second << " days/sec, " 
                 << std::setw(8) << std::fixed << std::setprecision(0) 
                 << nodes_per_second << " nodes/sec" << std::endl;
    }
    
    std::cout << "\n📊 PERFORMANCE ANALYSIS" << std::endl;
    std::cout << "========================" << std::endl;
    
    // Performance thresholds and validation
    for (const auto& result : results) {
        // Days per second should be at least 1000 for good performance
        EXPECT_GT(result.throughput_days_per_second, 1000.0) 
            << "Performance threshold: " << result.period << " days should process >1000 days/sec";
        
        // Nodes per second should be substantial
        EXPECT_GT(result.throughput_nodes_per_second, 5000.0)
            << "Graph execution should process >5000 nodes/sec for " << result.period << " days";
    }
    
    // Test specific performance targets
    auto full_strategy_result = std::find_if(results.begin(), results.end(), 
        [](const PerformanceResult& r) { return r.period == 1260; });
    
    if (full_strategy_result != results.end()) {
        std::cout << "\n🎯 FULL STRATEGY PERFORMANCE (1260 days):" << std::endl;
        std::cout << "   Execution time: " << full_strategy_result->avg_time.count() << "ms" << std::endl;
        std::cout << "   Days/second: " << std::fixed << std::setprecision(0) 
                 << full_strategy_result->throughput_days_per_second << std::endl;
        std::cout << "   Nodes/second: " << std::fixed << std::setprecision(0) 
                 << full_strategy_result->throughput_nodes_per_second << std::endl;
        
        // Full strategy should execute in under 1 second
        EXPECT_LT(full_strategy_result->avg_time.count(), 1000) 
            << "Full SmallStrategy (1260 days) should execute in under 1 second";
        
        // Should process at least 25,000 days per second
        EXPECT_GT(full_strategy_result->throughput_days_per_second, 25000.0)
            << "Should achieve >25k days/sec throughput";
        
        if (full_strategy_result->avg_time.count() < 100) {
            std::cout << "   🏆 EXCELLENT: Ultra-fast execution (<100ms)" << std::endl;
        } else if (full_strategy_result->avg_time.count() < 500) {
            std::cout << "   ✅ GOOD: Fast execution (<500ms)" << std::endl;
        } else {
            std::cout << "   ⚠️  ACCEPTABLE: Moderate execution (<1000ms)" << std::endl;
        }
    }
    
    // Scalability analysis
    if (results.size() >= 2) {
        auto first_result = results.front();
        auto last_result = results.back();
        
        double time_scale_factor = static_cast<double>(last_result.avg_time.count()) / first_result.avg_time.count();
        double period_scale_factor = static_cast<double>(last_result.period) / first_result.period;
        
        std::cout << "\n📈 SCALABILITY ANALYSIS:" << std::endl;
        std::cout << "   Period scale: " << period_scale_factor << "x" << std::endl;
        std::cout << "   Time scale: " << time_scale_factor << "x" << std::endl;
        std::cout << "   Efficiency ratio: " << std::fixed << std::setprecision(2) 
                 << time_scale_factor / period_scale_factor << std::endl;
        
        // Execution time should scale roughly linearly with period (not exponentially)
        EXPECT_LT(time_scale_factor, period_scale_factor * 2.0) 
            << "Execution time should scale roughly linearly with period";
        
        if (time_scale_factor < period_scale_factor * 1.5) {
            std::cout << "   ✅ EXCELLENT: Sub-linear scaling" << std::endl;
        } else {
            std::cout << "   📊 LINEAR: Expected linear scaling" << std::endl;
        }
    }
    
    std::cout << "\n✅ Graph execution speed benchmarking completed" << std::endl;
}

// Test 2: Node Processing Speed Test
TEST_F(SmallStrategyPerformanceTest, NodeProcessingSpeedTest) {
    ASSERT_TRUE(strategy_loaded) << "Strategy must be loaded";
    
    std::cout << "\n🔧 NODE PROCESSING SPEED TEST" << std::endl;
    std::cout << "==============================" << std::endl;
    
    // Execute strategy and measure node-level performance
    auto start = std::chrono::high_resolution_clock::now();
    BacktestResult result = execute_strategy_timed();
    auto end = std::chrono::high_resolution_clock::now();
    
    ASSERT_TRUE(result.success) << "Strategy execution must succeed";
    
    auto total_time = std::chrono::duration_cast<std::chrono::microseconds>(end - start);
    
    // Calculate node processing metrics
    size_t total_days = result.portfolio_history.size();
    size_t active_days = 0;
    
    for (const auto& day : result.portfolio_history) {
        if (!day.empty()) {
            active_days++;
        }
    }
    
    // Estimate total nodes processed
    // SmallStrategy structure: Root -> Condition1 -> (Condition2 + Sort + Stocks) | Stock
    // Average nodes per day: ~7-10 depending on path taken
    double estimated_nodes_per_day = 8.0;
    double total_nodes_processed = total_days * estimated_nodes_per_day;
    
    double microseconds_per_day = static_cast<double>(total_time.count()) / total_days;
    double microseconds_per_node = static_cast<double>(total_time.count()) / total_nodes_processed;
    double nodes_per_second = 1000000.0 / microseconds_per_node;
    
    std::cout << "   Total execution time: " << total_time.count() << " μs" << std::endl;
    std::cout << "   Days processed: " << total_days << std::endl;
    std::cout << "   Active days: " << active_days << std::endl;
    std::cout << "   Estimated nodes processed: " << std::fixed << std::setprecision(0) << total_nodes_processed << std::endl;
    std::cout << "   Time per day: " << std::fixed << std::setprecision(2) << microseconds_per_day << " μs" << std::endl;
    std::cout << "   Time per node: " << std::fixed << std::setprecision(2) << microseconds_per_node << " μs" << std::endl;
    std::cout << "   Node processing rate: " << std::fixed << std::setprecision(0) << nodes_per_second << " nodes/sec" << std::endl;
    
    // Performance assertions
    EXPECT_LT(microseconds_per_node, 100.0) << "Each node should process in under 100 microseconds";
    EXPECT_GT(nodes_per_second, 10000.0) << "Should process at least 10,000 nodes per second";
    
    // Quality thresholds
    if (microseconds_per_node < 10.0) {
        std::cout << "   🏆 EXCELLENT: Ultra-fast node processing (<10μs/node)" << std::endl;
    } else if (microseconds_per_node < 50.0) {
        std::cout << "   ✅ GOOD: Fast node processing (<50μs/node)" << std::endl;
    } else {
        std::cout << "   📊 ACCEPTABLE: Reasonable node processing (<100μs/node)" << std::endl;
    }
    
    std::cout << "✅ Node processing speed test completed" << std::endl;
}

// Test 3: Memory Efficiency Test
TEST_F(SmallStrategyPerformanceTest, MemoryEfficiencyTest) {
    ASSERT_TRUE(strategy_loaded) << "Strategy must be loaded";
    
    std::cout << "\n💾 MEMORY EFFICIENCY TEST" << std::endl;
    std::cout << "==========================" << std::endl;
    
    // Test multiple consecutive executions to check for memory leaks
    constexpr int memory_test_runs = 20;
    std::vector<std::chrono::milliseconds> execution_times;
    
    for (int run = 0; run < memory_test_runs; ++run) {
        auto start = std::chrono::high_resolution_clock::now();
        BacktestResult result = execute_strategy_timed();
        auto end = std::chrono::high_resolution_clock::now();
        
        ASSERT_TRUE(result.success) << "Memory test run " << run + 1 << " failed";
        
        auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);
        execution_times.push_back(duration);
        
        // Validate result structure
        EXPECT_EQ(result.portfolio_history.size(), static_cast<size_t>(strategy.period));
        
        // Every 5th run, check for consistency
        if (run % 5 == 0) {
            size_t active_days = 0;
            for (const auto& day : result.portfolio_history) {
                if (!day.empty()) {
                    active_days++;
                }
            }
            EXPECT_GT(active_days, 0) << "Should have active portfolio days";
        }
    }
    
    // Check for performance degradation (indicating memory issues)
    auto first_half_avg = std::accumulate(execution_times.begin(), 
                                         execution_times.begin() + memory_test_runs/2, 
                                         std::chrono::milliseconds(0)) / (memory_test_runs/2);
    
    auto second_half_avg = std::accumulate(execution_times.begin() + memory_test_runs/2, 
                                          execution_times.end(), 
                                          std::chrono::milliseconds(0)) / (memory_test_runs/2);
    
    double performance_degradation = static_cast<double>(second_half_avg.count()) / first_half_avg.count();
    
    std::cout << "   Test runs: " << memory_test_runs << std::endl;
    std::cout << "   First half average: " << first_half_avg.count() << "ms" << std::endl;
    std::cout << "   Second half average: " << second_half_avg.count() << "ms" << std::endl;
    std::cout << "   Performance change: " << std::fixed << std::setprecision(2) 
              << (performance_degradation - 1.0) * 100 << "%" << std::endl;
    
    // Performance should not degrade significantly (indicates memory leaks)
    EXPECT_LT(performance_degradation, 1.2) << "Performance should not degrade by more than 20%";
    
    if (performance_degradation < 1.05) {
        std::cout << "   ✅ EXCELLENT: No performance degradation detected" << std::endl;
    } else if (performance_degradation < 1.1) {
        std::cout << "   📊 GOOD: Minimal performance variation" << std::endl;
    } else {
        std::cout << "   ⚠️  WARNING: Performance degradation detected" << std::endl;
    }
    
    std::cout << "✅ Memory efficiency test completed" << std::endl;
}

// Main function for standalone execution
int main(int argc, char **argv) {
    ::testing::InitGoogleTest(&argc, argv);
    
    std::cout << "============================================================" << std::endl;
    std::cout << "    SMALLSTRATEGY PERFORMANCE TEST SUITE" << std::endl;
    std::cout << "============================================================" << std::endl;
    std::cout << "Testing graph execution speed and performance metrics" << std::endl;
    std::cout << "============================================================" << std::endl;
    
    int test_result = RUN_ALL_TESTS();
    
    std::cout << "\n============================================================" << std::endl;
    if (test_result == 0) {
        std::cout << "✅ ALL PERFORMANCE TESTS PASSED" << std::endl;
        std::cout << "🚀 SmallStrategy.json meets performance requirements" << std::endl;
    } else {
        std::cout << "❌ SOME PERFORMANCE TESTS FAILED" << std::endl;
    }
    std::cout << "============================================================" << std::endl;
    
    return test_result;
}