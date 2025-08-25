#include <gtest/gtest.h>
#include \"types.h\"

using namespace atlas;

class TypesTest : public ::testing::Test {
protected:
    void SetUp() override {
        // Set up test data
    }
};

// StockInfo tests
TEST_F(TypesTest, StockInfoConstruction) {
    StockInfo stock(\"AAPL\", 0.5f);
    EXPECT_EQ(stock.ticker(), \"AAPL\");
    EXPECT_FLOAT_EQ(stock.weight_tomorrow(), 0.5f);
}

TEST_F(TypesTest, StockInfoEquality) {
    StockInfo stock1(\"AAPL\", 0.5f);
    StockInfo stock2(\"AAPL\", 0.5f);
    StockInfo stock3(\"GOOGL\", 0.5f);
    StockInfo stock4(\"AAPL\", 0.6f);
    
    EXPECT_EQ(stock1, stock2);
    EXPECT_NE(stock1, stock3);
    EXPECT_NE(stock1, stock4);
}

TEST_F(TypesTest, StockInfoSetters) {
    StockInfo stock;
    stock.set_ticker(\"MSFT\");
    stock.set_weight_tomorrow(0.75f);
    
    EXPECT_EQ(stock.ticker(), \"MSFT\");
    EXPECT_FLOAT_EQ(stock.weight_tomorrow(), 0.75f);
}

// DayData tests
TEST_F(TypesTest, DayDataConstruction) {
    DayData day;
    EXPECT_TRUE(day.empty());
    EXPECT_EQ(day.size(), 0);
}

TEST_F(TypesTest, DayDataWithStocks) {
    std::vector<StockInfo> stocks = {
        StockInfo(\"AAPL\", 0.3f),
        StockInfo(\"GOOGL\", 0.7f)
    };
    
    DayData day(stocks);
    EXPECT_FALSE(day.empty());
    EXPECT_EQ(day.size(), 2);
    EXPECT_EQ(day.stock_list()[0].ticker(), \"AAPL\");
    EXPECT_EQ(day.stock_list()[1].ticker(), \"GOOGL\");
}

TEST_F(TypesTest, DayDataAddStock) {
    DayData day;
    StockInfo stock(\"TSLA\", 1.0f);
    
    day.add_stock(stock);
    EXPECT_EQ(day.size(), 1);
    EXPECT_EQ(day.stock_list()[0].ticker(), \"TSLA\");
}

TEST_F(TypesTest, DayDataEquality) {
    // Test equality with same stocks in different order (like Julia implementation)
    DayData day1;
    day1.add_stock(StockInfo(\"AAPL\", 0.3f));
    day1.add_stock(StockInfo(\"GOOGL\", 0.7f));
    
    DayData day2;
    day2.add_stock(StockInfo(\"GOOGL\", 0.7f));
    day2.add_stock(StockInfo(\"AAPL\", 0.3f));
    
    EXPECT_EQ(day1, day2); // Should be equal due to sorting in comparison
}

TEST_F(TypesTest, DayDataClear) {
    DayData day;
    day.add_stock(StockInfo(\"AAPL\", 0.5f));
    EXPECT_FALSE(day.empty());
    
    day.clear();
    EXPECT_TRUE(day.empty());
    EXPECT_EQ(day.size(), 0);
}

// CacheData tests
TEST_F(TypesTest, CacheDataConstruction) {
    CacheData cache;
    EXPECT_EQ(cache.uncalculated_days(), 0);
    EXPECT_FALSE(cache.cache_present());
    EXPECT_TRUE(cache.response().empty());
}

TEST_F(TypesTest, CacheDataWithData) {
    std::unordered_map<std::string, std::vector<float>> response;
    response[\"AAPL\"] = {100.0f, 101.0f, 102.0f};
    
    CacheData cache(response, 5, true);
    EXPECT_EQ(cache.uncalculated_days(), 5);
    EXPECT_TRUE(cache.cache_present());
    EXPECT_EQ(cache.response().size(), 1);
    EXPECT_EQ(cache.response().at(\"AAPL\").size(), 3);
}

// SubtreeContext tests
TEST_F(TypesTest, SubtreeContextConstruction) {
    SubtreeContext context;
    EXPECT_EQ(context.backtest_period(), 0);
    EXPECT_EQ(context.common_data_span(), 0);
    EXPECT_TRUE(context.profile_history().empty());
    EXPECT_TRUE(context.flow_count().empty());
    EXPECT_TRUE(context.trading_dates().empty());
    EXPECT_TRUE(context.active_mask().empty());
}

TEST_F(TypesTest, SubtreeContextWithData) {
    std::vector<DayData> history(10);
    std::unordered_map<std::string, int> flow_count{{\"hash1\", 5}};
    std::vector<std::string> dates{\"2024-01-01\", \"2024-01-02\"};
    std::vector<bool> mask{true, false, true};
    
    SubtreeContext context(30, history, flow_count, {}, dates, mask, 25);
    
    EXPECT_EQ(context.backtest_period(), 30);
    EXPECT_EQ(context.common_data_span(), 25);
    EXPECT_EQ(context.profile_history().size(), 10);
    EXPECT_EQ(context.flow_count().size(), 1);
    EXPECT_EQ(context.trading_dates().size(), 2);
    EXPECT_EQ(context.active_mask().size(), 3);
}", "original_text": "", "replace_all": false}]