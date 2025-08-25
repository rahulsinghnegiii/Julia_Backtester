#include <gtest/gtest.h>
#include \"backtesting_engine.h\"
#include \"strategy_parser.h\"

using namespace atlas;

class BacktestingEngineTest : public ::testing::Test {
protected:
    BacktestingEngine engine;
    StrategyParser parser;
    
    // Simple stock-only strategy for testing
    const std::string simple_strategy_json = R\"({
        \"json\": \"{\\\"type\\\":\\\"root\\\",\\\"properties\\\":{\\\"id\\\":\\\"test\\\",\\\"step\\\":\\\"root\\\",\\\"name\\\":\\\"root node\\\"},\\\"sequence\\\":[{\\\"id\\\":\\\"stock1\\\",\\\"type\\\":\\\"stock\\\",\\\"name\\\":\\\"BUY AAPL\\\",\\\"properties\\\":{\\\"symbol\\\":\\\"AAPL\\\"}}],\\\"tickers\\\":[\\\"AAPL\\\"],\\\"indicators\\\":[]}\",
        \"period\": \"5\",
        \"end_date\": \"2024-11-25\",
        \"hash\": \"test_hash\"
    })\";
};

TEST_F(BacktestingEngineTest, ExecuteSimpleBacktest) {
    // Parse strategy
    Strategy strategy = parser.parse_strategy(simple_strategy_json);
    
    // Create backtest parameters
    BacktestParams params;
    params.strategy = strategy;
    params.period = 5;
    params.end_date = \"2024-11-25\";
    params.live_execution = false;
    params.global_cache_length = 0;
    
    // Execute backtest
    BacktestResult result = engine.execute_backtest(params);
    
    // Verify success
    EXPECT_TRUE(result.success) << \"Backtest failed: \" << result.error_message;
    EXPECT_GT(result.execution_time.count(), 0);
    
    // Verify portfolio history
    EXPECT_EQ(result.portfolio_history.size(), 5);
    
    // At least some days should have AAPL
    bool found_aapl = false;
    for (const auto& day : result.portfolio_history) {
        for (const auto& stock : day.stock_list()) {
            if (stock.ticker() == \"AAPL\") {
                found_aapl = true;
                EXPECT_GT(stock.weight_tomorrow(), 0.0f);
            }
        }
    }
    EXPECT_TRUE(found_aapl);
}

TEST_F(BacktestingEngineTest, ExecuteBacktestInvalidParams) {
    BacktestParams invalid_params;
    invalid_params.period = 0; // Invalid period
    
    BacktestResult result = engine.execute_backtest(invalid_params);
    
    EXPECT_FALSE(result.success);
    EXPECT_FALSE(result.error_message.empty());
}

TEST_F(BacktestingEngineTest, HandleBacktestingAPI) {
    std::string json_response = engine.handle_backtesting_api(simple_strategy_json);
    
    // Parse response
    auto response = nlohmann::json::parse(json_response);
    
    EXPECT_TRUE(response.contains(\"success\"));
    EXPECT_TRUE(response[\"success\"].get<bool>());
    EXPECT_TRUE(response.contains(\"execution_time_ms\"));
    EXPECT_TRUE(response.contains(\"portfolio_history\"));
}

TEST_F(BacktestingEngineTest, HandleInvalidAPIRequest) {
    std::string invalid_json = \"invalid json\";
    
    std::string json_response = engine.handle_backtesting_api(invalid_json);
    auto response = nlohmann::json::parse(json_response);
    
    EXPECT_TRUE(response.contains(\"success\"));
    EXPECT_FALSE(response[\"success\"].get<bool>());
    EXPECT_TRUE(response.contains(\"error\"));
}

TEST_F(BacktestingEngineTest, PostOrderDFSStockNode) {
    Strategy strategy = parser.parse_strategy(simple_strategy_json);
    
    // Create test data
    std::vector<bool> active_mask = {true, false, true};
    int common_data_span = 3;
    float node_weight = 1.0f;
    std::vector<DayData> portfolio_history(3);
    std::vector<std::string> date_range = {\"2024-11-23\", \"2024-11-24\", \"2024-11-25\"};
    std::unordered_map<std::string, int> flow_count;
    std::unordered_map<std::string, std::vector<DayData>> flow_stocks;
    std::unordered_map<std::string, std::vector<float>> indicator_cache;
    std::unordered_map<std::string, std::vector<float>> price_cache;
    
    // Execute post-order DFS on stock node
    StrategyNode stock_node;
    stock_node.type = \"stock\";
    stock_node.properties = nlohmann::json{{\"symbol\", \"AAPL\"}};
    
    int result = engine.post_order_dfs(
        stock_node, active_mask, common_data_span, node_weight,
        portfolio_history, date_range, flow_count, flow_stocks,
        indicator_cache, price_cache, strategy
    );
    
    EXPECT_EQ(result, common_data_span);
    
    // Verify portfolio was updated
    bool found_stocks = false;
    for (const auto& day : portfolio_history) {
        if (!day.empty()) {
            found_stocks = true;
        }
    }
    EXPECT_TRUE(found_stocks);
}

TEST_F(BacktestingEngineTest, PostOrderDFSFolderNode) {
    Strategy strategy = parser.parse_strategy(simple_strategy_json);
    
    // Create a folder node with child stock nodes
    StrategyNode folder_node;
    folder_node.type = \"folder\";
    folder_node.hash = \"folder_hash\";
    
    StrategyNode child1;
    child1.type = \"stock\";
    child1.properties = nlohmann::json{{\"symbol\", \"AAPL\"}};
    
    StrategyNode child2;
    child2.type = \"stock\";
    child2.properties = nlohmann::json{{\"symbol\", \"GOOGL\"}};
    
    folder_node.sequence = {child1, child2};
    
    // Test data
    std::vector<bool> active_mask = {true, true};
    int common_data_span = 2;
    float node_weight = 1.0f;
    std::vector<DayData> portfolio_history(2);
    std::vector<std::string> date_range = {\"2024-11-24\", \"2024-11-25\"};
    std::unordered_map<std::string, int> flow_count;
    std::unordered_map<std::string, std::vector<DayData>> flow_stocks;
    std::unordered_map<std::string, std::vector<float>> indicator_cache;
    std::unordered_map<std::string, std::vector<float>> price_cache;
    
    int result = engine.post_order_dfs(
        folder_node, active_mask, common_data_span, node_weight,
        portfolio_history, date_range, flow_count, flow_stocks,
        indicator_cache, price_cache, strategy
    );
    
    EXPECT_EQ(result, common_data_span);
    
    // Verify flow count was incremented for folder
    EXPECT_EQ(flow_count[\"folder_hash\"], 1);
    
    // Verify both stocks were added
    bool found_aapl = false, found_googl = false;
    for (const auto& day : portfolio_history) {
        for (const auto& stock : day.stock_list()) {
            if (stock.ticker() == \"AAPL\") found_aapl = true;
            if (stock.ticker() == \"GOOGL\") found_googl = true;
        }
    }
    EXPECT_TRUE(found_aapl);
    EXPECT_TRUE(found_googl);
}

TEST_F(BacktestingEngineTest, PostOrderDFSUnknownNodeType) {
    Strategy strategy = parser.parse_strategy(simple_strategy_json);
    
    StrategyNode unknown_node;
    unknown_node.type = \"unknown_type\";
    
    std::vector<bool> active_mask = {true};
    int common_data_span = 1;
    float node_weight = 1.0f;
    std::vector<DayData> portfolio_history(1);
    std::vector<std::string> date_range = {\"2024-11-25\"};
    std::unordered_map<std::string, int> flow_count;
    std::unordered_map<std::string, std::vector<DayData>> flow_stocks;
    std::unordered_map<std::string, std::vector<float>> indicator_cache;
    std::unordered_map<std::string, std::vector<float>> price_cache;
    
    EXPECT_THROW({
        engine.post_order_dfs(
            unknown_node, active_mask, common_data_span, node_weight,
            portfolio_history, date_range, flow_count, flow_stocks,
            indicator_cache, price_cache, strategy
        );
    }, std::runtime_error);
}", "original_text": "", "replace_all": false}]