#pragma once

#include \"types.h\"
#include <nlohmann/json.hpp>
#include <string>
#include <memory>
#include <vector>

namespace atlas {

/**
 * @brief Represents a node in the strategy tree
 * Equivalent to Julia's node structure handling
 */
struct StrategyNode {
    std::string id;
    std::string type;
    std::string name;
    std::string component_type;
    nlohmann::json properties;
    nlohmann::json branches;
    std::vector<StrategyNode> sequence;
    std::string hash;
    std::string parent_hash;
    std::string node_children_hash;
    
    StrategyNode() = default;
    StrategyNode(const nlohmann::json& json_node);
};

/**
 * @brief Represents a complete trading strategy
 * Equivalent to Julia's strategy root handling
 */
struct Strategy {
    StrategyNode root;
    std::vector<std::string> tickers;
    std::vector<nlohmann::json> indicators;
    std::string node_children_hash;
    int period;
    std::string end_date;
    std::string strategy_hash;
    
    Strategy() = default;
    Strategy(const nlohmann::json& json_strategy);
};

/**
 * @brief Parser for strategy JSON structures
 * Equivalent to Julia's JSON parsing functionality
 */
class StrategyParser {
public:
    StrategyParser() = default;
    
    /**
     * @brief Parse strategy from JSON string
     * @param json_str JSON string representing the strategy
     * @return Parsed strategy object
     */
    Strategy parse_strategy(const std::string& json_str);
    
    /**
     * @brief Parse strategy from JSON object
     * @param json_obj JSON object representing the strategy
     * @return Parsed strategy object
     */
    Strategy parse_strategy(const nlohmann::json& json_obj);
    
    /**
     * @brief Validate strategy structure
     * @param strategy Strategy to validate
     * @return true if valid, false otherwise
     */
    bool validate_strategy(const Strategy& strategy);
    
    /**
     * @brief Parse node from JSON
     * @param json_node JSON object representing a node
     * @return Parsed strategy node
     */
    StrategyNode parse_node(const nlohmann::json& json_node);
    
private:
    /**
     * @brief Validate node structure
     * @param node Node to validate
     * @return true if valid, false otherwise
     */
    bool validate_node(const StrategyNode& node);
    
    /**
     * @brief Extract tickers from strategy tree
     * @param root Root node of the strategy
     * @return List of unique tickers
     */
    std::vector<std::string> extract_tickers(const StrategyNode& root);
    
    /**
     * @brief Extract indicators from strategy tree
     * @param root Root node of the strategy
     * @return List of indicators
     */
    std::vector<nlohmann::json> extract_indicators(const StrategyNode& root);
};

/**
 * @brief Exception for strategy parsing errors
 */
class StrategyParseError : public std::exception {
public:
    explicit StrategyParseError(const std::string& message) : message_(message) {}
    const char* what() const noexcept override { return message_.c_str(); }
    
private:
    std::string message_;
};

} // namespace atlas