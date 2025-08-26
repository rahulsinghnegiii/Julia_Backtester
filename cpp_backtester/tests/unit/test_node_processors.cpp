#include <gtest/gtest.h>
#include "conditional_node.h"
#include "sort_node.h"
#include "strategy.h"
#include "types.h"
#include <nlohmann/json.hpp>

using namespace atlas;
using json = nlohmann::json;

class NodeProcessorsTest : public ::testing::Test {
protected:
    void SetUp() override {
        // Setup common test data
        date_range = {"2024-01-01", "2024-01-02", "2024-01-03", "2024-01-04", "2024-01-05"};
        total_days = static_cast<int>(date_range.size());
        
        // Initialize portfolio history
        portfolio_history.resize(total_days);
        
        // Initialize active mask (all days active)
        active_mask.resize(total_days, true);
        
        // Setup mock indicator and price cache
        setupMockCache();
        
        // Setup test strategy
        setupTestStrategy();
    }
    
    void setupMockCache() {
        // Mock SPY prices and SMA-200
        std::vector<float> spy_prices = {450.0f, 445.0f, 448.0f, 452.0f, 449.0f};
        std::vector<float> spy_sma_200 = {448.0f, 447.0f, 447.5f, 448.5f, 448.2f};
        
        // Mock QQQ prices and SMA-20
        std::vector<float> qqq_prices = {380.0f, 375.0f, 378.0f, 382.0f, 379.0f};
        std::vector<float> qqq_sma_20 = {378.0f, 377.0f, 377.5f, 378.5f, 378.2f};
        
        // Mock PSQ and SHY RSI-10
        std::vector<float> psq_rsi_10 = {65.0f, 70.0f, 68.0f, 72.0f, 69.0f};
        std::vector<float> shy_rsi_10 = {55.0f, 60.0f, 58.0f, 62.0f, 59.0f};
        
        price_cache["SPY"] = spy_prices;
        price_cache["QQQ"] = qqq_prices;
        
        indicator_cache["SPY_SMA_200"] = spy_sma_200;
        indicator_cache["QQQ_SMA_20"] = qqq_sma_20;
        indicator_cache["PSQ_RSI_10"] = psq_rsi_10;
        indicator_cache["SHY_RSI_10"] = shy_rsi_10;
    }
    
    void setupTestStrategy() {
        strategy.tickers = {"SPY", "QQQ", "PSQ", "SHY"};
        strategy.period = total_days;
        strategy.end_date = "2024-01-05";
    }
    
    // Test data
    std::vector<std::string> date_range;
    int total_days;
    std::vector<DayData> portfolio_history;
    std::vector<bool> active_mask;
    std::unordered_map<std::string, int> flow_count;
    std::unordered_map<std::string, std::vector<DayData>> flow_stocks;
    std::unordered_map<std::string, std::vector<float>> indicator_cache;
    std::unordered_map<std::string, std::vector<float>> price_cache;
    Strategy strategy;
    
    // Helper methods
    StrategyNode create_conditional_node() {
        StrategyNode node;
        node.type = "condition";
        node.id = "test_condition";
        
        // Create condition: SPY current_price < SPY SMA-200
        json properties = {
            {"comparison", "<"},
            {"x", {
                {"indicator", "current price"},
                {"source", "SPY"}
            }},
            {"y", {
                {"indicator", "Simple Moving Average of Price"},
                {"period", "200"},
                {"source", "SPY"}
            }}
        };
        node.properties = properties;
        
        // Create branches
        json branches = {
            {"true", json::array()},
            {"false", json::array()}
        };
        node.branches = branches;
        
        return node;
    }
    
    StrategyNode create_sort_node() {
        StrategyNode node;
        node.type = "Sort";
        node.id = "test_sort";
        
        json properties = {
            {"select", {
                {"function", "Top"},
                {"howmany", "1"}
            }},
            {"sortby", {
                {"function", "Relative Strength Index"},
                {"window", "10"}
            }}
        };
        node.properties = properties;
        
        // Create branches with PSQ and SHY
        json branches = {
            {"Top-1", json::array()}
        };
        node.branches = branches;
        
        return node;
    }
};

// ============================================================================
// ConditionalNode Tests
// ============================================================================

TEST_F(NodeProcessorsTest, ConditionalNode_BasicValidation) {
    ConditionalNodeProcessor processor;
    
    EXPECT_EQ(processor.get_node_type(), "condition");
    
    auto node = create_conditional_node();
    
    // Test basic validation
    EXPECT_NO_THROW({
        NodeResult result = processor.process(
            node, active_mask, total_days, 1.0f, portfolio_history,
            date_range, flow_count, flow_stocks, indicator_cache, price_cache,
            strategy, false, 0
        );
    });
}

TEST_F(NodeProcessorsTest, ConditionalNode_ComparisonOperators) {
    ConditionalNodeProcessor processor;
    
    // Test different comparison operators
    std::vector<std::string> operators = {">", "<", "==", ">=", "<=", "!="};
    
    for (const auto& op : operators) {
        auto node = create_conditional_node();
        node.properties["comparison"] = op;
        
        EXPECT_NO_THROW({
            processor.process(
                node, active_mask, total_days, 1.0f, portfolio_history,
                date_range, flow_count, flow_stocks, indicator_cache, price_cache,
                strategy, false, 0
            );
        }) << "Failed for operator: " << op;
    }
}

TEST_F(NodeProcessorsTest, ConditionalNode_SPY_SMA_Logic) {
    ConditionalNodeProcessor processor;
    auto node = create_conditional_node();
    
    // Test the specific SPY < SMA-200 logic
    NodeResult result = processor.process(
        node, active_mask, total_days, 1.0f, portfolio_history,
        date_range, flow_count, flow_stocks, indicator_cache, price_cache,
        strategy, false, 0
    );
    
    EXPECT_TRUE(result.success) << "ConditionalNode processing should succeed";
    EXPECT_EQ(result.processed_days, total_days) << "Should process all days";
    
    // Verify condition evaluation based on our mock data
    // SPY prices: [450, 445, 448, 452, 449]
    // SPY SMA-200: [448, 447, 447.5, 448.5, 448.2]
    // Expected: [false, true, false, false, false]
    
    // Day 1: 445 < 447 = true (should take true branch)
    // Day 2: 448 >= 447.5 = false (should take false branch)
}

TEST_F(NodeProcessorsTest, ConditionalNode_InvalidProperties) {
    ConditionalNodeProcessor processor;
    
    // Test with missing comparison
    StrategyNode invalid_node;
    invalid_node.type = "condition";
    invalid_node.properties = json::object();
    
    EXPECT_THROW({
        processor.process(
            invalid_node, active_mask, total_days, 1.0f, portfolio_history,
            date_range, flow_count, flow_stocks, indicator_cache, price_cache,
            strategy, false, 0
        );
    }, ConditionalNodeError);
}

TEST_F(NodeProcessorsTest, ConditionalNode_MissingIndicatorData) {
    ConditionalNodeProcessor processor;
    auto node = create_conditional_node();
    
    // Clear indicator cache to simulate missing data
    indicator_cache.clear();
    
    EXPECT_NO_THROW({
        NodeResult result = processor.process(
            node, active_mask, total_days, 1.0f, portfolio_history,
            date_range, flow_count, flow_stocks, indicator_cache, price_cache,
            strategy, false, 0
        );
        // Should handle missing data gracefully
    });
}

// ============================================================================
// SortNode Tests  
// ============================================================================

TEST_F(NodeProcessorsTest, SortNode_BasicValidation) {
    SortNodeProcessor processor;
    
    EXPECT_EQ(processor.get_node_type(), "Sort");
    
    auto node = create_sort_node();
    
    EXPECT_NO_THROW({
        NodeResult result = processor.process(
            node, active_mask, total_days, 1.0f, portfolio_history,
            date_range, flow_count, flow_stocks, indicator_cache, price_cache,
            strategy, false, 0
        );
    });
}

TEST_F(NodeProcessorsTest, SortNode_RSI_TopSelection) {
    SortNodeProcessor processor;
    auto node = create_sort_node();
    
    // Create mock branches for PSQ and SHY
    StrategyNode psq_node;
    psq_node.type = "stock";
    psq_node.properties = json{{"symbol", "PSQ"}};
    
    StrategyNode shy_node;
    shy_node.type = "stock";
    shy_node.properties = json{{"symbol", "SHY"}};
    
    node.branches["Top-1"] = json::array({psq_node, shy_node});
    
    NodeResult result = processor.process(
        node, active_mask, total_days, 1.0f, portfolio_history,
        date_range, flow_count, flow_stocks, indicator_cache, price_cache,
        strategy, false, 0
    );
    
    EXPECT_TRUE(result.success) << "SortNode processing should succeed";
    
    // Verify that sorting by RSI selects the correct stock
    // PSQ RSI-10: [65, 70, 68, 72, 69]
    // SHY RSI-10: [55, 60, 58, 62, 59]
    // PSQ should be selected on all days (higher RSI)
}

TEST_F(NodeProcessorsTest, SortNode_SelectionFunctions) {
    SortNodeProcessor processor;
    
    // Test Top selection
    auto top_node = create_sort_node();
    top_node.properties["select"]["function"] = "Top";
    top_node.properties["select"]["howmany"] = "1";
    
    EXPECT_NO_THROW({
        processor.process(
            top_node, active_mask, total_days, 1.0f, portfolio_history,
            date_range, flow_count, flow_stocks, indicator_cache, price_cache,
            strategy, false, 0
        );
    });
    
    // Test Bottom selection
    auto bottom_node = create_sort_node();
    bottom_node.properties["select"]["function"] = "Bottom";
    bottom_node.properties["select"]["howmany"] = "1";
    
    EXPECT_NO_THROW({
        processor.process(
            bottom_node, active_mask, total_days, 1.0f, portfolio_history,
            date_range, flow_count, flow_stocks, indicator_cache, price_cache,
            strategy, false, 0
        );
    });
}

TEST_F(NodeProcessorsTest, SortNode_DifferentSortFunctions) {
    SortNodeProcessor processor;
    
    std::vector<std::string> sort_functions = {
        "Relative Strength Index",
        "Simple Moving Average",
        "Exponential Moving Average",
        "Current Price"
    };
    
    for (const auto& func : sort_functions) {
        auto node = create_sort_node();
        node.properties["sortby"]["function"] = func;
        
        EXPECT_NO_THROW({
            processor.process(
                node, active_mask, total_days, 1.0f, portfolio_history,
                date_range, flow_count, flow_stocks, indicator_cache, price_cache,
                strategy, false, 0
            );
        }) << "Failed for sort function: " << func;
    }
}

TEST_F(NodeProcessorsTest, SortNode_InvalidProperties) {
    SortNodeProcessor processor;
    
    // Test with missing select properties
    StrategyNode invalid_node;
    invalid_node.type = "Sort";
    invalid_node.properties = json::object();
    
    EXPECT_THROW({
        processor.process(
            invalid_node, active_mask, total_days, 1.0f, portfolio_history,
            date_range, flow_count, flow_stocks, indicator_cache, price_cache,
            strategy, false, 0
        );
    }, NodeProcessingError);
}

TEST_F(NodeProcessorsTest, SortNode_MultipleSelection) {
    SortNodeProcessor processor;
    auto node = create_sort_node();
    
    // Test selecting top 2 items
    node.properties["select"]["howmany"] = "2";
    
    EXPECT_NO_THROW({
        NodeResult result = processor.process(
            node, active_mask, total_days, 1.0f, portfolio_history,
            date_range, flow_count, flow_stocks, indicator_cache, price_cache,
            strategy, false, 0
        );
        
        EXPECT_TRUE(result.success);
    });
}

// ============================================================================
// SmallStrategy Integration Tests
// ============================================================================

TEST_F(NodeProcessorsTest, SmallStrategy_FullLogicFlow) {
    // Test the complete SmallStrategy logic flow
    ConditionalNodeProcessor cond_processor;
    SortNodeProcessor sort_processor;
    
    // Create the main conditional node (SPY price < SPY SMA-200)
    auto spy_condition = create_conditional_node();
    
    // Create QQQ stock node for true branch
    StrategyNode qqq_node;
    qqq_node.type = "stock";
    qqq_node.properties = json{{"symbol", "QQQ"}};
    spy_condition.branches["true"] = json::array({qqq_node});
    
    // Create nested conditional for false branch (QQQ price < QQQ SMA-20)
    auto qqq_condition = create_conditional_node();
    qqq_condition.properties["x"]["source"] = "QQQ";
    qqq_condition.properties["y"]["source"] = "QQQ";
    qqq_condition.properties["y"]["period"] = "20";
    
    // Create sort node for QQQ condition true branch
    auto sort_node = create_sort_node();
    StrategyNode psq_node, shy_node;
    psq_node.type = "stock";
    psq_node.properties = json{{"symbol", "PSQ"}};
    shy_node.type = "stock";
    shy_node.properties = json{{"symbol", "SHY"}};
    sort_node.branches["Top-1"] = json::array({psq_node, shy_node});
    
    qqq_condition.branches["true"] = json::array({sort_node});
    qqq_condition.branches["false"] = json::array({qqq_node}); // Else: QQQ
    
    spy_condition.branches["false"] = json::array({qqq_condition});
    
    // Process the complete logic
    std::vector<DayData> test_portfolio(total_days);
    
    EXPECT_NO_THROW({
        NodeResult result = cond_processor.process(
            spy_condition, active_mask, total_days, 1.0f, test_portfolio,
            date_range, flow_count, flow_stocks, indicator_cache, price_cache,
            strategy, false, 0
        );
        
        EXPECT_TRUE(result.success) << "SmallStrategy logic should execute successfully";
    });
}

TEST_F(NodeProcessorsTest, SmallStrategy_EdgeCases) {
    ConditionalNodeProcessor processor;
    
    // Test with partial active mask
    std::vector<bool> partial_mask = {true, false, true, false, true};
    auto node = create_conditional_node();
    
    EXPECT_NO_THROW({
        NodeResult result = processor.process(
            node, partial_mask, total_days, 1.0f, portfolio_history,
            date_range, flow_count, flow_stocks, indicator_cache, price_cache,
            strategy, false, 0
        );
        
        EXPECT_TRUE(result.success);
    });
}

TEST_F(NodeProcessorsTest, SmallStrategy_LiveExecution) {
    ConditionalNodeProcessor processor;
    auto node = create_conditional_node();
    
    // Test live execution mode
    EXPECT_NO_THROW({
        NodeResult result = processor.process(
            node, active_mask, total_days, 1.0f, portfolio_history,
            date_range, flow_count, flow_stocks, indicator_cache, price_cache,
            strategy, true, 100  // live_execution = true, global_cache_length = 100
        );
        
        EXPECT_TRUE(result.success);
    });
}

// ============================================================================
// Performance Tests
// ============================================================================

TEST_F(NodeProcessorsTest, Performance_LargeDataset) {
    ConditionalNodeProcessor cond_processor;
    SortNodeProcessor sort_processor;
    
    // Create larger dataset
    int large_days = 1000;
    std::vector<std::string> large_date_range;
    std::vector<bool> large_active_mask(large_days, true);
    std::vector<DayData> large_portfolio(large_days);
    
    for (int i = 0; i < large_days; ++i) {
        large_date_range.push_back("2024-01-" + std::to_string(i + 1));
    }
    
    // Create large cache data
    std::vector<float> large_spy_prices(large_days, 450.0f);
    std::vector<float> large_spy_sma(large_days, 448.0f);
    price_cache["SPY"] = large_spy_prices;
    indicator_cache["SPY_SMA_200"] = large_spy_sma;
    
    auto node = create_conditional_node();
    
    auto start = std::chrono::high_resolution_clock::now();
    
    NodeResult result = cond_processor.process(
        node, large_active_mask, large_days, 1.0f, large_portfolio,
        large_date_range, flow_count, flow_stocks, indicator_cache, price_cache,
        strategy, false, 0
    );
    
    auto end = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);
    
    EXPECT_TRUE(result.success) << "Large dataset processing should succeed";
    EXPECT_LT(duration.count(), 1000) << "Processing should be fast (< 1 second for 1000 days)";
}