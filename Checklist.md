Checklist for AI Agent (Project Progress Audit)

Implement SmallStrategy.json in Atlas, with Tests

 Confirm SmallStrategy.json is implemented in Atlas

 Verify Expected Returns match exactly

 Ensure tests exist to measure graph execution speed

Switch to Ninja + CMake (remove legacy parts)

 Confirm build system is Ninja + CMake

 Remove old dependencies: QT/GUI, Python interface, etc.

Create HistoricalData class (DuckDB-based)

 Lazy-load stock data at runtime using DuckDB

 Source data from yahoofinance-huggingface index

 Ensure data is always in RAM for fast backtests

 Add local disk caching to avoid re-downloads

Complete Implementation of All Nodes + Tests

 Verify Node Logic is fully implemented

 Verify Node Tests cover all nodes

Implement & Test All Remaining Strategies

 MediumStrategy.json

 LargeStrategy.json

 Smoke tests

 Any additional missing tests

Speed up Graph Backtesting

 Add multi-processing support to backtester

 Measure performance improvements

Cross-compile to WASM

 Ensure project compiles to WASM

 Verify data can be fetched via HistoricalData in browser

 Ensure backtesting runs correctly in browser