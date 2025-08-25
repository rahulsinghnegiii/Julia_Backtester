#include \"types.h\"

namespace atlas {

CacheData::CacheData(std::unordered_map<std::string, std::vector<float>> response,
                     int uncalculated_days, bool cache_present)
    : response_(std::move(response)), 
      uncalculated_days_(uncalculated_days),
      cache_present_(cache_present) {}

void CacheData::set_response(const std::unordered_map<std::string, std::vector<float>>& response) {
    response_ = response;
}

} // namespace atlas