#include <gtest/gtest.h>
#include \"stock_node.h\"
#include \"strategy_parser.h\"

using namespace atlas;

class StockNodeTest : public ::testing::Test {
protected:
    StockNodeProcessor processor;
    Strategy strategy;
    
    void SetUp() override {
        // Set up a basic strategy context
        strategy.period = 5;
        strategy.end_date = \"2024-11-25\";
        strategy.tickers = {\"AAPL\", \"GOOGL\"};
    }
};

TEST_F(StockNodeTest, ProcessValidStockNode) {
    // Create a valid stock node
    StrategyNode stock_node;
    stock_node.type = \"stock\";
    stock_node.properties = nlohmann::json{{\"symbol\", \"AAPL\"}};
    stock_node.hash = \"test_hash\";
    
    // Set up test data
    std::vector<bool> active_mask = {true, true, false, true, false};
    int total_days = 5;
    float node_weight = 0.5f;
    std::vector<DayData> portfolio_history(total_days);
    std::vector<std::string> date_range = {\"2024-11-21\", \"2024-11-22\", \"2024-11-23\", \"2024-11-24\", \"2024-11-25\"};
    std::unordered_map<std::string, int> flow_count;
    std::unordered_map<std::string, std::vector<DayData>> flow_stocks;
    std::unordered_map<std::string, std::vector<float>> indicator_cache;
    std::unordered_map<std::string, std::vector<float>> price_cache;
    
    // Process the node
    NodeResult result = processor.process(
        stock_node, active_mask, total_days, node_weight,
        portfolio_history, date_range, flow_count, flow_stocks,
        indicator_cache, price_cache, strategy
    );
    
    // Verify success
    EXPECT_TRUE(result.success);
    EXPECT_EQ(result.processed_days, total_days);
    
    // Verify flow count was incremented
    EXPECT_EQ(flow_count[\"test_hash\"], 1);
    
    // Verify portfolio was updated for active days (days 0, 1, 3)
    // Check that stocks were added to the correct days
    bool found_stocks = false;
    for (const auto& day : portfolio_history) {
        if (!day.empty()) {
            found_stocks = true;
            for (const auto& stock : day.stock_list()) {
                EXPECT_EQ(stock.ticker(), \"AAPL\");
                EXPECT_FLOAT_EQ(stock.weight_tomorrow(), 0.5f);
            }
        }
    }
    EXPECT_TRUE(found_stocks);
}

TEST_F(StockNodeTest, ProcessInvalidNodeMissingSymbol) {
    // Create a stock node without symbol
    StrategyNode invalid_node;
    invalid_node.type = \"stock\";
    invalid_node.properties = nlohmann::json{{\"name\", \"test\"}}; // Missing symbol
    
    std::vector<bool> active_mask = {true, false};
    int total_days = 2;
    float node_weight = 1.0f;
    std::vector<DayData> portfolio_history(total_days);
    std::vector<std::string> date_range = {\"2024-11-24\", \"2024-11-25\"};
    std::unordered_map<std::string, int> flow_count;
    std::unordered_map<std::string, std::vector<DayData>> flow_stocks;
    std::unordered_map<std::string, std::vector<float>> indicator_cache;
    std::unordered_map<std::string, std::vector<float>> price_cache;
    
    NodeResult result = processor.process(
        invalid_node, active_mask, total_days, node_weight,
        portfolio_history, date_range, flow_count, flow_stocks,
        indicator_cache, price_cache, strategy
    );
    
    EXPECT_FALSE(result.success);
    EXPECT_EQ(result.processed_days, 0);
    EXPECT_FALSE(result.error_message.empty());
}

TEST_F(StockNodeTest, ProcessInvalidWeightRange) {
    StrategyNode stock_node;
    stock_node.type = \"stock\";
    stock_node.properties = nlohmann::json{{\"symbol\", \"AAPL\"}};
    
    std::vector<bool> active_mask = {true};
    int total_days = 1;
    float invalid_weight = 1.5f; // Invalid weight > 1.0
    std::vector<DayData> portfolio_history(total_days);
    std::vector<std::string> date_range = {\"2024-11-25\"};
    std::unordered_map<std::string, int> flow_count;
    std::unordered_map<std::string, std::vector<DayData>> flow_stocks;
    std::unordered_map<std::string, std::vector<float>> indicator_cache;
    std::unordered_map<std::string, std::vector<float>> price_cache;
    
    NodeResult result = processor.process(
        stock_node, active_mask, total_days, invalid_weight,
        portfolio_history, date_range, flow_count, flow_stocks,
        indicator_cache, price_cache, strategy
    );
    
    EXPECT_FALSE(result.success);
}

TEST_F(StockNodeTest, ProcessEmptyActiveMask) {
    StrategyNode stock_node;
    stock_node.type = \"stock\";
    stock_node.properties = nlohmann::json{{\"symbol\", \"AAPL\"}};
    
    std::vector<bool> empty_mask; // Empty mask
    int total_days = 1;
    float node_weight = 0.5f;
    std::vector<DayData> portfolio_history(total_days);
    std::vector<std::string> date_range = {\"2024-11-25\"};
    std::unordered_map<std::string, int> flow_count;
    std::unordered_map<std::string, std::vector<DayData>> flow_stocks;
    std::unordered_map<std::string, std::vector<float>> indicator_cache;
    std::unordered_map<std::string, std::vector<float>> price_cache;
    
    NodeResult result = processor.process(
        stock_node, empty_mask, total_days, node_weight,
        portfolio_history, date_range, flow_count, flow_stocks,
        indicator_cache, price_cache, strategy
    );
    
    EXPECT_FALSE(result.success);
}

TEST_F(StockNodeTest, ProcessWithAllActiveDays) {
    StrategyNode stock_node;
    stock_node.type = \"stock\";
    stock_node.properties = nlohmann::json{{\"symbol\", \"GOOGL\"}};
    
    // All days active
    std::vector<bool> active_mask = {true, true, true};
    int total_days = 3;
    float node_weight = 0.33f;
    std::vector<DayData> portfolio_history(total_days);
    std::vector<std::string> date_range = {\"2024-11-23\", \"2024-11-24\", \"2024-11-25\"};
    std::unordered_map<std::string, int> flow_count;
    std::unordered_map<std::string, std::vector<DayData>> flow_stocks;
    std::unordered_map<std::string, std::vector<float>> indicator_cache;
    std::unordered_map<std::string, std::vector<float>> price_cache;
    
    NodeResult result = processor.process(
        stock_node, active_mask, total_days, node_weight,
        portfolio_history, date_range, flow_count, flow_stocks,
        indicator_cache, price_cache, strategy
    );
    
    EXPECT_TRUE(result.success);
    
    // All days should have the stock
    for (const auto& day : portfolio_history) {
        EXPECT_FALSE(day.empty());
        EXPECT_EQ(day.stock_list()[0].ticker(), \"GOOGL\");
        EXPECT_FLOAT_EQ(day.stock_list()[0].weight_tomorrow(), 0.33f);
    }
}

TEST_F(StockNodeTest, ProcessWithNoActiveDays) {
    StrategyNode stock_node;
    stock_node.type = \"stock\";
    stock_node.properties = nlohmann::json{{\"symbol\", \"TSLA\"}};
    
    // No days active
    std::vector<bool> active_mask = {false, false, false};
    int total_days = 3;
    float node_weight = 1.0f;
    std::vector<DayData> portfolio_history(total_days);
    std::vector<std::string> date_range = {\"2024-11-23\", \"2024-11-24\", \"2024-11-25\"};
    std::unordered_map<std::string, int> flow_count;
    std::unordered_map<std::string, std::vector<DayData>> flow_stocks;
    std::unordered_map<std::string, std::vector<float>> indicator_cache;
    std::unordered_map<std::string, std::vector<float>> price_cache;
    
    NodeResult result = processor.process(
        stock_node, active_mask, total_days, node_weight,
        portfolio_history, date_range, flow_count, flow_stocks,
        indicator_cache, price_cache, strategy
    );
    
    EXPECT_TRUE(result.success); // Should succeed even with no active days
    
    // No days should have stocks
    for (const auto& day : portfolio_history) {
        EXPECT_TRUE(day.empty());
    }
}

TEST_F(StockNodeTest, GetNodeType) {
    EXPECT_EQ(processor.get_node_type(), \"stock\");
}", "original_text": "", "replace_all": false}]