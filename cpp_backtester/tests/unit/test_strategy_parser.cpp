#include <gtest/gtest.h>
#include \"strategy_parser.h\"
#include <nlohmann/json.hpp>

using namespace atlas;

class StrategyParserTest : public ::testing::Test {
protected:
    StrategyParser parser;
    
    // Sample strategy JSON similar to SmallStrategy.json
    const std::string sample_strategy_json = R\"({
        \"json\": \"{\\\"type\\\":\\\"root\\\",\\\"properties\\\":{\\\"id\\\":\\\"f5575cedaa4a16c0c192cda063fe0724\\\",\\\"step\\\":\\\"root\\\",\\\"name\\\":\\\"root node\\\",\\\"triggerPeriod\\\":\\\"monthly\\\"},\\\"sequence\\\":[{\\\"id\\\":\\\"714628fcdeda1ca52722fd562e0f97f5\\\",\\\"componentType\\\":\\\"task\\\",\\\"type\\\":\\\"stock\\\",\\\"name\\\":\\\"BUY QQQ\\\",\\\"properties\\\":{\\\"symbol\\\":\\\"QQQ\\\"},\\\"hash\\\":\\\"3d78dfbadec0f0703a82240269cdef47\\\",\\\"parentHash\\\":\\\"a533604873cbe4f0523af58547683c45\\\"}],\\\"tickers\\\":[\\\"QQQ\\\"],\\\"indicators\\\":[],\\\"nodeChildrenHash\\\":\\\"c51d42f7f3a70aaab465d21954f457d9\\\"}\",
        \"period\": \"10\",
        \"end_date\": \"2024-11-25\",
        \"hash\": \"d2936843a0ad3275a5f5e72749594ffe\"
    })\";
};

TEST_F(StrategyParserTest, ParseValidStrategy) {
    EXPECT_NO_THROW({
        Strategy strategy = parser.parse_strategy(sample_strategy_json);
        
        EXPECT_EQ(strategy.period, 10);
        EXPECT_EQ(strategy.end_date, \"2024-11-25\");
        EXPECT_EQ(strategy.strategy_hash, \"d2936843a0ad3275a5f5e72749594ffe\");
        EXPECT_EQ(strategy.root.type, \"root\");
        EXPECT_FALSE(strategy.tickers.empty());
        EXPECT_EQ(strategy.tickers[0], \"QQQ\");
    });
}

TEST_F(StrategyParserTest, ParseInvalidJSON) {
    std::string invalid_json = \"invalid json\";
    
    EXPECT_THROW({
        parser.parse_strategy(invalid_json);
    }, StrategyParseError);
}

TEST_F(StrategyParserTest, ParseMissingJsonField) {
    std::string missing_json_field = R\"({
        \"period\": \"10\",
        \"end_date\": \"2024-11-25\",
        \"hash\": \"test\"
    })\";
    
    EXPECT_THROW({
        parser.parse_strategy(missing_json_field);
    }, StrategyParseError);
}

TEST_F(StrategyParserTest, ValidateValidStrategy) {
    Strategy strategy = parser.parse_strategy(sample_strategy_json);
    EXPECT_TRUE(parser.validate_strategy(strategy));
}

TEST_F(StrategyParserTest, ValidateInvalidStrategy) {
    Strategy invalid_strategy;
    invalid_strategy.period = 0; // Invalid period
    
    EXPECT_FALSE(parser.validate_strategy(invalid_strategy));
}

TEST_F(StrategyParserTest, ParseStockNode) {
    nlohmann::json stock_node_json = {
        {\"id\", \"test_id\"},
        {\"type\", \"stock\"},
        {\"name\", \"BUY AAPL\"},
        {\"componentType\", \"task\"},
        {\"properties\", {{\"symbol\", \"AAPL\"}}},
        {\"hash\", \"test_hash\"}
    };
    
    StrategyNode node = parser.parse_node(stock_node_json);
    
    EXPECT_EQ(node.id, \"test_id\");
    EXPECT_EQ(node.type, \"stock\");
    EXPECT_EQ(node.name, \"BUY AAPL\");
    EXPECT_EQ(node.component_type, \"task\");
    EXPECT_EQ(node.hash, \"test_hash\");
    EXPECT_TRUE(node.properties.contains(\"symbol\"));
    EXPECT_EQ(node.properties[\"symbol\"].get<std::string>(), \"AAPL\");
}

TEST_F(StrategyParserTest, ParseConditionalNode) {
    nlohmann::json conditional_node_json = {
        {\"id\", \"cond_id\"},
        {\"type\", \"condition\"},
        {\"name\", \"Price Condition\"},
        {\"properties\", {
            {\"comparison\", \"<\"},
            {\"x\", {{\"indicator\", \"current price\"}, {\"source\", \"SPY\"}}},
            {\"y\", {{\"indicator\", \"SMA\"}, {\"period\", \"200\"}, {\"source\", \"SPY\"}}}
        }},
        {\"branches\", {
            {\"true\", nlohmann::json::array()},
            {\"false\", nlohmann::json::array()}
        }}
    };
    
    StrategyNode node = parser.parse_node(conditional_node_json);
    
    EXPECT_EQ(node.type, \"condition\");
    EXPECT_TRUE(node.properties.contains(\"comparison\"));
    EXPECT_TRUE(node.properties.contains(\"x\"));
    EXPECT_TRUE(node.properties.contains(\"y\"));
    EXPECT_TRUE(node.branches.contains(\"true\"));
    EXPECT_TRUE(node.branches.contains(\"false\"));
}

TEST_F(StrategyParserTest, ParseNodeWithSequence) {
    nlohmann::json folder_node_json = {
        {\"type\", \"folder\"},
        {\"sequence\", nlohmann::json::array({
            {
                {\"type\", \"stock\"},
                {\"properties\", {{\"symbol\", \"AAPL\"}}}
            },
            {
                {\"type\", \"stock\"},
                {\"properties\", {{\"symbol\", \"GOOGL\"}}}
            }
        })}
    };
    
    StrategyNode node = parser.parse_node(folder_node_json);
    
    EXPECT_EQ(node.type, \"folder\");
    EXPECT_EQ(node.sequence.size(), 2);
    EXPECT_EQ(node.sequence[0].type, \"stock\");
    EXPECT_EQ(node.sequence[1].type, \"stock\");
}

TEST_F(StrategyParserTest, ValidateStockNodeValid) {
    nlohmann::json valid_stock = {
        {\"type\", \"stock\"},
        {\"properties\", {{\"symbol\", \"AAPL\"}}}
    };
    
    StrategyNode node = parser.parse_node(valid_stock);
    // Note: We would need to expose validate_node as public to test it directly
    // For now, this test validates that parsing completes successfully
    EXPECT_EQ(node.type, \"stock\");
}

TEST_F(StrategyParserTest, ComplexStrategyParsing) {
    // Test with a more complex strategy structure
    Strategy strategy = parser.parse_strategy(sample_strategy_json);
    
    // Verify root node
    EXPECT_EQ(strategy.root.type, \"root\");
    EXPECT_TRUE(strategy.root.properties.contains(\"id\"));
    
    // Verify tickers are extracted
    EXPECT_FALSE(strategy.tickers.empty());
    
    // Verify basic structure
    EXPECT_GE(strategy.period, 1);
    EXPECT_FALSE(strategy.end_date.empty());
}", "original_text": "", "replace_all": false}]