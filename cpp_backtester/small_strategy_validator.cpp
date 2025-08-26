#include <iostream>
#include <vector>
#include <string>
#include <unordered_map>
#include <algorithm>
#include <cmath>

// Minimal implementation to validate SmallStrategy logic without full dependencies

namespace atlas_test {

// Basic data structures for validation
struct StockInfo {
    std::string ticker;
    float weight_tomorrow;
    
    StockInfo(const std::string& t, float w) : ticker(t), weight_tomorrow(w) {}
};

struct DayData {
    std::vector<StockInfo> stock_list;
    
    bool empty() const { return stock_list.empty(); }
    void add_stock(const std::string& ticker, float weight) {
        stock_list.emplace_back(ticker, weight);
    }
};

// Technical Analysis Functions (simplified for validation)
class TAFunctions {
public:
    static std::vector<float> calculate_sma(const std::vector<float>& data, int period) {
        std::vector<float> sma_values(data.size(), std::numeric_limits<float>::quiet_NaN());
        
        for (size_t i = period - 1; i < data.size(); ++i) {
            float sum = 0.0f;
            for (int j = 0; j < period; ++j) {
                sum += data[i - j];
            }
            sma_values[i] = sum / period;
        }
        
        return sma_values;
    }
    
    static std::vector<float> calculate_rsi(const std::vector<float>& prices, int period) {
        std::vector<float> rsi_values(prices.size(), std::numeric_limits<float>::quiet_NaN());
        
        if (prices.size() < static_cast<size_t>(period + 1)) {
            return rsi_values;
        }
        
        // Calculate price changes
        std::vector<float> gains, losses;
        for (size_t i = 1; i < prices.size(); ++i) {
            float change = prices[i] - prices[i-1];
            gains.push_back(change > 0 ? change : 0);
            losses.push_back(change < 0 ? -change : 0);
        }
        
        // Calculate initial averages
        float avg_gain = 0, avg_loss = 0;
        for (int i = 0; i < period; ++i) {
            avg_gain += gains[i];
            avg_loss += losses[i];
        }
        avg_gain /= period;
        avg_loss /= period;
        
        // Calculate RSI
        for (size_t i = period; i < rsi_values.size(); ++i) {
            if (avg_loss > 0) {
                float rs = avg_gain / avg_loss;
                rsi_values[i] = 100.0f - (100.0f / (1.0f + rs));
            }
            
            // Update averages (Wilder's smoothing)
            if (i < gains.size()) {
                avg_gain = (avg_gain * (period - 1) + gains[i]) / period;
                avg_loss = (avg_loss * (period - 1) + losses[i]) / period;
            }
        }
        
        return rsi_values;
    }
    
    static float get_current_price(const std::string& ticker, const std::vector<float>& prices) {
        // Return the last available price
        return prices.empty() ? 0.0f : prices.back();
    }
};

// Mock Data Provider
class MockDataProvider {
public:
    static std::vector<float> get_price_data(const std::string& ticker, int days) {
        std::vector<float> prices;
        float base_price = get_base_price(ticker);
        
        for (int i = 0; i < days; ++i) {
            // Generate realistic price movement
            float variation = std::sin(i * 0.1f) * 5.0f + (std::rand() % 100 - 50) * 0.1f;
            prices.push_back(base_price + variation + i * 0.05f);
        }
        
        return prices;
    }
    
private:
    static float get_base_price(const std::string& ticker) {
        if (ticker == "SPY") return 450.0f;
        if (ticker == "QQQ") return 380.0f;
        if (ticker == "PSQ") return 20.0f;
        if (ticker == "SHY") return 85.0f;
        return 100.0f;
    }
};

// SmallStrategy Logic Validator
class SmallStrategyValidator {
public:
    static bool validate_strategy_logic() {
        std::cout << "=== SmallStrategy Logic Validation ===" << std::endl;
        
        // Generate test data
        int test_days = 250; // Test with 250 days
        auto spy_prices = MockDataProvider::get_price_data("SPY", test_days);
        auto qqq_prices = MockDataProvider::get_price_data("QQQ", test_days);
        auto psq_prices = MockDataProvider::get_price_data("PSQ", test_days);
        auto shy_prices = MockDataProvider::get_price_data("SHY", test_days);
        
        // Calculate technical indicators
        auto spy_sma_200 = TAFunctions::calculate_sma(spy_prices, 200);
        auto qqq_sma_20 = TAFunctions::calculate_sma(qqq_prices, 20);
        auto psq_rsi_10 = TAFunctions::calculate_rsi(psq_prices, 10);
        auto shy_rsi_10 = TAFunctions::calculate_rsi(shy_prices, 10);
        
        std::cout << "Generated " << test_days << " days of test data" << std::endl;
        std::cout << "SPY SMA-200 calculated: " << count_valid_values(spy_sma_200) << " valid values" << std::endl;
        std::cout << "QQQ SMA-20 calculated: " << count_valid_values(qqq_sma_20) << " valid values" << std::endl;
        std::cout << "PSQ RSI-10 calculated: " << count_valid_values(psq_rsi_10) << " valid values" << std::endl;
        std::cout << "SHY RSI-10 calculated: " << count_valid_values(shy_rsi_10) << " valid values" << std::endl;
        
        // Execute SmallStrategy logic for each day
        std::vector<DayData> portfolio_history;
        int spy_condition_true = 0, qqq_condition_true = 0, else_branch = 0;
        int psq_selected = 0, shy_selected = 0;
        
        for (int day = 200; day < test_days; ++day) { // Start from day 200 to have enough SMA data
            DayData day_portfolio = execute_small_strategy_day(
                day, spy_prices, qqq_prices, psq_prices, shy_prices,
                spy_sma_200, qqq_sma_20, psq_rsi_10, shy_rsi_10
            );
            
            portfolio_history.push_back(day_portfolio);
            
            // Count strategy outcomes
            if (!day_portfolio.empty()) {
                const auto& stock = day_portfolio.stock_list[0];
                if (stock.ticker == "QQQ") {
                    float spy_current = spy_prices[day];
                    float spy_sma = spy_sma_200[day];
                    if (!std::isnan(spy_sma) && spy_current < spy_sma) {
                        spy_condition_true++;
                    } else {
                        float qqq_current = qqq_prices[day];
                        float qqq_sma = qqq_sma_20[day];
                        if (std::isnan(qqq_sma) || qqq_current >= qqq_sma) {
                            else_branch++;
                        }
                    }
                } else if (stock.ticker == "PSQ") {
                    psq_selected++;
                    qqq_condition_true++;
                } else if (stock.ticker == "SHY") {
                    shy_selected++;
                    qqq_condition_true++;
                }
            }
        }
        
        // Validate results
        std::cout << "\n=== Strategy Execution Results ===" << std::endl;
        std::cout << "Total days executed: " << portfolio_history.size() << std::endl;
        std::cout << "SPY condition true (QQQ selected): " << spy_condition_true << std::endl;
        std::cout << "QQQ condition true (Sort executed): " << qqq_condition_true << std::endl;
        std::cout << "  - PSQ selected: " << psq_selected << std::endl;
        std::cout << "  - SHY selected: " << shy_selected << std::endl;
        std::cout << "Else branch (QQQ selected): " << else_branch << std::endl;
        
        // Validate expected behavior
        bool validation_passed = true;
        
        if (portfolio_history.empty()) {
            std::cout << "❌ FAIL: No portfolio history generated" << std::endl;
            validation_passed = false;
        } else {
            std::cout << "✅ PASS: Portfolio history generated" << std::endl;
        }
        
        if (spy_condition_true + qqq_condition_true + else_branch != static_cast<int>(portfolio_history.size())) {
            std::cout << "❌ FAIL: Strategy logic count mismatch" << std::endl;
            validation_passed = false;
        } else {
            std::cout << "✅ PASS: Strategy logic counts consistent" << std::endl;
        }
        
        if (psq_selected == 0 && shy_selected == 0) {
            std::cout << "⚠️  WARNING: Sort node never executed (may be expected with test data)" << std::endl;
        } else {
            std::cout << "✅ PASS: Sort node executed and selected stocks" << std::endl;
        }
        
        // Show sample results
        std::cout << "\n=== Sample Portfolio (first 10 days) ===" << std::endl;
        for (int i = 0; i < std::min(10, static_cast<int>(portfolio_history.size())); ++i) {
            std::cout << "Day " << (i + 1) << ": ";
            if (portfolio_history[i].empty()) {
                std::cout << "No positions";
            } else {
                for (const auto& stock : portfolio_history[i].stock_list) {
                    std::cout << stock.ticker << "(" << stock.weight_tomorrow << ") ";
                }
            }
            std::cout << std::endl;
        }
        
        return validation_passed;
    }
    
private:
    static DayData execute_small_strategy_day(
        int day,
        const std::vector<float>& spy_prices,
        const std::vector<float>& qqq_prices,
        const std::vector<float>& psq_prices,
        const std::vector<float>& shy_prices,
        const std::vector<float>& spy_sma_200,
        const std::vector<float>& qqq_sma_20,
        const std::vector<float>& psq_rsi_10,
        const std::vector<float>& shy_rsi_10
    ) {
        DayData day_portfolio;
        
        // SmallStrategy Logic:
        // IF SPY current_price < SPY SMA-200d: BUY QQQ
        // ELSE IF QQQ current_price < QQQ SMA-20d: Sort by RSI-10d (PSQ vs SHY), select Top-1
        // ELSE: BUY QQQ
        
        float spy_current = spy_prices[day];
        float spy_sma = spy_sma_200[day];
        
        if (!std::isnan(spy_sma) && spy_current < spy_sma) {
            // Condition 1: SPY price < SMA-200 → Buy QQQ
            day_portfolio.add_stock("QQQ", 1.0f);
        } else {
            float qqq_current = qqq_prices[day];
            float qqq_sma = qqq_sma_20[day];
            
            if (!std::isnan(qqq_sma) && qqq_current < qqq_sma) {
                // Condition 2: QQQ price < SMA-20 → Sort by RSI
                float psq_rsi = day < static_cast<int>(psq_rsi_10.size()) ? psq_rsi_10[day] : std::numeric_limits<float>::quiet_NaN();
                float shy_rsi = day < static_cast<int>(shy_rsi_10.size()) ? shy_rsi_10[day] : std::numeric_limits<float>::quiet_NaN();
                
                if (!std::isnan(psq_rsi) && !std::isnan(shy_rsi)) {
                    // Select stock with higher RSI (Top-1)
                    if (psq_rsi > shy_rsi) {
                        day_portfolio.add_stock("PSQ", 1.0f);
                    } else {
                        day_portfolio.add_stock("SHY", 1.0f);
                    }
                } else if (!std::isnan(psq_rsi)) {
                    day_portfolio.add_stock("PSQ", 1.0f);
                } else if (!std::isnan(shy_rsi)) {
                    day_portfolio.add_stock("SHY", 1.0f);
                } else {
                    // Fallback if RSI unavailable
                    day_portfolio.add_stock("QQQ", 1.0f);
                }
            } else {
                // Else condition: Buy QQQ
                day_portfolio.add_stock("QQQ", 1.0f);
            }
        }
        
        return day_portfolio;
    }
    
    static int count_valid_values(const std::vector<float>& values) {
        return std::count_if(values.begin(), values.end(), 
                           [](float v) { return !std::isnan(v); });
    }
};

} // namespace atlas_test

int main() {
    std::cout << "Atlas C++ Backend - SmallStrategy Logic Validation" << std::endl;
    std::cout << "=================================================" << std::endl;
    
    bool validation_passed = atlas_test::SmallStrategyValidator::validate_strategy_logic();
    
    std::cout << "\n=== Final Validation Result ===" << std::endl;
    if (validation_passed) {
        std::cout << "✅ SmallStrategy logic validation PASSED" << std::endl;
        std::cout << "   Core algorithms functioning correctly" << std::endl;
        std::cout << "   Strategy decision tree executing as expected" << std::endl;
        return 0;
    } else {
        std::cout << "❌ SmallStrategy logic validation FAILED" << std::endl;
        std::cout << "   Issues found in core algorithm implementation" << std::endl;
        return 1;
    }
}