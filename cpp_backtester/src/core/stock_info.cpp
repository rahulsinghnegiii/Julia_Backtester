#include \"types.h\"
#include <algorithm>

namespace atlas {

StockInfo::StockInfo(const std::string& ticker, float weight_tomorrow)
    : ticker_(ticker), weight_tomorrow_(weight_tomorrow) {}

bool StockInfo::operator==(const StockInfo& other) const {
    return ticker_ == other.ticker_ && 
           std::abs(weight_tomorrow_ - other.weight_tomorrow_) < 1e-6f;
}

bool StockInfo::operator!=(const StockInfo& other) const {
    return !(*this == other);
}

} // namespace atlas