#pragma once

#include <string>
#include <vector>
#include <memory>
#include <unordered_map>
#include <chrono>
#include <optional>

namespace atlas {

/**
 * @brief Stock data record structure
 */
struct StockDataRecord {
    std::string date;
    float adjusted_close;
    float volume;
    float market_cap;
    
    StockDataRecord() = default;
    StockDataRecord(const std::string& d, float price, float vol = 0.0f, float cap = 0.0f)
        : date(d), adjusted_close(price), volume(vol), market_cap(cap) {}
};

/**
 * @brief Live data record structure
 */
struct LiveDataRecord {
    std::string symbol;
    float current_price;
    float change;
    float change_percent;
    std::string timestamp;
    
    LiveDataRecord() = default;
    LiveDataRecord(const std::string& sym, float price, float chg, float chg_pct, const std::string& ts)
        : symbol(sym), current_price(price), change(chg), change_percent(chg_pct), timestamp(ts) {}
};

/**
 * @brief Database connection manager for thread-safe operations
 */
class DatabaseManager {
public:
    static DatabaseManager& instance();
    
    /**
     * @brief Initialize database connection pool
     * @param pool_size Size of connection pool
     * @return true if successful
     */
    bool initialize_connection_pool(int pool_size = 20);
    
    /**
     * @brief Get a database connection for current thread
     * @return Database connection pointer
     */
    std::shared_ptr<void> get_thread_connection();
    
    /**
     * @brief Execute SQL query with retry logic
     * @param query SQL query string
     * @param max_retries Maximum number of retries
     * @return Query result as vector of records
     */
    std::vector<std::unordered_map<std::string, std::string>> execute_query(
        const std::string& query, int max_retries = 3);
    
    /**
     * @brief Check connection health
     * @param connection Database connection
     * @return true if connection is healthy
     */
    bool check_connection_health(std::shared_ptr<void> connection);
    
    /**
     * @brief Clean up all connections
     */
    void cleanup_connections();

private:
    DatabaseManager() = default;
    ~DatabaseManager() = default;
    DatabaseManager(const DatabaseManager&) = delete;
    DatabaseManager& operator=(const DatabaseManager&) = delete;
    
    std::vector<std::shared_ptr<void>> connection_pool_;
    std::mutex connection_mutex_;
    int pool_size_ = 20;
    
    std::shared_ptr<void> create_connection();
    std::shared_ptr<void> get_available_connection();
};

/**
 * @brief Stock data provider interface
 */
class IStockDataProvider {
public:
    virtual ~IStockDataProvider() = default;
    
    virtual std::vector<StockDataRecord> get_historical_data(
        const std::string& ticker, int period, const std::string& end_date) = 0;
    
    virtual std::vector<StockDataRecord> get_historical_data_range(
        const std::string& ticker, const std::string& start_date, const std::string& end_date) = 0;
    
    virtual std::optional<LiveDataRecord> get_live_data(const std::string& ticker) = 0;
    
    virtual std::vector<StockDataRecord> get_market_cap_data(
        const std::string& ticker, const std::string& date, int period) = 0;
};

/**
 * @brief Parquet-based stock data provider
 * Equivalent to Julia's StockData.jl functionality
 */
class StockDataProvider : public IStockDataProvider {
public:
    explicit StockDataProvider(const std::string& data_root = "./data");
    
    /**
     * @brief Get historical stock data for a period
     * @param ticker Stock symbol
     * @param period Number of days
     * @param end_date End date (YYYY-MM-DD format)
     * @return Vector of stock data records
     */
    std::vector<StockDataRecord> get_historical_data(
        const std::string& ticker, int period, const std::string& end_date) override;
    
    /**
     * @brief Get historical stock data for date range
     * @param ticker Stock symbol
     * @param start_date Start date (YYYY-MM-DD format)
     * @param end_date End date (YYYY-MM-DD format)
     * @return Vector of stock data records
     */
    std::vector<StockDataRecord> get_historical_data_range(
        const std::string& ticker, const std::string& start_date, const std::string& end_date) override;
    
    /**
     * @brief Get historical data until end date
     * @param ticker Stock symbol
     * @param end_date End date (YYYY-MM-DD format)
     * @param live_data Include live data flag
     * @return Vector of stock data records
     */
    std::vector<StockDataRecord> get_historical_data_until_end_date(
        const std::string& ticker, const std::string& end_date, bool live_data = false);
    
    /**
     * @brief Get live stock data
     * @param ticker Stock symbol
     * @return Live data record if available
     */
    std::optional<LiveDataRecord> get_live_data(const std::string& ticker) override;
    
    /**
     * @brief Get market cap data
     * @param ticker Stock symbol
     * @param date Date (YYYY-MM-DD format)
     * @param period Number of days
     * @return Vector of market cap records
     */
    std::vector<StockDataRecord> get_market_cap_data(
        const std::string& ticker, const std::string& date, int period) override;
    
    /**
     * @brief Get stock data with live data option
     * @param ticker Stock symbol
     * @param period Number of days
     * @param end_date End date (YYYY-MM-DD format)
     * @param live_data Include live data flag
     * @return Vector of stock data records
     */
    std::vector<StockDataRecord> get_stock_data_dataframe(
        const std::string& ticker, int period, const std::string& end_date, bool live_data = false);
    
    /**
     * @brief Calculate percentage changes
     * @param values Vector of values
     * @return Vector of percentage changes
     */
    static std::vector<float> calculate_delta_percentages(const std::vector<float>& values);
    
    /**
     * @brief Set data root directory
     * @param data_root Path to data directory
     */
    void set_data_root(const std::string& data_root) { data_root_ = data_root; }
    
    /**
     * @brief Get current data root directory
     * @return Data root directory path
     */
    const std::string& get_data_root() const { return data_root_; }

private:
    std::string data_root_;
    DatabaseManager& db_manager_;
    
    // Cache for recently accessed data
    std::unordered_map<std::string, std::vector<StockDataRecord>> data_cache_;
    std::unordered_map<std::string, LiveDataRecord> live_data_cache_;
    std::unordered_map<std::string, std::chrono::steady_clock::time_point> cache_timestamps_;
    mutable std::mutex cache_mutex_;
    
    // Cache timeout (5 minutes)
    static constexpr std::chrono::minutes CACHE_TIMEOUT{5};
    
    /**
     * @brief Map ticker symbol (e.g., FNGU to FNGA)
     * @param ticker Original ticker
     * @return Mapped ticker
     */
    std::string map_ticker(const std::string& ticker) const;
    
    /**
     * @brief Get file path for ticker data
     * @param ticker Stock symbol
     * @return File path
     */
    std::string get_data_file_path(const std::string& ticker) const;
    
    /**
     * @brief Get market cap file path for ticker
     * @param ticker Stock symbol
     * @return Market cap file path
     */
    std::string get_market_cap_file_path(const std::string& ticker) const;
    
    /**
     * @brief Execute parquet query using DuckDB
     * @param query SQL query
     * @return Query results
     */
    std::vector<StockDataRecord> execute_parquet_query(const std::string& query);
    
    /**
     * @brief Make live data API call
     * @param ticker Stock symbol
     * @return Live data record if successful
     */
    std::optional<LiveDataRecord> get_live_data_api_call(const std::string& ticker);
    
    /**
     * @brief Combine historical and live data
     * @param historical_data Historical data records
     * @param live_data Live data record
     * @return Combined data records
     */
    std::vector<StockDataRecord> combine_data(
        const std::vector<StockDataRecord>& historical_data, 
        const std::optional<LiveDataRecord>& live_data);
    
    /**
     * @brief Check if cache is valid for key
     * @param cache_key Cache key
     * @return true if cache is valid
     */
    bool is_cache_valid(const std::string& cache_key) const;
    
    /**
     * @brief Update cache with data
     * @param cache_key Cache key
     * @param data Data to cache
     */
    void update_cache(const std::string& cache_key, const std::vector<StockDataRecord>& data);
    
    /**
     * @brief Update live data cache
     * @param ticker Stock symbol
     * @param live_data Live data to cache
     */
    void update_live_cache(const std::string& ticker, const LiveDataRecord& live_data);
    
    /**
     * @brief Get cached data
     * @param cache_key Cache key
     * @return Cached data if available
     */
    std::optional<std::vector<StockDataRecord>> get_cached_data(const std::string& cache_key);
    
    /**
     * @brief Get cached live data
     * @param ticker Stock symbol
     * @return Cached live data if available
     */
    std::optional<LiveDataRecord> get_cached_live_data(const std::string& ticker);
};

/**
 * @brief Mock data provider for testing
 */
class MockStockDataProvider : public IStockDataProvider {
public:
    MockStockDataProvider() = default;
    
    std::vector<StockDataRecord> get_historical_data(
        const std::string& ticker, int period, const std::string& end_date) override;
    
    std::vector<StockDataRecord> get_historical_data_range(
        const std::string& ticker, const std::string& start_date, const std::string& end_date) override;
    
    std::optional<LiveDataRecord> get_live_data(const std::string& ticker) override;
    
    std::vector<StockDataRecord> get_market_cap_data(
        const std::string& ticker, const std::string& date, int period) override;

private:
    std::vector<StockDataRecord> generate_mock_data(
        const std::string& ticker, int period, const std::string& end_date);
    
    float get_base_price(const std::string& ticker) const;
};

/**
 * @brief Stock data provider factory
 */
class StockDataProviderFactory {
public:
    static std::unique_ptr<IStockDataProvider> create_provider(
        const std::string& provider_type = "parquet", 
        const std::string& data_root = "./data");
    
    static std::unique_ptr<IStockDataProvider> create_mock_provider();
};

/**
 * @brief Exception for stock data errors
 */
class StockDataError : public std::runtime_error {
public:
    explicit StockDataError(const std::string& message) 
        : std::runtime_error("Stock data error: " + message) {}
};

} // namespace atlas