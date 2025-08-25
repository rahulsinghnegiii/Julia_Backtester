#include "stock_data_provider.h"
#include <filesystem>
#include <fstream>
#include <sstream>
#include <iostream>
#include <algorithm>
#include <cmath>
#include <regex>
#include <thread>
#include <iomanip>

namespace atlas {

// DatabaseManager implementation
DatabaseManager& DatabaseManager::instance() {
    static DatabaseManager instance;
    return instance;
}

bool DatabaseManager::initialize_connection_pool(int pool_size) {
    std::lock_guard<std::mutex> lock(connection_mutex_);
    try {
        pool_size_ = pool_size;
        connection_pool_.clear();
        connection_pool_.reserve(pool_size);
        
        // Pre-create connections (mock implementation)
        for (int i = 0; i < pool_size; ++i) {
            connection_pool_.push_back(create_connection());
        }
        
        std::cout << "Initialized connection pool with size " << pool_size << std::endl;
        return true;
        
    } catch (const std::exception& e) {
        std::cerr << "Error initializing connection pool: " << e.what() << std::endl;
        return false;
    }
}

std::shared_ptr<void> DatabaseManager::get_thread_connection() {
    try {
        return get_available_connection();
    } catch (const std::exception& e) {
        std::cerr << "Error in get_thread_connection: " << e.what() << std::endl;
        throw StockDataError("Failed to get database connection: " + std::string(e.what()));
    }
}

std::vector<std::unordered_map<std::string, std::string>> DatabaseManager::execute_query(
    const std::string& query, int max_retries) {
    
    auto connection = get_thread_connection();
    int base_wait_ms = 500;
    
    for (int attempt = 1; attempt <= max_retries; ++attempt) {
        try {
            // Mock query execution - in real implementation, this would use DuckDB
            std::vector<std::unordered_map<std::string, std::string>> results;
            
            // Simulate query execution
            if (query.find("SELECT") != std::string::npos) {
                // Mock result for demonstration
                std::unordered_map<std::string, std::string> row;
                row["date"] = "2024-11-25";
                row["adjusted_close"] = "450.0";
                row["volume"] = "1000000";
                results.push_back(row);
            }
            
            return results;
            
        } catch (const std::exception& e) {
            if (attempt == max_retries) {
                std::cerr << "Error executing DuckDB query after " << max_retries 
                         << " attempts: " << e.what() << std::endl;
                throw StockDataError("Query execution failed: " + std::string(e.what()));
            }
            
            int wait_time = base_wait_ms * (1 << (attempt - 1)); // Exponential backoff
            std::cerr << "Attempt " << attempt << " failed. Retrying in " 
                     << wait_time << "ms..." << std::endl;
            std::this_thread::sleep_for(std::chrono::milliseconds(wait_time));
        }
    }
    
    return {};
}

bool DatabaseManager::check_connection_health(std::shared_ptr<void> connection) {
    if (!connection) {
        return false;
    }
    
    try {
        // Mock health check - in real implementation, would execute "SELECT 1"
        return true;
    } catch (const std::exception&) {
        return false;
    }
}

void DatabaseManager::cleanup_connections() {
    std::lock_guard<std::mutex> lock(connection_mutex_);
    try {
        connection_pool_.clear();
        std::cout << "Cleaned up all database connections" << std::endl;
    } catch (const std::exception& e) {
        std::cerr << "Error cleaning up connections: " << e.what() << std::endl;
    }
}

std::shared_ptr<void> DatabaseManager::create_connection() {
    // Mock connection creation - in real implementation, would create DuckDB connection
    return std::shared_ptr<void>(new int(42), [](void* p) { delete static_cast<int*>(p); });
}

std::shared_ptr<void> DatabaseManager::get_available_connection() {
    std::lock_guard<std::mutex> lock(connection_mutex_);
    
    // Find a healthy connection
    for (auto& conn : connection_pool_) {
        if (conn && check_connection_health(conn)) {
            return conn;
        }
    }
    
    // If no healthy connection found, create a new one
    for (auto& conn : connection_pool_) {
        if (!conn) {
            conn = create_connection();
            return conn;
        }
    }
    
    // If pool is full, replace the first connection
    if (!connection_pool_.empty()) {
        connection_pool_[0] = create_connection();
        return connection_pool_[0];
    }
    
    // If pool is empty, create a new connection
    auto new_conn = create_connection();
    connection_pool_.push_back(new_conn);
    return new_conn;
}

// StockDataProvider implementation
StockDataProvider::StockDataProvider(const std::string& data_root) 
    : data_root_(data_root), db_manager_(DatabaseManager::instance()) {
    
    if (!std::filesystem::exists(data_root_)) {
        std::filesystem::create_directories(data_root_);
    }
    
    db_manager_.initialize_connection_pool();
}

std::vector<StockDataRecord> StockDataProvider::get_historical_data(
    const std::string& ticker, int period, const std::string& end_date) {
    
    try {
        std::string mapped_ticker = map_ticker(ticker);
        std::string cache_key = mapped_ticker + "_" + std::to_string(period) + "_" + end_date;
        
        // Check cache first
        auto cached_data = get_cached_data(cache_key);
        if (cached_data) {
            return *cached_data;
        }
        
        std::string file_path = get_data_file_path(mapped_ticker);
        
        if (!std::filesystem::exists(file_path)) {
            throw StockDataError("Stock data file not found for symbol " + mapped_ticker + 
                                " at path: " + file_path);
        }
        
        // Build SQL query for DuckDB parquet reading
        std::ostringstream query_ss;
        query_ss << "WITH latest_records AS ("
                 << "    SELECT adjusted_close, date"
                 << "    FROM read_parquet('" << file_path << "')"
                 << "    WHERE date <= '" << end_date << "'"
                 << "    ORDER BY date DESC"
                 << "    LIMIT " << period
                 << ") "
                 << "SELECT adjusted_close, date"
                 << " FROM latest_records"
                 << " ORDER BY date ASC";
        
        auto results = execute_parquet_query(query_ss.str());
        
        // Update cache
        update_cache(cache_key, results);
        
        return results;
        
    } catch (const std::exception& e) {
        throw StockDataError("Error in get_historical_data: " + std::string(e.what()));
    }
}

std::vector<StockDataRecord> StockDataProvider::get_historical_data_range(
    const std::string& ticker, const std::string& start_date, const std::string& end_date) {
    
    try {
        std::string mapped_ticker = map_ticker(ticker);
        std::string cache_key = mapped_ticker + "_range_" + start_date + "_" + end_date;
        
        // Check cache first
        auto cached_data = get_cached_data(cache_key);
        if (cached_data) {
            return *cached_data;
        }
        
        std::string file_path = get_data_file_path(mapped_ticker);
        
        if (!std::filesystem::exists(file_path)) {
            throw StockDataError("Stock data file not found for symbol " + mapped_ticker);
        }
        
        // Build SQL query
        std::ostringstream query_ss;
        query_ss << "SELECT adjusted_close, date"
                 << " FROM read_parquet('" << file_path << "')"
                 << " WHERE date >= '" << start_date << "' AND date <= '" << end_date << "'"
                 << " ORDER BY date ASC";
        
        auto results = execute_parquet_query(query_ss.str());
        
        // Update cache
        update_cache(cache_key, results);
        
        return results;
        
    } catch (const std::exception& e) {
        throw StockDataError("Error in get_historical_data_range: " + std::string(e.what()));
    }
}

std::vector<StockDataRecord> StockDataProvider::get_historical_data_until_end_date(
    const std::string& ticker, const std::string& end_date, bool live_data) {
    
    try {
        std::string mapped_ticker = map_ticker(ticker);
        std::string cache_key = mapped_ticker + "_until_" + end_date + "_" + (live_data ? "live" : "hist");
        
        // Check cache first
        auto cached_data = get_cached_data(cache_key);
        if (cached_data && !live_data) { // Don't use cache for live data
            return *cached_data;
        }
        
        std::string file_path = get_data_file_path(mapped_ticker);
        
        if (!std::filesystem::exists(file_path)) {
            throw StockDataError("Stock data file not found for symbol " + mapped_ticker);
        }
        
        // Build SQL query
        std::ostringstream query_ss;
        query_ss << "SELECT adjusted_close, date"
                 << " FROM read_parquet('" << file_path << "')"
                 << " WHERE date <= '" << end_date << "'"
                 << " ORDER BY date ASC";
        
        auto results = execute_parquet_query(query_ss.str());
        
        if (live_data) {
            auto live_data_record = get_live_data(mapped_ticker);
            results = combine_data(results, live_data_record);
        }
        
        // Update cache
        update_cache(cache_key, results);
        
        return results;
        
    } catch (const std::exception& e) {
        throw StockDataError("Error in get_historical_data_until_end_date: " + std::string(e.what()));
    }
}

std::optional<LiveDataRecord> StockDataProvider::get_live_data(const std::string& ticker) {
    try {
        std::string mapped_ticker = map_ticker(ticker);
        
        // Check live data cache first
        auto cached_live_data = get_cached_live_data(mapped_ticker);
        if (cached_live_data) {
            return cached_live_data;
        }
        
        auto live_data = get_live_data_api_call(mapped_ticker);
        
        if (live_data) {
            update_live_cache(mapped_ticker, *live_data);
        }
        
        return live_data;
        
    } catch (const std::exception& e) {
        std::cerr << "Error in get_live_data for symbol " << ticker << ": " << e.what() << std::endl;
        return std::nullopt;
    }
}

std::vector<StockDataRecord> StockDataProvider::get_market_cap_data(
    const std::string& ticker, const std::string& date, int period) {
    
    try {
        std::string mapped_ticker = map_ticker(ticker);
        std::string file_path = get_market_cap_file_path(mapped_ticker);
        
        if (!std::filesystem::exists(file_path)) {
            throw StockDataError("Market cap data file not found for symbol " + mapped_ticker);
        }
        
        // Build SQL query
        std::ostringstream query_ss;
        query_ss << "SELECT marketCap, date"
                 << " FROM read_parquet('" << file_path << "')"
                 << " WHERE date <= '" << date << "'"
                 << " ORDER BY date DESC"
                 << " LIMIT " << period;
        
        auto query_results = db_manager_.execute_query(query_ss.str());
        
        std::vector<StockDataRecord> results;
        for (const auto& row : query_results) {
            StockDataRecord record;
            record.date = row.at("date");
            record.market_cap = std::stof(row.at("marketCap"));
            results.push_back(record);
        }
        
        return results;
        
    } catch (const std::exception& e) {
        throw StockDataError("Error in get_market_cap_data: " + std::string(e.what()));
    }
}

std::vector<StockDataRecord> StockDataProvider::get_stock_data_dataframe(
    const std::string& ticker, int period, const std::string& end_date, bool live_data) {
    
    try {
        std::string mapped_ticker = map_ticker(ticker);
        
        if (live_data) {
            if (period == 1) {
                auto live_data_record = get_live_data(mapped_ticker);
                if (live_data_record) {
                    std::vector<StockDataRecord> result;
                    StockDataRecord record;
                    record.date = live_data_record->timestamp;
                    record.adjusted_close = live_data_record->current_price;
                    result.push_back(record);
                    return result;
                }
            } else {
                // Get historical data and combine with live data
                auto historical_data = get_historical_data(mapped_ticker, period - 1, end_date);
                auto live_data_record = get_live_data(mapped_ticker);
                return combine_data(historical_data, live_data_record);
            }
        }
        
        return get_historical_data(mapped_ticker, period, end_date);
        
    } catch (const std::exception& e) {
        throw StockDataError("Error in get_stock_data_dataframe: " + std::string(e.what()));
    }
}

std::vector<float> StockDataProvider::calculate_delta_percentages(const std::vector<float>& values) {
    try {
        if (values.empty()) {
            return {};
        }
        
        std::vector<float> deltas;
        deltas.reserve(values.size());
        deltas.push_back(0.0f); // First value has no delta
        
        for (size_t i = 1; i < values.size(); ++i) {
            if (values[i-1] != 0.0f) {
                float delta = (values[i] - values[i-1]) / values[i-1] * 100.0f;
                deltas.push_back(delta);
            } else {
                deltas.push_back(0.0f);
            }
        }
        
        return deltas;
        
    } catch (const std::exception& e) {
        throw StockDataError("Error in calculate_delta_percentages: " + std::string(e.what()));
    }
}

// Private helper methods

std::string StockDataProvider::map_ticker(const std::string& ticker) const {
    // Implement ticker mapping logic (e.g., FNGU to FNGA)
    // For now, just return the original ticker
    std::string mapped = ticker;
    
    // Replace dots with dashes for file system compatibility
    std::replace(mapped.begin(), mapped.end(), '.', '-');
    
    return mapped;
}

std::string StockDataProvider::get_data_file_path(const std::string& ticker) const {
    return data_root_ + "/" + ticker + ".parquet";
}

std::string StockDataProvider::get_market_cap_file_path(const std::string& ticker) const {
    return data_root_ + "/market_cap/" + ticker + ".parquet";
}

std::vector<StockDataRecord> StockDataProvider::execute_parquet_query(const std::string& query) {
    try {
        auto query_results = db_manager_.execute_query(query);
        
        std::vector<StockDataRecord> results;
        for (const auto& row : query_results) {
            StockDataRecord record;
            record.date = row.at("date");
            record.adjusted_close = std::stof(row.at("adjusted_close"));
            
            if (row.find("volume") != row.end()) {
                record.volume = std::stof(row.at("volume"));
            }
            
            results.push_back(record);
        }
        
        return results;
        
    } catch (const std::exception& e) {
        throw StockDataError("Error executing parquet query: " + std::string(e.what()));
    }
}

std::optional<LiveDataRecord> StockDataProvider::get_live_data_api_call(const std::string& ticker) {
    try {
        // Mock implementation - in real system, would make HTTP API call
        // For now, generate mock live data
        LiveDataRecord live_data;
        live_data.symbol = ticker;
        live_data.current_price = 450.0f + (std::rand() % 100 - 50) * 0.1f; // Mock price variation
        live_data.change = (std::rand() % 100 - 50) * 0.1f;
        live_data.change_percent = live_data.change / live_data.current_price * 100.0f;
        
        // Current timestamp
        auto now = std::chrono::system_clock::now();
        auto time_t = std::chrono::system_clock::to_time_t(now);
        std::ostringstream timestamp_ss;
        timestamp_ss << std::put_time(std::gmtime(&time_t), "%Y-%m-%d %H:%M:%S");
        live_data.timestamp = timestamp_ss.str();
        
        return live_data;
        
    } catch (const std::exception& e) {
        std::cerr << "Error in live data API call for " << ticker << ": " << e.what() << std::endl;
        return std::nullopt;
    }
}

std::vector<StockDataRecord> StockDataProvider::combine_data(
    const std::vector<StockDataRecord>& historical_data, 
    const std::optional<LiveDataRecord>& live_data) {
    
    std::vector<StockDataRecord> combined = historical_data;
    
    if (live_data) {
        StockDataRecord live_record;
        live_record.date = live_data->timestamp;
        live_record.adjusted_close = live_data->current_price;
        combined.push_back(live_record);
    }
    
    return combined;
}

bool StockDataProvider::is_cache_valid(const std::string& cache_key) const {
    std::lock_guard<std::mutex> lock(cache_mutex_);
    
    auto it = cache_timestamps_.find(cache_key);
    if (it == cache_timestamps_.end()) {
        return false;
    }
    
    auto now = std::chrono::steady_clock::now();
    return (now - it->second) < CACHE_TIMEOUT;
}

void StockDataProvider::update_cache(const std::string& cache_key, 
                                    const std::vector<StockDataRecord>& data) {
    std::lock_guard<std::mutex> lock(cache_mutex_);
    data_cache_[cache_key] = data;
    cache_timestamps_[cache_key] = std::chrono::steady_clock::now();
}

void StockDataProvider::update_live_cache(const std::string& ticker, 
                                         const LiveDataRecord& live_data) {
    std::lock_guard<std::mutex> lock(cache_mutex_);
    live_data_cache_[ticker] = live_data;
    cache_timestamps_[ticker + "_live"] = std::chrono::steady_clock::now();
}

std::optional<std::vector<StockDataRecord>> StockDataProvider::get_cached_data(
    const std::string& cache_key) {
    
    if (!is_cache_valid(cache_key)) {
        return std::nullopt;
    }
    
    std::lock_guard<std::mutex> lock(cache_mutex_);
    auto it = data_cache_.find(cache_key);
    if (it != data_cache_.end()) {
        return it->second;
    }
    
    return std::nullopt;
}

std::optional<LiveDataRecord> StockDataProvider::get_cached_live_data(const std::string& ticker) {
    std::string cache_key = ticker + "_live";
    
    if (!is_cache_valid(cache_key)) {
        return std::nullopt;
    }
    
    std::lock_guard<std::mutex> lock(cache_mutex_);
    auto it = live_data_cache_.find(ticker);
    if (it != live_data_cache_.end()) {
        return it->second;
    }
    
    return std::nullopt;
}

// MockStockDataProvider implementation
std::vector<StockDataRecord> MockStockDataProvider::get_historical_data(
    const std::string& ticker, int period, const std::string& end_date) {
    
    return generate_mock_data(ticker, period, end_date);
}

std::vector<StockDataRecord> MockStockDataProvider::get_historical_data_range(
    const std::string& ticker, const std::string& start_date, const std::string& end_date) {
    
    // Simple mock implementation - generate 30 days of data
    return generate_mock_data(ticker, 30, end_date);
}

std::optional<LiveDataRecord> MockStockDataProvider::get_live_data(const std::string& ticker) {
    LiveDataRecord live_data;
    live_data.symbol = ticker;
    live_data.current_price = get_base_price(ticker);
    live_data.change = (std::rand() % 100 - 50) * 0.1f;
    live_data.change_percent = live_data.change / live_data.current_price * 100.0f;
    live_data.timestamp = "2024-11-25 10:30:00";
    
    return live_data;
}

std::vector<StockDataRecord> MockStockDataProvider::get_market_cap_data(
    const std::string& ticker, const std::string& date, int period) {
    
    std::vector<StockDataRecord> results;
    float base_market_cap = 1000000.0f; // 1B base market cap
    
    if (ticker == "AAPL") base_market_cap = 3000000.0f;
    else if (ticker == "MSFT") base_market_cap = 2800000.0f;
    else if (ticker == "SPY") base_market_cap = 400000.0f;
    
    for (int i = 0; i < period; ++i) {
        StockDataRecord record;
        record.date = date; // Simplified - would calculate actual dates
        record.market_cap = base_market_cap * (1.0f + (std::rand() % 100 - 50) * 0.001f);
        results.push_back(record);
    }
    
    return results;
}

std::vector<StockDataRecord> MockStockDataProvider::generate_mock_data(
    const std::string& ticker, int period, const std::string& end_date) {
    
    std::vector<StockDataRecord> results;
    float base_price = get_base_price(ticker);
    
    for (int i = 0; i < period; ++i) {
        StockDataRecord record;
        record.date = end_date; // Simplified - would calculate actual dates
        
        // Generate price with some volatility
        float variation = (std::sin(i * 0.1f) + std::cos(i * 0.05f)) * 5.0f;
        float trend = i * 0.1f;
        record.adjusted_close = base_price + variation + trend;
        record.volume = 1000000.0f + (std::rand() % 500000);
        
        results.push_back(record);
    }
    
    return results;
}

float MockStockDataProvider::get_base_price(const std::string& ticker) const {
    if (ticker == "SPY") return 450.0f;
    else if (ticker == "QQQ") return 380.0f;
    else if (ticker == "AAPL") return 180.0f;
    else if (ticker == "MSFT") return 350.0f;
    else return 100.0f;
}

// StockDataProviderFactory implementation
std::unique_ptr<IStockDataProvider> StockDataProviderFactory::create_provider(
    const std::string& provider_type, const std::string& data_root) {
    
    if (provider_type == "parquet") {
        return std::make_unique<StockDataProvider>(data_root);
    } else if (provider_type == "mock") {
        return std::make_unique<MockStockDataProvider>();
    } else {
        throw StockDataError("Unknown provider type: " + provider_type);
    }
}

std::unique_ptr<IStockDataProvider> StockDataProviderFactory::create_mock_provider() {
    return std::make_unique<MockStockDataProvider>();
}

} // namespace atlas