#include \"strategy_parser.h\"
#include <stdexcept>
#include <set>
#include <algorithm>

namespace atlas {

StrategyNode::StrategyNode(const nlohmann::json& json_node) {
    if (json_node.contains(\"id\")) {
        id = json_node[\"id\"].get<std::string>();
    }
    
    if (json_node.contains(\"type\")) {
        type = json_node[\"type\"].get<std::string>();
    }
    
    if (json_node.contains(\"name\")) {
        name = json_node[\"name\"].get<std::string>();
    }
    
    if (json_node.contains(\"componentType\")) {
        component_type = json_node[\"componentType\"].get<std::string>();
    }
    
    if (json_node.contains(\"properties\")) {
        properties = json_node[\"properties\"];
    }
    
    if (json_node.contains(\"branches\")) {
        branches = json_node[\"branches\"];
    }
    
    if (json_node.contains(\"sequence\") && json_node[\"sequence\"].is_array()) {
        for (const auto& seq_node : json_node[\"sequence\"]) {
            sequence.emplace_back(seq_node);
        }
    }
    
    if (json_node.contains(\"hash\")) {
        hash = json_node[\"hash\"].get<std::string>();
    }
    
    if (json_node.contains(\"parentHash\")) {
        parent_hash = json_node[\"parentHash\"].get<std::string>();
    }
    
    if (json_node.contains(\"nodeChildrenHash\")) {
        node_children_hash = json_node[\"nodeChildrenHash\"].get<std::string>();
    }
}

Strategy::Strategy(const nlohmann::json& json_strategy) {
    if (!json_strategy.contains(\"json\")) {
        throw StrategyParseError(\"Missing 'json' field in strategy\");
    }
    
    // Parse the nested JSON string
    auto inner_json = nlohmann::json::parse(json_strategy[\"json\"].get<std::string>());
    
    // Parse root node
    root = StrategyNode(inner_json);
    
    // Extract tickers
    if (inner_json.contains(\"tickers\") && inner_json[\"tickers\"].is_array()) {
        for (const auto& ticker : inner_json[\"tickers\"]) {
            tickers.push_back(ticker.get<std::string>());
        }
    }
    
    // Extract indicators
    if (inner_json.contains(\"indicators\") && inner_json[\"indicators\"].is_array()) {
        for (const auto& indicator : inner_json[\"indicators\"]) {
            indicators.push_back(indicator);
        }
    }
    
    // Extract node children hash
    if (inner_json.contains(\"nodeChildrenHash\")) {
        node_children_hash = inner_json[\"nodeChildrenHash\"].get<std::string>();
    }
    
    // Extract outer fields
    if (json_strategy.contains(\"period\")) {
        period = std::stoi(json_strategy[\"period\"].get<std::string>());
    }
    
    if (json_strategy.contains(\"end_date\")) {
        end_date = json_strategy[\"end_date\"].get<std::string>();
    }
    
    if (json_strategy.contains(\"hash\")) {
        strategy_hash = json_strategy[\"hash\"].get<std::string>();
    }
}

Strategy StrategyParser::parse_strategy(const std::string& json_str) {
    try {
        auto json_obj = nlohmann::json::parse(json_str);
        return parse_strategy(json_obj);
    } catch (const nlohmann::json::exception& e) {
        throw StrategyParseError(\"JSON parsing error: \" + std::string(e.what()));
    }
}

Strategy StrategyParser::parse_strategy(const nlohmann::json& json_obj) {
    try {
        Strategy strategy(json_obj);
        
        if (!validate_strategy(strategy)) {
            throw StrategyParseError(\"Strategy validation failed\");
        }
        
        return strategy;
    } catch (const std::exception& e) {
        throw StrategyParseError(\"Strategy parsing error: \" + std::string(e.what()));
    }
}

bool StrategyParser::validate_strategy(const Strategy& strategy) {
    // Validate root node
    if (!validate_node(strategy.root)) {
        return false;
    }
    
    // Validate that we have tickers
    if (strategy.tickers.empty()) {
        return false;
    }
    
    // Validate period
    if (strategy.period <= 0) {
        return false;
    }
    
    // Validate end_date format (basic check)
    if (strategy.end_date.empty()) {
        return false;
    }
    
    return true;
}

StrategyNode StrategyParser::parse_node(const nlohmann::json& json_node) {
    return StrategyNode(json_node);
}

bool StrategyParser::validate_node(const StrategyNode& node) {
    // Must have a type
    if (node.type.empty()) {
        return false;
    }
    
    // Type-specific validation
    if (node.type == \"stock\") {
        // Stock nodes must have symbol in properties
        if (!node.properties.contains(\"symbol\")) {
            return false;
        }
        auto symbol = node.properties[\"symbol\"];
        if (!symbol.is_string() || symbol.get<std::string>().empty()) {
            return false;
        }
    } else if (node.type == \"condition\") {
        // Conditional nodes must have comparison and x/y in properties
        if (!node.properties.contains(\"comparison\") ||
            !node.properties.contains(\"x\") ||
            !node.properties.contains(\"y\")) {
            return false;
        }
    } else if (node.type == \"Sort\") {
        // Sort nodes must have select and sortby in properties
        if (!node.properties.contains(\"select\") ||
            !node.properties.contains(\"sortby\")) {
            return false;
        }
    }
    
    // Recursively validate child nodes
    for (const auto& child : node.sequence) {
        if (!validate_node(child)) {
            return false;
        }
    }
    
    return true;
}

std::vector<std::string> StrategyParser::extract_tickers(const StrategyNode& root) {
    std::set<std::string> ticker_set;
    
    // Extract from current node if it's a stock node
    if (root.type == \"stock\" && root.properties.contains(\"symbol\")) {
        ticker_set.insert(root.properties[\"symbol\"].get<std::string>());
    }
    
    // Extract from properties if they reference tickers
    if (root.properties.contains(\"source\")) {
        ticker_set.insert(root.properties[\"source\"].get<std::string>());
    }
    
    // Recursively extract from child nodes
    for (const auto& child : root.sequence) {
        auto child_tickers = extract_tickers(child);
        ticker_set.insert(child_tickers.begin(), child_tickers.end());
    }
    
    // Convert set to vector
    return std::vector<std::string>(ticker_set.begin(), ticker_set.end());
}

std::vector<nlohmann::json> StrategyParser::extract_indicators(const StrategyNode& root) {
    std::vector<nlohmann::json> indicators;
    
    // Extract indicators from properties
    if (root.properties.contains(\"x\") && root.properties[\"x\"].contains(\"indicator\")) {
        indicators.push_back(root.properties[\"x\"]);
    }
    
    if (root.properties.contains(\"y\") && root.properties[\"y\"].contains(\"indicator\")) {
        indicators.push_back(root.properties[\"y\"]);
    }
    
    if (root.properties.contains(\"sortby\") && root.properties[\"sortby\"].contains(\"function\")) {
        indicators.push_back(root.properties[\"sortby\"]);
    }
    
    // Recursively extract from child nodes
    for (const auto& child : root.sequence) {
        auto child_indicators = extract_indicators(child);
        indicators.insert(indicators.end(), child_indicators.begin(), child_indicators.end());
    }
    
    return indicators;
}

} // namespace atlas