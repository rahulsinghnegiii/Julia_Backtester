#include \"types.h\"
#include <algorithm>

namespace atlas {

DayData::DayData(std::vector<StockInfo> stock_list)
    : stock_list_(std::move(stock_list)) {}

void DayData::add_stock(const StockInfo& stock) {
    stock_list_.push_back(stock);
}

void DayData::clear() {
    stock_list_.clear();
}

bool DayData::operator==(const DayData& other) const {
    if (stock_list_.size() != other.stock_list_.size()) {
        return false;
    }
    
    // Sort both lists by ticker for comparison (like Julia implementation)
    auto this_sorted = stock_list_;
    auto other_sorted = other.stock_list_;
    
    std::sort(this_sorted.begin(), this_sorted.end(),
              [](const StockInfo& a, const StockInfo& b) {
                  return a.ticker() < b.ticker();
              });
    
    std::sort(other_sorted.begin(), other_sorted.end(),
              [](const StockInfo& a, const StockInfo& b) {
                  return a.ticker() < b.ticker();
              });
    
    return this_sorted == other_sorted;
}

bool DayData::operator!=(const DayData& other) const {
    return !(*this == other);
}

} // namespace atlas