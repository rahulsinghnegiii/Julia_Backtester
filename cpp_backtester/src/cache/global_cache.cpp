#include "global_cache.h"
#include <filesystem>
#include <fstream>
#include <sstream>
#include <iostream>
#include <iomanip>
#include <ctime>

namespace atlas {

GlobalCache& GlobalCache::instance() {
    static GlobalCache instance;
    return instance;
}

bool GlobalCache::cache_flow_data(const std::string& hash, const std::string& end_date, 
                                 const std::unordered_map<std::string, nlohmann::json>& flow_data) {
    try {
        std::string key = generate_flow_key(hash, end_date);
        flow_cache_[key] = FlowCacheEntry(flow_data);
        
        // Also save to file for persistence
        std::string cache_dir = "./Cache/" + hash;
        if (!create_cache_directory(cache_dir)) {
            return false;
        }
        
        std::string file_path = cache_dir + "/" + end_date + "-flow.json";
        nlohmann::json json_data(flow_data);
        
        return write_json_to_file(file_path, json_data);
        
    } catch (const std::exception& e) {
        std::cerr << "Failed to cache flow data: " << e.what() << std::endl;
        return false;
    }
}

std::unique_ptr<std::unordered_map<std::string, nlohmann::json>> GlobalCache::get_cached_flow_data(
    const std::string& hash, const std::string& end_date) {
    
    try {
        // Try memory cache first
        std::string key = generate_flow_key(hash, end_date);
        auto cache_it = flow_cache_.find(key);
        if (cache_it != flow_cache_.end()) {
            return std::make_unique<std::unordered_map<std::string, nlohmann::json>>(cache_it->second.flow_data);
        }
        
        // Try file cache
        std::string cache_dir = "./Cache/" + hash;
        std::string file_path = cache_dir + "/" + end_date + "-flow.json";
        
        if (std::filesystem::exists(file_path)) {
            auto json_data = read_json_from_file(file_path);
            if (json_data) {
                auto flow_data = std::make_unique<std::unordered_map<std::string, nlohmann::json>>();
                for (auto& [key, value] : json_data->items()) {
                    (*flow_data)[key] = value;
                }
                
                // Cache in memory for future use
                flow_cache_[key] = FlowCacheEntry(*flow_data);
                
                return flow_data;
            }
        }
        
        return nullptr;
        
    } catch (const std::exception& e) {
        std::cerr << "Failed to get cached flow data: " << e.what() << std::endl;
        return nullptr;
    }
}

bool GlobalCache::cache_results(const std::string& hash, 
                               const std::unordered_map<std::string, std::vector<float>>& response) {
    try {
        results_cache_[hash] = ResultsCacheEntry(response);
        
        // Also save to file for persistence
        std::string cache_dir = "./Cache/" + hash;
        if (!create_cache_directory(cache_dir)) {
            return false;
        }
        
        std::string file_path = cache_dir + "/" + hash + ".json";
        
        // Convert response to JSON
        nlohmann::json json_response;
        for (const auto& [key, values] : response) {
            json_response[key] = values;
        }
        
        return write_json_to_file(file_path, json_response);
        
    } catch (const std::exception& e) {
        std::cerr << "Failed to cache results: " << e.what() << std::endl;
        return false;
    }
}

std::unique_ptr<std::unordered_map<std::string, std::vector<float>>> GlobalCache::get_cached_results(
    const std::string& hash) {
    
    try {
        // Try memory cache first
        auto cache_it = results_cache_.find(hash);
        if (cache_it != results_cache_.end()) {
            return std::make_unique<std::unordered_map<std::string, std::vector<float>>>(cache_it->second.data);
        }
        
        // Try file cache
        std::string cache_dir = "./Cache/" + hash;
        std::string file_path = cache_dir + "/" + hash + ".json";
        
        if (std::filesystem::exists(file_path)) {
            auto json_data = read_json_from_file(file_path);
            if (json_data) {
                auto results = std::make_unique<std::unordered_map<std::string, std::vector<float>>>();
                for (auto& [key, value] : json_data->items()) {
                    if (value.is_array()) {
                        std::vector<float> float_vector;
                        for (auto& item : value) {
                            if (item.is_number()) {
                                float_vector.push_back(item.get<float>());
                            }
                        }
                        (*results)[key] = float_vector;
                    }
                }
                
                // Cache in memory for future use
                results_cache_[hash] = ResultsCacheEntry(*results);
                
                return results;
            }
        }
        
        return nullptr;
        
    } catch (const std::exception& e) {
        std::cerr << "Failed to get cached results: " << e.what() << std::endl;
        return nullptr;
    }
}

bool GlobalCache::cache_data(const std::string& hash, 
                            const std::unordered_map<std::string, std::vector<float>>& response,
                            const std::string& end_date,
                            const std::unordered_map<std::string, nlohmann::json>& flow_data) {
    bool results_cached = cache_results(hash, response);
    bool flow_cached = cache_flow_data(hash, end_date, flow_data);
    
    return results_cached && flow_cached;
}

GlobalCache::CacheDataResult GlobalCache::get_cached_data(const std::string& hash, 
                                                          const std::string& end_date, 
                                                          bool live_data) {
    CacheDataResult result;
    result.cached_response = nullptr;
    result.uncalculated_days = 0;
    result.cache_present = false;
    
    try {
        auto cached_response = get_cached_results(hash);
        if (!cached_response) {
            return result;
        }
        
        // Check if we have dates in the cached response
        auto dates_it = cached_response->find("dates");
        if (dates_it == cached_response->end() || dates_it->second.empty()) {
            return result;
        }
        
        // Get the last cached date (assuming dates are stored as float representations)
        // In a real implementation, this would need proper date parsing
        std::string last_cached_date_str = ""; // Placeholder - would extract from dates vector
        
        if (is_date_greater_equal(last_cached_date_str, end_date)) {
            result.cached_response = std::move(cached_response);
            result.cache_present = true;
            return result;
        }
        
        // Calculate uncalculated trading days
        result.uncalculated_days = get_trading_days("SPY", last_cached_date_str, end_date, live_data);
        if (result.uncalculated_days == 0) {
            result.cached_response = std::move(cached_response);
            result.cache_present = true;
        } else {
            result.cached_response = std::move(cached_response);
            result.cache_present = false;
        }
        
        return result;
        
    } catch (const std::exception& e) {
        std::cerr << "Failed to get cached data: " << e.what() << std::endl;
        return result;
    }
}

void GlobalCache::clear_cache() {
    flow_cache_.clear();
    results_cache_.clear();
}

void GlobalCache::clear_expired_entries(std::chrono::seconds max_age) {
    auto now = std::chrono::system_clock::now();
    
    // Clear expired flow cache entries
    for (auto it = flow_cache_.begin(); it != flow_cache_.end();) {
        if (now - it->second.timestamp > max_age) {
            it = flow_cache_.erase(it);
        } else {
            ++it;
        }
    }
    
    // Clear expired results cache entries
    for (auto it = results_cache_.begin(); it != results_cache_.end();) {
        if (now - it->second.timestamp > max_age) {
            it = results_cache_.erase(it);
        } else {
            ++it;
        }
    }
}

size_t GlobalCache::get_cache_size() const {
    return flow_cache_.size() + results_cache_.size();
}

bool GlobalCache::save_cache_to_file(const std::string& cache_dir) {
    try {
        if (!create_cache_directory(cache_dir)) {
            return false;
        }
        
        // Save flow cache
        nlohmann::json flow_cache_json;
        for (const auto& [key, entry] : flow_cache_) {
            flow_cache_json[key] = entry.flow_data;
        }
        
        std::string flow_cache_file = cache_dir + "/flow_cache.json";
        if (!write_json_to_file(flow_cache_file, flow_cache_json)) {
            return false;
        }
        
        // Save results cache
        nlohmann::json results_cache_json;
        for (const auto& [key, entry] : results_cache_) {
            results_cache_json[key] = entry.data;
        }
        
        std::string results_cache_file = cache_dir + "/results_cache.json";
        return write_json_to_file(results_cache_file, results_cache_json);
        
    } catch (const std::exception& e) {
        std::cerr << "Failed to save cache to file: " << e.what() << std::endl;
        return false;
    }
}

bool GlobalCache::load_cache_from_file(const std::string& cache_dir) {
    try {
        // Load flow cache
        std::string flow_cache_file = cache_dir + "/flow_cache.json";
        if (std::filesystem::exists(flow_cache_file)) {
            auto flow_json = read_json_from_file(flow_cache_file);
            if (flow_json) {
                for (auto& [key, value] : flow_json->items()) {
                    std::unordered_map<std::string, nlohmann::json> flow_data;
                    for (auto& [inner_key, inner_value] : value.items()) {
                        flow_data[inner_key] = inner_value;
                    }
                    flow_cache_[key] = FlowCacheEntry(flow_data);
                }
            }
        }
        
        // Load results cache
        std::string results_cache_file = cache_dir + "/results_cache.json";
        if (std::filesystem::exists(results_cache_file)) {
            auto results_json = read_json_from_file(results_cache_file);
            if (results_json) {
                for (auto& [key, value] : results_json->items()) {
                    std::unordered_map<std::string, std::vector<float>> results_data;
                    for (auto& [inner_key, inner_value] : value.items()) {
                        if (inner_value.is_array()) {
                            std::vector<float> float_vector;
                            for (auto& item : inner_value) {
                                if (item.is_number()) {
                                    float_vector.push_back(item.get<float>());
                                }
                            }
                            results_data[inner_key] = float_vector;
                        }
                    }
                    results_cache_[key] = ResultsCacheEntry(results_data);
                }
            }
        }
        
        return true;
        
    } catch (const std::exception& e) {
        std::cerr << "Failed to load cache from file: " << e.what() << std::endl;
        return false;
    }
}

// Private helper methods

std::string GlobalCache::generate_flow_key(const std::string& hash, const std::string& end_date) const {
    return hash + "_" + end_date + "_flow";
}

bool GlobalCache::create_cache_directory(const std::string& path) const {
    try {
        std::filesystem::create_directories(path);
        return true;
    } catch (const std::exception& e) {
        std::cerr << "Failed to create cache directory: " << path << " - " << e.what() << std::endl;
        return false;
    }
}

std::string GlobalCache::get_cache_file_path(const std::string& hash, const std::string& end_date, 
                                           const std::string& suffix) const {
    return "./Cache/" + hash + "/" + end_date + suffix;
}

bool GlobalCache::write_json_to_file(const std::string& file_path, const nlohmann::json& data) const {
    try {
        std::ofstream file(file_path);
        if (!file.is_open()) {
            return false;
        }
        
        file << data.dump(4); // Pretty print with 4 spaces
        file.close();
        
        return true;
        
    } catch (const std::exception& e) {
        std::cerr << "Failed to write JSON to file: " << file_path << " - " << e.what() << std::endl;
        return false;
    }
}

std::unique_ptr<nlohmann::json> GlobalCache::read_json_from_file(const std::string& file_path) const {
    try {
        std::ifstream file(file_path);
        if (!file.is_open()) {
            return nullptr;
        }
        
        nlohmann::json data;
        file >> data;
        file.close();
        
        return std::make_unique<nlohmann::json>(std::move(data));
        
    } catch (const std::exception& e) {
        std::cerr << "Failed to read JSON from file: " << file_path << " - " << e.what() << std::endl;
        return nullptr;
    }
}

int GlobalCache::get_trading_days(const std::string& symbol, const std::string& start_date, 
                                 const std::string& end_date, bool live_data) const {
    // Placeholder implementation - in a real system, this would:
    // 1. Parse the dates
    // 2. Query a market calendar or data provider
    // 3. Count business days excluding holidays
    // 4. Account for live_data flag
    
    // For now, return a simple approximation
    // This would need proper date parsing and market calendar integration
    return 5; // Placeholder value
}

bool GlobalCache::is_date_greater_equal(const std::string& date1, const std::string& date2) const {
    // Placeholder implementation - in a real system, this would:
    // 1. Parse both date strings (e.g., "2024-11-25")
    // 2. Compare them properly
    
    // For now, use string comparison (works for ISO format YYYY-MM-DD)
    return date1 >= date2;
}

} // namespace atlas