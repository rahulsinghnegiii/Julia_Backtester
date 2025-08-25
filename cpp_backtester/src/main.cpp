#include "backtesting_engine.h"
#include "strategy_parser.h"
#include <iostream>
#include <fstream>
#include <string>
#include <chrono>

using namespace atlas;

void print_usage(const char* program_name) {
    std::cout << "Usage: " << program_name << " <strategy_file.json>" << std::endl;
    std::cout << "  strategy_file.json: Path to the strategy JSON file" << std::endl;
    std::cout << std::endl;
    std::cout << "Example:" << std::endl;
    std::cout << "  " << program_name << " SmallStrategy.json" << std::endl;
}

std::string read_file(const std::string& filename) {
    std::ifstream file(filename);
    if (!file.is_open()) {
        throw std::runtime_error("Could not open file: " + filename);
    }
    
    std::string content;
    std::string line;
    while (std::getline(file, line)) {
        content += line + "\n";
    }
    
    return content;
}

void print_results(const BacktestResult& result) {
    std::cout << "\n=== Backtest Results ===" << std::endl;
    std::cout << "Success: " << (result.success ? "Yes" : "No") << std::endl;
    std::cout << "Execution Time: " << result.execution_time.count() << " ms" << std::endl;
    
    if (!result.success) {
        std::cout << "Error: " << result.error_message << std::endl;
        return;
    }
    
    std::cout << "\nPortfolio History (" << result.portfolio_history.size() << " days):" << std::endl;
    
    for (size_t day = 0; day < result.portfolio_history.size(); ++day) {
        const auto& day_data = result.portfolio_history[day];
        std::cout << "Day " << day + 1 << ": ";
        
        if (day_data.empty()) {
            std::cout << "No positions";
        } else {
            for (size_t i = 0; i < day_data.stock_list().size(); ++i) {
                const auto& stock = day_data.stock_list()[i];
                if (i > 0) std::cout << ", ";
                std::cout << stock.ticker() << "(" << stock.weight_tomorrow() << ")";
            }
        }
        std::cout << std::endl;
        
        // Limit output for readability
        if (day >= 9) {
            std::cout << "... (" << (result.portfolio_history.size() - day - 1) << " more days)" << std::endl;
            break;
        }
    }
    
    if (!result.flow_count.empty()) {
        std::cout << "\nFlow Count:" << std::endl;
        for (const auto& [hash, count] : result.flow_count) {
            std::cout << "  " << hash.substr(0, 8) << "...: " << count << std::endl;
        }
    }
}

int main(int argc, char* argv[]) {
    std::cout << "Atlas Backtesting Engine v1.0" << std::endl;
    std::cout << "C++ Migration from Julia" << std::endl;
    std::cout << "==============================" << std::endl;
    
    // Check command line arguments
    if (argc != 2) {
        print_usage(argv[0]);
        return 1;
    }
    
    std::string strategy_file = argv[1];
    
    try {
        // Read strategy file
        std::cout << "\nReading strategy file: " << strategy_file << std::endl;
        std::string json_content = read_file(strategy_file);
        
        // Create engine and parser
        BacktestingEngine engine;
        StrategyParser parser;
        
        // Parse strategy
        std::cout << "Parsing strategy..." << std::endl;
        Strategy strategy = parser.parse_strategy(json_content);
        
        std::cout << "Strategy Details:" << std::endl;
        std::cout << "  Period: " << strategy.period << " days" << std::endl;
        std::cout << "  End Date: " << strategy.end_date << std::endl;
        std::cout << "  Tickers: ";
        for (size_t i = 0; i < strategy.tickers.size(); ++i) {
            if (i > 0) std::cout << ", ";
            std::cout << strategy.tickers[i];
        }
        std::cout << std::endl;
        std::cout << "  Indicators: " << strategy.indicators.size() << std::endl;
        
        // Create backtest parameters
        BacktestParams params;
        params.strategy = strategy;
        params.period = strategy.period;
        params.end_date = strategy.end_date;
        params.live_execution = false;
        params.global_cache_length = 0;
        
        // Execute backtest
        std::cout << "\nExecuting backtest..." << std::endl;
        auto start_time = std::chrono::high_resolution_clock::now();
        
        BacktestResult result = engine.execute_backtest(params);
        
        auto end_time = std::chrono::high_resolution_clock::now();
        auto total_time = std::chrono::duration_cast<std::chrono::milliseconds>(end_time - start_time);
        
        std::cout << "Backtest completed in " << total_time.count() << " ms" << std::endl;
        
        // Print results
        print_results(result);
        
        return result.success ? 0 : 1;
        
    } catch (const std::exception& e) {
        std::cerr << "\nError: " << e.what() << std::endl;
        return 1;
    }
}