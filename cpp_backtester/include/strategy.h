#pragma once

#include <string>
#include <vector>
#include <unordered_map>
#include <memory>
#include <chrono>
#include <functional>

namespace backtester {

// Forward declarations
class DataProvider;
struct NodeResult;
struct PortfolioEntry;

// Data structures
struct DayData {
    std::string date;
    double open = 0.0;
    double high = 0.0;
    double low = 0.0;
    double close = 0.0;
    double volume = 0.0;
    double adjusted_close = 0.0;
};

struct StockInfo {
    std::string ticker;
    std::vector<DayData> data;
    std::unordered_map<std::string, std::vector<double>> indicators;
};

struct PortfolioEntry {
    std::string ticker;
    double weight_tomorrow = 0.0;
    double weight_today = 0.0;
    double price = 0.0;
};

struct BacktestResult {
    std::vector<double> returns;
    std::vector<std::string> dates;
    std::vector<std::vector<PortfolioEntry>> profile_history;
    int days = 0;
    std::string strategy_hash;
    double execution_time_ms = 0.0;
};

// Node types
enum class NodeType {
    ROOT,
    STOCK,
    CONDITION,
    SORT,
    ALLOCATION
};

// Node base class
struct Node {
    std::string id;
    NodeType type;
    std::string name;
    std::unordered_map<std::string, std::string> properties;
    std::string hash;
    std::string parent_hash;
    
    virtual ~Node() = default;
};

// Specific node types
struct StockNode : public Node {
    std::string symbol;
    
    StockNode() { type = NodeType::STOCK; }
};

struct ConditionNode : public Node {
    struct Operand {
        std::string indicator;
        std::string source;
        std::string period;
        std::string numerator;
        std::string denominator;
    };
    
    std::string comparison;  // "<", ">", "==", "<=", ">="
    Operand x;
    Operand y;
    std::vector<std::shared_ptr<Node>> true_branch;
    std::vector<std::shared_ptr<Node>> false_branch;
    
    ConditionNode() { type = NodeType::CONDITION; }
};

struct SortNode : public Node {
    struct SelectFunction {
        std::string function;  // "Top", "Bottom"
        int howmany = 1;
    };
    
    struct SortByFunction {
        std::string function;  // "Relative Strength Index", etc.
        std::string window;
    };
    
    SelectFunction select;
    SortByFunction sortby;
    std::vector<std::shared_ptr<Node>> children;
    
    SortNode() { type = NodeType::SORT; }
};

// Strategy class
class Strategy {
public:
    Strategy(const std::string& strategy_json);
    ~Strategy() = default;
    
    // Main execution
    BacktestResult execute(int period_days, const std::string& end_date, 
                          const std::string& strategy_hash, 
                          std::shared_ptr<DataProvider> data_provider);
    
    // Validation
    bool validate() const;
    
    // Getters
    const std::vector<std::string>& get_tickers() const { return tickers_; }
    const std::vector<std::shared_ptr<Node>>& get_sequence() const { return sequence_; }
    const std::string& get_type() const { return type_; }
    
    // Node processing
    std::vector<PortfolioEntry> process_node_sequence(
        const std::vector<std::shared_ptr<Node>>& nodes,
        const std::string& current_date,
        const std::unordered_map<std::string, StockInfo>& stock_data);
    
private:
    std::string type_;
    std::vector<std::string> tickers_;
    std::vector<std::shared_ptr<Node>> sequence_;
    std::unordered_map<std::string, std::string> properties_;
    
    // Parser methods
    void parse_json(const std::string& json_str);
    std::shared_ptr<Node> parse_node(const std::string& node_json);
    std::shared_ptr<ConditionNode> parse_condition_node(const std::string& node_json);
    std::shared_ptr<StockNode> parse_stock_node(const std::string& node_json);
    std::shared_ptr<SortNode> parse_sort_node(const std::string& node_json);
    
    // Node processors
    std::vector<PortfolioEntry> process_stock_node(
        const StockNode& node,
        const std::string& current_date,
        const std::unordered_map<std::string, StockInfo>& stock_data);
    
    std::vector<PortfolioEntry> process_condition_node(
        const ConditionNode& node,
        const std::string& current_date,
        const std::unordered_map<std::string, StockInfo>& stock_data);
    
    std::vector<PortfolioEntry> process_sort_node(
        const SortNode& node,
        const std::string& current_date,
        const std::unordered_map<std::string, StockInfo>& stock_data);
    
    // Helper methods
    bool evaluate_condition(
        const ConditionNode::Operand& x,
        const ConditionNode::Operand& y,
        const std::string& comparison,
        const std::string& current_date,
        const std::unordered_map<std::string, StockInfo>& stock_data);
    
    double get_indicator_value(
        const ConditionNode::Operand& operand,
        const std::string& current_date,
        const std::unordered_map<std::string, StockInfo>& stock_data);
    
    std::vector<double> calculate_returns(
        const std::vector<std::vector<PortfolioEntry>>& portfolio_history,
        const std::unordered_map<std::string, StockInfo>& stock_data);
};

// SmallStrategy specific implementation
class SmallStrategy : public Strategy {
public:
    SmallStrategy();
    
    // SmallStrategy logic:
    // 1. If SPY current price < SPY SMA-200d: Buy QQQ
    // 2. Else if QQQ current price < QQQ SMA-20d: Sort by RSI-10d (Top 1) → Buy PSQ or SHY
    // 3. Else: Buy QQQ
    
    static std::string get_strategy_json();
    static std::vector<std::string> get_expected_tickers();
    
    // Validation specific to SmallStrategy
    bool validate_small_strategy_logic() const;
};

// Utility functions
namespace utils {
    std::string generate_hash(const std::string& content);
    std::string date_to_string(const std::chrono::system_clock::time_point& time);
    std::chrono::system_clock::time_point string_to_date(const std::string& date_str);
    std::vector<std::string> generate_date_range(const std::string& start_date, 
                                                 const std::string& end_date);
    double normalize_weight(double weight);
    bool validate_ticker(const std::string& ticker);
}

} // namespace backtester