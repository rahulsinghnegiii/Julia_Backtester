#include \"node_processor.h\"

namespace atlas {

bool NodeProcessor::validate_node(const StrategyNode& node) const {
    return !node.type.empty();
}

void NodeProcessor::increment_flow_count(std::unordered_map<std::string, int>& flow_count, const std::string& hash) {
    if (!hash.empty()) {
        flow_count[hash]++;
    }
}

void NodeProcessor::set_flow_stocks(
    std::unordered_map<std::string, std::vector<DayData>>& flow_stocks,
    const std::vector<DayData>& portfolio_history,
    const std::string& hash
) {
    if (!hash.empty()) {
        flow_stocks[hash] = portfolio_history;
    }
}

} // namespace atlas