#include "subtree_cache.h"
#include <filesystem>
#include <fstream>
#include <sstream>
#include <iostream>
#include <algorithm>
#include <cstring>
#include <regex>

namespace atlas {

// PortfolioEntry implementation
PortfolioEntry::PortfolioEntry(uint32_t d, const std::string& t, float w) 
    : date(d), weight(w) {
    set_ticker(t);
}

std::string PortfolioEntry::get_ticker() const {
    // Find the null terminator or end of array
    size_t len = 0;
    while (len < ticker.size() && ticker[len] != '\0') {
        len++;
    }
    return std::string(ticker.data(), len);
}

void PortfolioEntry::set_ticker(const std::string& ticker_str) {
    ticker.fill('\0'); // Clear the array
    size_t copy_len = std::min(ticker_str.length(), ticker.size() - 1);
    std::memcpy(ticker.data(), ticker_str.c_str(), copy_len);
}

// SubtreeCache implementation
SubtreeCache::SubtreeCache() : cache_dir_("./SubtreeCache") {
    create_cache_directory();
}

bool SubtreeCache::write_subtree_portfolio_mmap(
    const std::vector<std::string>& date_range,
    const std::string& end_date,
    const std::string& hash,
    int common_data_span,
    const std::vector<DayData>& portfolio_history,
    bool live_execution) {
    
    try {
        std::string mmap_path = get_mmap_file_path(hash);
        uint32_t end_date_int = date_to_int(end_date);
        
        // Convert portfolio data to entries
        auto portfolio_entries = convert_to_portfolio_entries(
            date_range, end_date, common_data_span, portfolio_history, live_execution);
        
        if (portfolio_entries.empty()) {
            std::cerr << "No data to write for hash " << hash << std::endl;
            return false;
        }
        
        // Write entries to file
        bool success = write_entries_to_file(mmap_path, portfolio_entries);
        
        if (success) {
            std::cout << "Saved memory-mapped data for node with hash " << hash 
                     << " up to " << end_date << std::endl;
        }
        
        return success;
        
    } catch (const std::exception& e) {
        std::cerr << "Failed to write subtree portfolio: " << e.what() << std::endl;
        return false;
    }
}

bool SubtreeCache::append_subtree_portfolio_mmap(
    const std::vector<std::string>& date_range,
    const std::string& end_date,
    const std::string& hash,
    int common_data_span,
    const std::vector<DayData>& portfolio_history,
    bool live_execution) {
    
    try {
        std::string mmap_path = get_mmap_file_path(hash);
        uint32_t end_date_int = date_to_int(end_date);
        
        // Read existing data to find last date
        uint32_t last_existing_date = 0;
        if (std::filesystem::exists(mmap_path)) {
            auto existing_entries = read_entries_from_file(mmap_path, end_date);
            if (existing_entries && !existing_entries->empty()) {
                last_existing_date = std::max_element(existing_entries->begin(), existing_entries->end(),
                    [](const PortfolioEntry& a, const PortfolioEntry& b) {
                        return a.date < b.date;
                    })->date;
            }
        }
        
        // Filter new data
        std::vector<int> new_data_indices;
        for (int i = 0; i < common_data_span; ++i) {
            int date_index = date_range.size() - common_data_span + i;
            if (date_index >= 0 && date_index < static_cast<int>(date_range.size())) {
                uint32_t current_date_int = date_to_int(date_range[date_index]);
                if (current_date_int > last_existing_date) {
                    new_data_indices.push_back(i);
                }
            }
        }
        
        if (new_data_indices.empty()) {
            std::cout << "No new data to append for node with hash " << hash << std::endl;
            return true;
        }
        
        // Create new entries for the filtered data
        std::vector<PortfolioEntry> new_entries;
        for (int i : new_data_indices) {
            int date_index = date_range.size() - common_data_span + i;
            int portfolio_index = portfolio_history.size() - common_data_span + i;
            
            if (date_index >= 0 && date_index < static_cast<int>(date_range.size()) &&
                portfolio_index >= 0 && portfolio_index < static_cast<int>(portfolio_history.size())) {
                
                uint32_t current_date_int = date_to_int(date_range[date_index]);
                
                if (live_execution && current_date_int == end_date_int) {
                    continue;
                }
                
                const auto& day_data = portfolio_history[portfolio_index];
                for (const auto& stock : day_data.stock_list) {
                    new_entries.emplace_back(current_date_int, stock.ticker, stock.weight_tomorrow);
                }
            }
        }
        
        if (new_entries.empty()) {
            return true;
        }
        
        // Append new entries to file
        bool success = append_entries_to_file(mmap_path, new_entries);
        
        if (success) {
            std::cout << "Appended memory-mapped data for node with hash " << hash 
                     << " up to " << end_date << std::endl;
        }
        
        return success;
        
    } catch (const std::exception& e) {
        std::cerr << "Failed to append subtree portfolio: " << e.what() << std::endl;
        return false;
    }
}

std::pair<std::unique_ptr<std::vector<DayData>>, std::string> 
SubtreeCache::read_subtree_portfolio_mmap(const std::string& hash, const std::string& end_date) {
    
    try {
        std::string mmap_path = get_mmap_file_path(hash);
        
        if (!std::filesystem::exists(mmap_path)) {
            return {nullptr, ""};
        }
        
        auto entries = read_entries_from_file(mmap_path, end_date);
        if (!entries || entries->empty()) {
            return {nullptr, ""};
        }
        
        // Convert entries back to DayData
        auto portfolio_history = std::make_unique<std::vector<DayData>>(
            convert_from_portfolio_entries(*entries));
        
        // Find the last date
        uint32_t last_date_int = std::max_element(entries->begin(), entries->end(),
            [](const PortfolioEntry& a, const PortfolioEntry& b) {
                return a.date < b.date;
            })->date;
        
        std::string last_date = int_to_date(last_date_int);
        
        return {std::move(portfolio_history), last_date};
        
    } catch (const std::exception& e) {
        std::cerr << "Failed to read subtree portfolio: " << e.what() << std::endl;
        return {nullptr, ""};
    }
}

std::tuple<std::unique_ptr<std::vector<DayData>>, std::unique_ptr<std::vector<std::string>>, std::string>
SubtreeCache::read_subtree_portfolio_with_dates_mmap(const std::string& hash, const std::string& end_date) {
    
    try {
        std::string mmap_path = get_mmap_file_path(hash);
        
        if (!std::filesystem::exists(mmap_path)) {
            return {nullptr, nullptr, ""};
        }
        
        auto entries = read_entries_from_file(mmap_path, end_date);
        if (!entries || entries->empty()) {
            return {nullptr, nullptr, ""};
        }
        
        // Convert entries back to DayData
        auto portfolio_history = std::make_unique<std::vector<DayData>>(
            convert_from_portfolio_entries(*entries));
        
        // Extract unique dates
        std::set<uint32_t> unique_date_ints;
        for (const auto& entry : *entries) {
            unique_date_ints.insert(entry.date);
        }
        
        auto dates = std::make_unique<std::vector<std::string>>();
        for (uint32_t date_int : unique_date_ints) {
            dates->push_back(int_to_date(date_int));
        }
        
        // Find the last date
        uint32_t last_date_int = *unique_date_ints.rbegin();
        std::string last_date = int_to_date(last_date_int);
        
        return {std::move(portfolio_history), std::move(dates), last_date};
        
    } catch (const std::exception& e) {
        std::cerr << "Failed to read subtree portfolio with dates: " << e.what() << std::endl;
        return {nullptr, nullptr, ""};
    }
}

void SubtreeCache::set_portfolio_history(
    std::vector<DayData>& portfolio_history,
    const std::vector<DayData>& subtree_portfolio_history,
    const std::vector<bool>& active_mask,
    float node_weight,
    int common_data_span) {
    
    int min_length = std::min({
        static_cast<int>(active_mask.size()), 
        static_cast<int>(subtree_portfolio_history.size()), 
        common_data_span,
        static_cast<int>(portfolio_history.size())
    });
    
    for (int i = 0; i < min_length; ++i) {
        int reverse_index = active_mask.size() - i - 1;
        int subtree_index = subtree_portfolio_history.size() - i - 1;
        int portfolio_index = portfolio_history.size() - i - 1;
        
        if (reverse_index >= 0 && reverse_index < static_cast<int>(active_mask.size()) &&
            subtree_index >= 0 && subtree_index < static_cast<int>(subtree_portfolio_history.size()) &&
            portfolio_index >= 0 && portfolio_index < static_cast<int>(portfolio_history.size()) &&
            active_mask[reverse_index]) {
            
            const auto& subtree_day = subtree_portfolio_history[subtree_index];
            auto& portfolio_day = portfolio_history[portfolio_index];
            
            for (const auto& stock : subtree_day.stock_list) {
                StockInfo weighted_stock(stock.ticker, stock.weight_tomorrow * node_weight);
                portfolio_day.stock_list.push_back(weighted_stock);
            }
        }
    }
}

bool SubtreeCache::clear_cache(const std::string& hash) {
    try {
        std::string mmap_path = get_mmap_file_path(hash);
        std::string parquet_path = get_parquet_file_path(hash);
        
        bool success = true;
        
        if (std::filesystem::exists(mmap_path)) {
            success &= std::filesystem::remove(mmap_path);
        }
        
        if (std::filesystem::exists(parquet_path)) {
            success &= std::filesystem::remove(parquet_path);
        }
        
        return success;
        
    } catch (const std::exception& e) {
        std::cerr << "Failed to clear cache for hash " << hash << ": " << e.what() << std::endl;
        return false;
    }
}

bool SubtreeCache::clear_all_cache() {
    try {
        if (std::filesystem::exists(cache_dir_)) {
            std::filesystem::remove_all(cache_dir_);
            return create_cache_directory();
        }
        return true;
        
    } catch (const std::exception& e) {
        std::cerr << "Failed to clear all cache: " << e.what() << std::endl;
        return false;
    }
}

size_t SubtreeCache::get_cache_size(const std::string& hash) const {
    try {
        std::string mmap_path = get_mmap_file_path(hash);
        return calculate_file_size(mmap_path);
        
    } catch (const std::exception& e) {
        std::cerr << "Failed to get cache size for hash " << hash << ": " << e.what() << std::endl;
        return 0;
    }
}

void SubtreeCache::set_cache_directory(const std::string& cache_dir) {
    cache_dir_ = cache_dir;
    create_cache_directory();
}

// Private helper methods

uint32_t SubtreeCache::date_to_int(const std::string& date_str) const {
    // Parse date string in format "YYYY-MM-DD"
    std::regex date_regex(R"((\d{4})-(\d{2})-(\d{2}))");
    std::smatch matches;
    
    if (std::regex_match(date_str, matches, date_regex)) {
        uint32_t year = std::stoul(matches[1].str());
        uint32_t month = std::stoul(matches[2].str());
        uint32_t day = std::stoul(matches[3].str());
        
        return (year << 16) | (month << 8) | day;
    }
    
    throw SubtreeCacheError("Invalid date format: " + date_str);
}

std::string SubtreeCache::int_to_date(uint32_t date_int) const {
    uint32_t year = date_int >> 16;
    uint32_t month = (date_int >> 8) & 0xFF;
    uint32_t day = date_int & 0xFF;
    
    std::ostringstream oss;
    oss << std::setfill('0') << std::setw(4) << year << "-"
        << std::setfill('0') << std::setw(2) << month << "-"
        << std::setfill('0') << std::setw(2) << day;
    
    return oss.str();
}

std::string SubtreeCache::get_mmap_file_path(const std::string& hash) const {
    return cache_dir_ + "/" + hash + ".mmap";
}

std::string SubtreeCache::get_parquet_file_path(const std::string& hash) const {
    return cache_dir_ + "/" + hash + ".parquet";
}

bool SubtreeCache::create_cache_directory() const {
    try {
        std::filesystem::create_directories(cache_dir_);
        return true;
    } catch (const std::exception& e) {
        std::cerr << "Failed to create cache directory: " << cache_dir_ << " - " << e.what() << std::endl;
        return false;
    }
}

size_t SubtreeCache::calculate_file_size(const std::string& file_path) const {
    try {
        if (std::filesystem::exists(file_path)) {
            return std::filesystem::file_size(file_path);
        }
        return 0;
    } catch (const std::exception& e) {
        return 0;
    }
}

std::vector<PortfolioEntry> SubtreeCache::convert_to_portfolio_entries(
    const std::vector<std::string>& date_range,
    const std::string& end_date,
    int common_data_span,
    const std::vector<DayData>& portfolio_history,
    bool live_execution) const {
    
    std::vector<PortfolioEntry> entries;
    uint32_t end_date_int = date_to_int(end_date);
    
    // Pre-compute date integers
    std::vector<uint32_t> date_ints;
    for (int i = 0; i < common_data_span; ++i) {
        int date_index = date_range.size() - common_data_span + i;
        if (date_index >= 0 && date_index < static_cast<int>(date_range.size())) {
            date_ints.push_back(date_to_int(date_range[date_index]));
        }
    }
    
    for (int i = 0; i < common_data_span; ++i) {
        if (i >= static_cast<int>(date_ints.size())) continue;
        
        uint32_t current_date_int = date_ints[i];
        
        if (live_execution && current_date_int == end_date_int) {
            continue;
        }
        
        int portfolio_index = portfolio_history.size() - common_data_span + i;
        if (portfolio_index >= 0 && portfolio_index < static_cast<int>(portfolio_history.size())) {
            const auto& day_data = portfolio_history[portfolio_index];
            for (const auto& stock : day_data.stock_list) {
                entries.emplace_back(current_date_int, stock.ticker, stock.weight_tomorrow);
            }
        }
    }
    
    return entries;
}

std::vector<DayData> SubtreeCache::convert_from_portfolio_entries(
    const std::vector<PortfolioEntry>& entries) const {
    
    // Group entries by date
    std::map<uint32_t, std::vector<const PortfolioEntry*>> grouped_entries;
    for (const auto& entry : entries) {
        grouped_entries[entry.date].push_back(&entry);
    }
    
    std::vector<DayData> portfolio_history;
    portfolio_history.reserve(grouped_entries.size());
    
    for (const auto& [date_int, day_entries] : grouped_entries) {
        DayData day_data;
        day_data.stock_list.reserve(day_entries.size());
        
        for (const auto* entry : day_entries) {
            day_data.stock_list.emplace_back(entry->get_ticker(), entry->weight);
        }
        
        portfolio_history.push_back(std::move(day_data));
    }
    
    return portfolio_history;
}

bool SubtreeCache::write_entries_to_file(const std::string& file_path, const std::vector<PortfolioEntry>& entries) {
    try {
        std::ofstream file(file_path, std::ios::binary | std::ios::trunc);
        if (!file.is_open()) {
            return false;
        }
        
        file.write(reinterpret_cast<const char*>(entries.data()), 
                  entries.size() * sizeof(PortfolioEntry));
        
        file.close();
        return true;
        
    } catch (const std::exception& e) {
        std::cerr << "Failed to write entries to file: " << file_path << " - " << e.what() << std::endl;
        return false;
    }
}

bool SubtreeCache::append_entries_to_file(const std::string& file_path, const std::vector<PortfolioEntry>& entries) {
    try {
        std::ofstream file(file_path, std::ios::binary | std::ios::app);
        if (!file.is_open()) {
            return false;
        }
        
        file.write(reinterpret_cast<const char*>(entries.data()), 
                  entries.size() * sizeof(PortfolioEntry));
        
        file.close();
        return true;
        
    } catch (const std::exception& e) {
        std::cerr << "Failed to append entries to file: " << file_path << " - " << e.what() << std::endl;
        return false;
    }
}

std::unique_ptr<std::vector<PortfolioEntry>> SubtreeCache::read_entries_from_file(
    const std::string& file_path, const std::string& end_date) const {
    
    try {
        std::ifstream file(file_path, std::ios::binary);
        if (!file.is_open()) {
            return nullptr;
        }
        
        // Get file size
        file.seekg(0, std::ios::end);
        size_t file_size = file.tellg();
        file.seekg(0, std::ios::beg);
        
        size_t num_entries = file_size / sizeof(PortfolioEntry);
        if (num_entries == 0) {
            return nullptr;
        }
        
        auto entries = std::make_unique<std::vector<PortfolioEntry>>(num_entries);
        file.read(reinterpret_cast<char*>(entries->data()), file_size);
        file.close();
        
        // Filter by end date
        uint32_t end_date_int = date_to_int(end_date);
        entries->erase(
            std::remove_if(entries->begin(), entries->end(),
                [end_date_int](const PortfolioEntry& entry) {
                    return entry.date > end_date_int;
                }),
            entries->end()
        );
        
        if (entries->empty()) {
            return nullptr;
        }
        
        return entries;
        
    } catch (const std::exception& e) {
        std::cerr << "Failed to read entries from file: " << file_path << " - " << e.what() << std::endl;
        return nullptr;
    }
}

bool SubtreeCache::validate_portfolio_entry(const PortfolioEntry& entry) const {
    // Basic validation
    if (entry.date == 0) return false;
    if (entry.weight < 0.0f) return false;
    
    std::string ticker = entry.get_ticker();
    if (ticker.empty() || ticker.length() > 7) return false;
    
    return true;
}

bool SubtreeCache::validate_date_string(const std::string& date_str) const {
    std::regex date_regex(R"(\d{4}-\d{2}-\d{2})");
    return std::regex_match(date_str, date_regex);
}

} // namespace atlas