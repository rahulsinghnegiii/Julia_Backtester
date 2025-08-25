#include \"types.h\"

namespace atlas {

SubtreeContext::SubtreeContext(int backtest_period,
                               std::vector<DayData> profile_history,
                               std::unordered_map<std::string, int> flow_count,
                               std::unordered_map<std::string, std::vector<DayData>> flow_stocks,
                               std::vector<std::string> trading_dates,
                               std::vector<bool> active_mask,
                               int common_data_span)
    : backtest_period_(backtest_period),
      profile_history_(std::move(profile_history)),
      flow_count_(std::move(flow_count)),
      flow_stocks_(std::move(flow_stocks)),
      trading_dates_(std::move(trading_dates)),
      active_mask_(std::move(active_mask)),
      common_data_span_(common_data_span) {}

} // namespace atlas