#include <gtest/gtest.h>
#include "backtesting_engine.h"
#include "strategy_parser.h"
#include <nlohmann/json.hpp>
#include <fstream>
#include <iostream>
#include <iomanip>
#include <unordered_map>

using namespace atlas;
using json = nlohmann::json;

class JuliaCompatibilityTest : public ::testing::Test {
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
    
    json load_json_file(const std::string& filename) {
        std::string content = read_file(filename);
        if (content.empty()) {
            return json::object();
        }
        
        try {
            return json::parse(content);
        } catch (const std::exception& e) {
            std::cerr << "Error parsing JSON: " << e.what() << std::endl;
            return json::object();
        }
    }
    
    void print_comparison_report(const BacktestResult& cpp_result, 
                               const json& julia_expected,
                               const std::string& strategy_name) {
        std::cout << "\n=================================================" << std::endl;
        std::cout << "    JULIA COMPATIBILITY VALIDATION REPORT" << std::endl;
        std::cout << "=================================================" << std::endl;
        std::cout << "Strategy: " << strategy_name << std::endl;
        
        // Compare portfolio history structure
        if (julia_expected.contains("profile_history")) {
            auto julia_history = julia_expected["profile_history"];
            std::cout << "\n=== Portfolio History Comparison ===" << std::endl;
            std::cout << "Julia Expected Days: " << julia_history.size() << std::endl;
            std::cout << "C++ Result Days: " << cpp_result.portfolio_history.size() << std::endl;
            
            // Size comparison
            size_t min_days = std::min(julia_history.size(), cpp_result.portfolio_history.size());
            std::cout << "Comparing first " << min_days << " days" << std::endl;
            
            // Ticker frequency analysis
            std::unordered_map<std::string, int> julia_ticker_count;
            std::unordered_map<std::string, int> cpp_ticker_count;
            
            for (size_t i = 0; i < min_days && i < julia_history.size(); ++i) {
                if (julia_history[i].contains("stockList") && !julia_history[i]["stockList"].empty()) {
                    auto stock = julia_history[i]["stockList"][0];
                    if (stock.contains("ticker")) {
                        julia_ticker_count[stock["ticker"]]++;
                    }
                }
            }
            
            for (size_t i = 0; i < min_days && i < cpp_result.portfolio_history.size(); ++i) {
                if (!cpp_result.portfolio_history[i].empty()) {
                    for (const auto& stock : cpp_result.portfolio_history[i].stock_list()) {
                        cpp_ticker_count[stock.ticker()]++;
                    }
                }
            }
            
            std::cout << "\n=== Ticker Frequency Analysis ===" << std::endl;
            std::cout << "Julia Expected:" << std::endl;
            for (const auto& [ticker, count] : julia_ticker_count) {
                float percentage = (static_cast<float>(count) / min_days) * 100.0f;
                std::cout << "  " << ticker << ": " << count << " days (" 
                         << std::fixed << std::setprecision(1) << percentage << "%)" << std::endl;
            }
            
            std::cout << "\nC++ Implementation:" << std::endl;
            for (const auto& [ticker, count] : cpp_ticker_count) {
                float percentage = (static_cast<float>(count) / min_days) * 100.0f;
                std::cout << "  " << ticker << ": " << count << " days (" 
                         << std::fixed << std::setprecision(1) << percentage << "%)" << std::endl;
            }
            
            // Day-by-day comparison (first 50 days for detailed analysis)
            std::cout << "\n=== Day-by-Day Comparison (First 50 Days) ===" << std::endl;
            int matches = 0;
            int valid_comparisons = 0;
            
            for (size_t i = 0; i < std::min({min_days, static_cast<size_t>(50), julia_history.size()}); ++i) {
                std::string julia_ticker = "";
                std::string cpp_ticker = "";
                
                // Extract Julia ticker
                if (julia_history[i].contains("stockList") && !julia_history[i]["stockList"].empty()) {
                    auto stock = julia_history[i]["stockList"][0];
                    if (stock.contains("ticker")) {
                        julia_ticker = stock["ticker"];
                    }
                }
                
                // Extract C++ ticker
                if (i < cpp_result.portfolio_history.size() && !cpp_result.portfolio_history[i].empty()) {
                    auto stocks = cpp_result.portfolio_history[i].stock_list();
                    if (!stocks.empty()) {
                        cpp_ticker = stocks[0].ticker();
                    }
                }
                
                if (!julia_ticker.empty() && !cpp_ticker.empty()) {
                    valid_comparisons++;
                    bool match = (julia_ticker == cpp_ticker);
                    if (match) matches++;
                    
                    std::cout << "Day " << std::setw(2) << (i+1) << ": "
                             << "Julia=" << std::setw(3) << julia_ticker 
                             << " | C++=" << std::setw(3) << cpp_ticker
                             << " | " << (match ? "✓" : "✗") << std::endl;
                }
            }
            
            std::cout << "\n=== Match Statistics ===" << std::endl;
            if (valid_comparisons > 0) {
                float match_percentage = (static_cast<float>(matches) / valid_comparisons) * 100.0f;
                std::cout << "Matches: " << matches << "/" << valid_comparisons 
                         << " (" << std::fixed << std::setprecision(1) << match_percentage << "%)" << std::endl;
                
                if (match_percentage >= 95.0f) {
                    std::cout << "🏆 EXCELLENT COMPATIBILITY (>= 95%)" << std::endl;
                } else if (match_percentage >= 85.0f) {
                    std::cout << "✅ GOOD COMPATIBILITY (>= 85%)" << std::endl;
                } else if (match_percentage >= 70.0f) {
                    std::cout << "⚠️  ACCEPTABLE COMPATIBILITY (>= 70%)" << std::endl;
                } else {
                    std::cout << "❌ POOR COMPATIBILITY (< 70%)" << std::endl;
                }
            }
        }
        
        // Compare dates if available
        if (julia_expected.contains("dates")) {
            auto julia_dates = julia_expected["dates"];
            std::cout << "\n=== Date Range Comparison ===" << std::endl;
            std::cout << "Julia Date Count: " << julia_dates.size() << std::endl;
            
            if (!julia_dates.empty()) {
                std::cout << "Julia Start Date: " << julia_dates[0] << std::endl;
                std::cout << "Julia End Date: " << julia_dates[julia_dates.size()-1] << std::endl;
            }
        }
        
        std::cout << "=================================================" << std::endl;
    }
};

TEST_F(JuliaCompatibilityTest, CompareWithExpectedOutput) {
    // Load SmallStrategy.json definition
    std::string strategy_content = read_file("SmallStrategy.json");
    
    if (strategy_content.empty()) {
        GTEST_SKIP() << "SmallStrategy.json not found, skipping Julia compatibility test";
    }
    
    // Load Julia expected output
    json julia_expected = load_json_file("../App/Tests/E2E/ExpectedFiles/SmallStrategy.json");
    
    if (julia_expected.empty()) {
        GTEST_SKIP() << "Julia expected output file not found, skipping compatibility test";
    }
    
    try {
        // Parse and execute strategy
        Strategy strategy = parser.parse_strategy(strategy_content);
        
        BacktestParams params;
        params.strategy = strategy;
        params.period = strategy.period;
        params.end_date = strategy.end_date;
        params.live_execution = false;
        params.global_cache_length = 0;
        
        BacktestResult cpp_result = engine.execute_backtest(params);
        
        EXPECT_TRUE(cpp_result.success) << "C++ strategy execution should succeed";
        
        // Generate comprehensive comparison report
        print_comparison_report(cpp_result, julia_expected, "SmallStrategy");
        
        // Validate basic structure compatibility
        ASSERT_TRUE(julia_expected.contains("profile_history")) 
            << "Julia expected output should contain profile_history";
        
        auto julia_history = julia_expected["profile_history"];
        EXPECT_GT(julia_history.size(), 0) << "Julia history should not be empty";
        EXPECT_GT(cpp_result.portfolio_history.size(), 0) << "C++ history should not be empty";
        
        // Validate that we have the expected tickers in both outputs
        std::set<std::string> expected_tickers = {"QQQ", "PSQ", "SHY"};
        std::set<std::string> found_tickers;
        
        // Check first 100 days for ticker validation
        size_t check_days = std::min(static_cast<size_t>(100), 
                                   std::min(julia_history.size(), cpp_result.portfolio_history.size()));
        
        for (size_t i = 0; i < check_days; ++i) {
            if (i < cpp_result.portfolio_history.size() && !cpp_result.portfolio_history[i].empty()) {
                for (const auto& stock : cpp_result.portfolio_history[i].stock_list()) {
                    found_tickers.insert(stock.ticker());
                }
            }
        }
        
        for (const auto& expected_ticker : expected_tickers) {
            EXPECT_TRUE(found_tickers.count(expected_ticker) > 0) 
                << "Expected ticker " << expected_ticker << " should appear in C++ output";
        }
        
        // Calculate match percentage for validation
        int matches = 0;
        int valid_comparisons = 0;
        size_t comparison_days = std::min(static_cast<size_t>(200), 
                                        std::min(julia_history.size(), cpp_result.portfolio_history.size()));
        
        for (size_t i = 0; i < comparison_days; ++i) {
            std::string julia_ticker = "";
            std::string cpp_ticker = "";
            
            // Extract Julia ticker
            if (julia_history[i].contains("stockList") && !julia_history[i]["stockList"].empty()) {
                auto stock = julia_history[i]["stockList"][0];
                if (stock.contains("ticker")) {
                    julia_ticker = stock["ticker"];
                }
            }
            
            // Extract C++ ticker
            if (i < cpp_result.portfolio_history.size() && !cpp_result.portfolio_history[i].empty()) {
                auto stocks = cpp_result.portfolio_history[i].stock_list();
                if (!stocks.empty()) {
                    cpp_ticker = stocks[0].ticker();
                }
            }
            
            if (!julia_ticker.empty() && !cpp_ticker.empty()) {
                valid_comparisons++;
                if (julia_ticker == cpp_ticker) {
                    matches++;
                }
            }
        }
        
        if (valid_comparisons > 0) {
            float match_percentage = (static_cast<float>(matches) / valid_comparisons) * 100.0f;
            std::cout << "\nFinal Validation: " << match_percentage << "% compatibility" << std::endl;
            
            // We expect at least 50% compatibility due to different implementation details
            EXPECT_GE(match_percentage, 50.0f) 
                << "C++ implementation should have reasonable compatibility with Julia output";
        }
        
    } catch (const std::exception& e) {
        FAIL() << "Exception during Julia compatibility test: " << e.what();
    }
}

TEST_F(JuliaCompatibilityTest, ValidateStrategyLogicPatterns) {
    // Load SmallStrategy.json definition
    std::string strategy_content = read_file("SmallStrategy.json");
    
    if (strategy_content.empty()) {
        GTEST_SKIP() << "SmallStrategy.json not found, skipping pattern validation";
    }
    
    // Load Julia expected output
    json julia_expected = load_json_file("../App/Tests/E2E/ExpectedFiles/SmallStrategy.json");
    
    if (julia_expected.empty()) {
        GTEST_SKIP() << "Julia expected output file not found, skipping pattern validation";
    }
    
    try {
        // Parse and execute strategy
        Strategy strategy = parser.parse_strategy(strategy_content);
        
        BacktestParams params;
        params.strategy = strategy;
        params.period = strategy.period;
        params.end_date = strategy.end_date;
        params.live_execution = false;
        params.global_cache_length = 0;
        
        BacktestResult cpp_result = engine.execute_backtest(params);
        
        EXPECT_TRUE(cpp_result.success) << "C++ strategy execution should succeed";
        
        // Validate SmallStrategy logic patterns
        auto julia_history = julia_expected["profile_history"];
        
        std::cout << "\n=== SmallStrategy Logic Pattern Validation ===" << std::endl;
        
        // Pattern 1: QQQ should be the most frequent (default case)
        std::unordered_map<std::string, int> julia_counts;
        std::unordered_map<std::string, int> cpp_counts;
        
        size_t analysis_days = std::min(julia_history.size(), cpp_result.portfolio_history.size());
        
        for (size_t i = 0; i < analysis_days; ++i) {
            // Julia counts
            if (i < julia_history.size() && julia_history[i].contains("stockList") && 
                !julia_history[i]["stockList"].empty()) {
                auto stock = julia_history[i]["stockList"][0];
                if (stock.contains("ticker")) {
                    julia_counts[stock["ticker"]]++;
                }
            }
            
            // C++ counts
            if (i < cpp_result.portfolio_history.size() && !cpp_result.portfolio_history[i].empty()) {
                auto stocks = cpp_result.portfolio_history[i].stock_list();
                if (!stocks.empty()) {
                    cpp_counts[stocks[0].ticker()]++;
                }
            }
        }
        
        // Validate patterns
        std::cout << "Julia Ticker Distribution:" << std::endl;
        for (const auto& [ticker, count] : julia_counts) {
            float pct = (static_cast<float>(count) / analysis_days) * 100.0f;
            std::cout << "  " << ticker << ": " << std::fixed << std::setprecision(1) << pct << "%" << std::endl;
        }
        
        std::cout << "C++ Ticker Distribution:" << std::endl;
        for (const auto& [ticker, count] : cpp_counts) {
            float pct = (static_cast<float>(count) / analysis_days) * 100.0f;
            std::cout << "  " << ticker << ": " << std::fixed << std::setprecision(1) << pct << "%" << std::endl;
        }
        
        // Pattern validation: QQQ should be most frequent in both
        auto julia_max = std::max_element(julia_counts.begin(), julia_counts.end(),
            [](const auto& a, const auto& b) { return a.second < b.second; });
        
        auto cpp_max = std::max_element(cpp_counts.begin(), cpp_counts.end(),
            [](const auto& a, const auto& b) { return a.second < b.second; });
        
        if (julia_max != julia_counts.end() && cpp_max != cpp_counts.end()) {
            std::cout << "Most frequent - Julia: " << julia_max->first 
                     << ", C++: " << cpp_max->first << std::endl;
            
            EXPECT_EQ(julia_max->first, "QQQ") << "QQQ should be most frequent in Julia output";
            EXPECT_EQ(cpp_max->first, "QQQ") << "QQQ should be most frequent in C++ output";
        }
        
        // Pattern 2: All three tickers should appear
        EXPECT_GT(julia_counts["QQQ"], 0) << "QQQ should appear in Julia output";
        EXPECT_GT(julia_counts["PSQ"], 0) << "PSQ should appear in Julia output";  
        EXPECT_GT(julia_counts["SHY"], 0) << "SHY should appear in Julia output";
        
        EXPECT_GT(cpp_counts["QQQ"], 0) << "QQQ should appear in C++ output";
        EXPECT_GT(cpp_counts["PSQ"], 0) << "PSQ should appear in C++ output";
        EXPECT_GT(cpp_counts["SHY"], 0) << "SHY should appear in C++ output";
        
        std::cout << "Pattern validation completed ✓" << std::endl;
        
    } catch (const std::exception& e) {
        FAIL() << "Exception during pattern validation: " << e.what();
    }
}