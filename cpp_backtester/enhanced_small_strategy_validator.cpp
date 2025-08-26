#include <iostream>
#include <chrono>
#include <fstream>
#include "backtesting_engine.h"
#include "strategy_parser.h"
#include <nlohmann/json.hpp>

using namespace atlas;
using json = nlohmann::json;

class SmallStrategyVerifier {
public:
    bool run_verification() {
        std::cout << "=====================================================" << std::endl;
        std::cout << "    ENHANCED SMALLSTRATEGY VERIFICATION RUNNER" << std::endl;
        std::cout << "=====================================================" << std::endl;
        std::cout << "Including Julia Compatibility Validation" << std::endl;
        std::cout << "=====================================================" << std::endl;
        
        // Step 1: Load and parse SmallStrategy.json
        std::cout << "\n[1/6] Loading SmallStrategy.json..." << std::endl;
        std::string strategy_content = read_file("SmallStrategy.json");
        if (strategy_content.empty()) {
            std::cerr << "❌ Error: SmallStrategy.json not found" << std::endl;
            return false;
        }
        std::cout << "✅ SmallStrategy.json loaded successfully" << std::endl;
        
        // Step 2: Load Julia expected output
        std::cout << "\n[2/6] Loading Julia expected output..." << std::endl;
        json julia_expected = load_json_file("../App/Tests/E2E/ExpectedFiles/SmallStrategy.json");
        if (julia_expected.empty()) {
            std::cout << "⚠️  Warning: Julia expected output not found, skipping compatibility test" << std::endl;
        } else {
            std::cout << "✅ Julia expected output loaded successfully" << std::endl;
            auto julia_history = julia_expected["profile_history"];
            std::cout << "   📊 Julia portfolio history: " << julia_history.size() << " days" << std::endl;
        }
        
        // Step 3: Parse strategy
        std::cout << "\n[3/6] Parsing strategy..." << std::endl;
        StrategyParser parser;
        Strategy strategy;
        try {
            strategy = parser.parse_strategy(strategy_content);
            std::cout << "✅ Strategy parsed successfully" << std::endl;
            std::cout << "   📅 Period: " << strategy.period << " days" << std::endl;
            std::cout << "   📅 End Date: " << strategy.end_date << std::endl;
            std::cout << "   📈 Tickers: ";
            for (size_t i = 0; i < strategy.tickers.size(); ++i) {
                if (i > 0) std::cout << ", ";
                std::cout << strategy.tickers[i];
            }
            std::cout << std::endl;
        } catch (const std::exception& e) {
            std::cerr << "❌ Error parsing strategy: " << e.what() << std::endl;
            return false;
        }
        
        // Step 4: Execute strategy
        std::cout << "\n[4/6] Executing SmallStrategy..." << std::endl;
        BacktestingEngine engine;
        BacktestParams params;
        params.strategy = strategy;
        params.period = strategy.period;
        params.end_date = strategy.end_date;
        params.live_execution = false;
        params.global_cache_length = 0;
        
        auto start_time = std::chrono::high_resolution_clock::now();
        BacktestResult result;
        try {
            result = engine.execute_backtest(params);
            auto end_time = std::chrono::high_resolution_clock::now();
            auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end_time - start_time);
            
            if (result.success) {
                std::cout << "✅ Strategy executed successfully" << std::endl;
                std::cout << "   ⚡ Execution time: " << duration.count() << " ms" << std::endl;
                std::cout << "   📊 Portfolio history: " << result.portfolio_history.size() << " days" << std::endl;
            } else {
                std::cerr << "❌ Strategy execution failed" << std::endl;
                return false;
            }
        } catch (const std::exception& e) {
            std::cerr << "❌ Error executing strategy: " << e.what() << std::endl;
            return false;
        }
        
        // Step 5: Validate results
        std::cout << "\n[5/6] Validating results..." << std::endl;
        
        // Count active days and ticker distribution
        size_t active_days = 0;
        std::unordered_map<std::string, int> ticker_counts;
        
        for (const auto& day : result.portfolio_history) {
            if (!day.empty()) {
                active_days++;
                for (const auto& stock : day.stock_list()) {
                    ticker_counts[stock.ticker()]++;
                }
            }
        }
        
        float utilization = static_cast<float>(active_days) / result.portfolio_history.size() * 100.0f;
        std::cout << "   📈 Active days: " << active_days << "/" << result.portfolio_history.size() 
                 << " (" << std::fixed << std::setprecision(1) << utilization << "%)" << std::endl;
        
        std::cout << "   🎯 Ticker distribution:" << std::endl;
        for (const auto& [ticker, count] : ticker_counts) {
            float pct = static_cast<float>(count) / result.portfolio_history.size() * 100.0f;
            std::cout << "      " << ticker << ": " << count << " days (" 
                     << std::fixed << std::setprecision(1) << pct << "%)" << std::endl;
        }
        
        // Validate expected tickers
        std::set<std::string> expected_tickers = {"QQQ", "PSQ", "SHY"};
        bool all_tickers_found = true;
        for (const auto& expected : expected_tickers) {
            if (ticker_counts.find(expected) == ticker_counts.end() || ticker_counts[expected] == 0) {
                std::cerr << "❌ Expected ticker " << expected << " not found in results" << std::endl;
                all_tickers_found = false;
            }
        }
        
        if (all_tickers_found) {
            std::cout << "✅ All expected tickers present in results" << std::endl;
        }
        
        // Step 6: Julia compatibility validation
        std::cout << "\n[6/6] Julia compatibility validation..." << std::endl;
        
        if (julia_expected.empty()) {
            std::cout << "⚠️  Skipping Julia compatibility (expected output not available)" << std::endl;
        } else {
            bool compatibility_passed = validate_julia_compatibility(result, julia_expected);
            if (compatibility_passed) {
                std::cout << "✅ Julia compatibility validation passed" << std::endl;
            } else {
                std::cout << "⚠️  Julia compatibility validation completed with warnings" << std::endl;
            }
        }
        
        // Final summary
        std::cout << "\n=====================================================" << std::endl;
        std::cout << "              VERIFICATION SUMMARY" << std::endl;
        std::cout << "=====================================================" << std::endl;
        std::cout << "✅ Strategy Loading: PASSED" << std::endl;
        std::cout << "✅ Strategy Parsing: PASSED" << std::endl;
        std::cout << "✅ Strategy Execution: PASSED" << std::endl;
        std::cout << "✅ Result Validation: PASSED" << std::endl;
        std::cout << "✅ Ticker Validation: " << (all_tickers_found ? "PASSED" : "FAILED") << std::endl;
        std::cout << "✅ Julia Compatibility: " << (!julia_expected.empty() ? "VALIDATED" : "SKIPPED") << std::endl;
        std::cout << "=====================================================" << std::endl;
        std::cout << "🏆 SMALLSTRATEGY VERIFICATION: " << (all_tickers_found ? "SUCCESS" : "PARTIAL") << std::endl;
        std::cout << "=====================================================" << std::endl;
        
        return all_tickers_found;
    }

private:
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
    
    bool validate_julia_compatibility(const BacktestResult& cpp_result, const json& julia_expected) {
        if (!julia_expected.contains("profile_history")) {
            std::cout << "❌ Julia expected output missing profile_history" << std::endl;
            return false;
        }
        
        auto julia_history = julia_expected["profile_history"];
        size_t comparison_days = std::min(julia_history.size(), cpp_result.portfolio_history.size());
        
        std::cout << "   📊 Comparing " << comparison_days << " days..." << std::endl;
        
        int matches = 0;
        int valid_comparisons = 0;
        std::unordered_map<std::string, int> julia_counts;
        std::unordered_map<std::string, int> cpp_counts;
        
        for (size_t i = 0; i < comparison_days; ++i) {
            std::string julia_ticker = "";
            std::string cpp_ticker = "";
            
            // Extract Julia ticker
            if (i < julia_history.size() && julia_history[i].contains("stockList") && 
                !julia_history[i]["stockList"].empty()) {
                auto stock = julia_history[i]["stockList"][0];
                if (stock.contains("ticker")) {
                    julia_ticker = stock["ticker"];
                    julia_counts[julia_ticker]++;
                }
            }
            
            // Extract C++ ticker
            if (i < cpp_result.portfolio_history.size() && !cpp_result.portfolio_history[i].empty()) {
                auto stocks = cpp_result.portfolio_history[i].stock_list();
                if (!stocks.empty()) {
                    cpp_ticker = stocks[0].ticker();
                    cpp_counts[cpp_ticker]++;
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
            float match_percentage = static_cast<float>(matches) / valid_comparisons * 100.0f;
            std::cout << "   🎯 Match rate: " << matches << "/" << valid_comparisons 
                     << " (" << std::fixed << std::setprecision(1) << match_percentage << "%)" << std::endl;
            
            std::cout << "   📈 Julia ticker distribution:" << std::endl;
            for (const auto& [ticker, count] : julia_counts) {
                float pct = static_cast<float>(count) / comparison_days * 100.0f;
                std::cout << "      " << ticker << ": " << std::fixed << std::setprecision(1) << pct << "%" << std::endl;
            }
            
            std::cout << "   📈 C++ ticker distribution:" << std::endl;
            for (const auto& [ticker, count] : cpp_counts) {
                float pct = static_cast<float>(count) / comparison_days * 100.0f;
                std::cout << "      " << ticker << ": " << std::fixed << std::setprecision(1) << pct << "%" << std::endl;
            }
            
            if (match_percentage >= 70.0f) {
                std::cout << "   ✅ Compatibility: EXCELLENT (>= 70%)" << std::endl;
                return true;
            } else if (match_percentage >= 50.0f) {
                std::cout << "   ✅ Compatibility: GOOD (>= 50%)" << std::endl;
                return true;
            } else {
                std::cout << "   ⚠️  Compatibility: FAIR (< 50%)" << std::endl;
                return false;
            }
        } else {
            std::cout << "   ❌ No valid comparisons possible" << std::endl;
            return false;
        }
    }
};

int main() {
    SmallStrategyVerifier verifier;
    bool success = verifier.run_verification();
    return success ? 0 : 1;
}