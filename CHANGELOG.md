## 2025-04-06 [*](https://github.com/algozen-io/TA_Indicators_Service/pull/225)

### Changed
- Enhanced caching functions to support live execution mode
- Improved error handling for data retrieval operations
- Added robust JSON parsing for live data API responses

## 2025-04-05 [*](https://github.com/algozen-io/TA_Indicators_Service/pull/224)

### Added
- Added script to save all folders in a strategy
- Improved subtree cache truncation logic in one-day backtest
- Enhanced test diagnostics with additional logging

## 2025-03-24 [*](https://github.com/algozen-io/TA_Indicators_Service/pull/221)

### Changed
- Optimized portfolio handling for backtesting with memory-mapped data and improved caching
- Enhanced branch return curve calculation for better performance
- Fixed N-day backtest issues with proper data range handling
- Improved error handling and logging in node processing functions
## 2025-03-26 [*](https://github.com/algozen-io/TA_Indicators_Service/pull/222)

### Changed
- Updated git hooks to improve test workflow and reporting
- Removed E2E tests and added GlobalLRUCache tests
- Fixed FlowMap error test handling
- Improved code formatting across multiple test files



## 2025-03-21 [*](https://github.com/algozen-io/TA_Indicators_Service/pull/218)

### Added
- Added benchmark timing tests for various node operations
- Implemented weekly test reports with timestamps
- Improved test coverage for allocation, conditional, sort, and stock nodes

## 2025-03-23 [*](https://github.com/algozen-io/TA_Indicators_Service/pull/220)

### Added
- Added support for "Equal Allocation" function in allocation processing
- Enhanced conditional logic in allocation node functions
## 2025-03-20 [*](https://github.com/algozen-io/TA_Indicators_Service/pull/216)

### Fixed
- Updated ticker date function to return earliest dates instead of latest
- Changed metadata reference from end_date to start_date
- Improved data consistency in backtest utilities



## 2025-03-18 [*](https://github.com/algozen-io/TA_Indicators_Service/pull/214)

### Added
- Implemented ticker mapping from FNGU to FNGA until May 2025
- Updated trading days reference from SPY to KO in cache handling
- Improved consistency in ticker symbol handling across data retrieval functions



## 2025-03-12 [*](https://github.com/algozen-io/TA_Indicators_Service/pull/210)

### Fixed
- Fixed error handling for unknown indicator functions
- Updated "Moving Average of Price" to "Simple Moving Average of Price" for consistency
- Added test coverage for indicator name error cases

## 2025-03-11 [*](https://github.com/algozen-io/TA_Indicators_Service/pull/208)

### Changed
- Updated default ticker from SPY to KO in date population functions
- Improved consistency in stock data retrieval operations


## 2025-03-06 [*](https://github.com/algozen-io/TA_Indicators_Service/pull/205)

### Added
- Added function to return end dates for all tickers in strategy data
- Enhanced API response with ticker date information
- Improved diagnostics for identifying data availability limitations


## 2024-02-03 [*](https://github.com/algozen-io/TA_Indicators_Service/pull/183)

### Changed
- Updated node weight calculation to exclude comment nodes
- Added test coverage for comment node weight handling
- Improved branch node processing accuracy by filtering out comments

## 2024-01-16 [*](https://github.com/algozen-io/TA_Indicators_Service/pull/174)

### Changed
- Optimized backtest runs to use cached data more efficiently
- Improved handling of uncalculated trading days when cache is present
- Enhanced error messaging for insufficient price data scenarios

## 2025-02-11 [*](https://github.com/algozen-io/TA_Indicators_Service/pull/187)

### Changed
- Enhanced synthetic value handling in conditional nodes
- Improved error handling and logging for synthetic stock operations
- Updated synthetic indicator data processing with stricter validation



## 2024-12-30 [*](https://github.com/algozen-io/TA_Indicators_Service/pull/168)

### Changed
- Optimized stock data retrieval with improved DuckDB query logic
- Refactored comparison operations to use broadcasting for better performance
- Enhanced sort node processing with cleaner code structure and error handling

Based on the PR changes, I'll add a new entry to the CHANGELOG.md focusing on the key changes:

## 2024-12-30 [\*](https://github.com/algozen-io/TA_Indicators_Service/pull/165)

### Added
- Implemented synthetic stock functionality with folder-based organization
- Added stock ratio support in conditional nodes
- Enhanced node processing with strategy root context propagation

### Changed
- Updated node processors to handle synthetic stocks and stock ratios
- Improved test organization and coverage across multiple node types


Based on the PR changes, I'll add a new entry to the CHANGELOG.md focusing on the key changes. Here's the suggested addition:

```markdown
## 2024-12-17

### Added

- Implemented memory-mapped file operations for subtree portfolio data to improve performance and memory efficiency.
- Added comprehensive testing suite for portfolio data operations comparing Parquet and memory-mapped implementations.

### Changed

- Enhanced subtree cache functionality with new read/write operations supporting both Parquet and memory-mapped formats.
```

This changelog entry captures the main improvements introduced in this PR: the implementation of memory-mapped operations for portfolio data handling and the addition of related tests, while maintaining the existing style and format of the changelog.

## 2024-12-25 [\*](https://github.com/algozen-io/TA_Indicators_Service/pull/164)

### Added

- Implemented Lock on Trigger (LOT) node functionality for conditional branch execution
- Added support for entry and exit conditions in LOT node processing
- Introduced error handling specific to LOT node operations

## 2024-11-18

### Changed

- Refactored error handling in backtest routes and utilities to use specific error types for improved clarity and maintainability.

### Added

- Introduced custom exception types for better error categorization and handling in backtest processes.
- Added validation functions to ensure the integrity of input parameters and node structures in backtest operations.

## 2024-11-12

### Fixed

- Corrected the calculation of `min_days_manual` in the allocation process to ensure accurate results.

## 2024-11-06

### Fixed

- Added a check in `parse_sort_properties` to handle empty `sortby` window cases, defaulting to 0.

### Added

- Introduced a unit test for verifying behavior with an empty `sortby` window.
- Updated `Tests.md` with detailed test summaries, execution times, and coverage metrics.

## 2024-10-28

### Fixed

- Addressed caching issues in indicator functions to improve performance and reliability.

### Changed

- Refactored data handling by separating utility functions into `DataUtils.jl` and database management into `DuckDbManager.jl` for better modularity.
- Updated stock data retrieval functions to use DuckDB queries for enhanced efficiency.

## 2024-10-22

### Added

- Added unit tests for `StockNode` to verify stock node processing and portfolio history updates.
- Introduced a JSON configuration file for strategy definition with root, stock, and condition nodes.

## 2024-09-24

### Fixed

- Resolved issues in service tests, ensuring all tests pass successfully.

### Changed

- Updated imports to use `VectoriseBacktestService.Types` for improved consistency across modules.

## 2024-09-19

### Fixed

- Resolved API call errors in various functions to improve data retrieval and processing stability.

### Added

- Implemented new functions for handling stock data using Arrow and Parquet formats, enhancing data processing capabilities.
- Introduced utility functions for converting Parquet files to Arrow format and copying Parquet files.

### Changed

- Updated project dependencies and manifest to include new packages and versions for improved functionality.

## 2024-09-17

### Changed

- Updated CI configuration to utilize 'Ready to merge' label for triggering workflows.

## 2024-09-16

### Enhanced

- Improved modularity by integrating `Stock_Data.jl` into `AllocationNode.jl`.

### Documentation

- Added detailed test summaries and execution metrics to `Tests.md`.

## 2024-09-15

### Refactored

- Refactored code for improved modularity and readability, including changes to function names and structure.

## 2024-09-06

### Added

- Added current price to sort node functionality for enhanced sorting capabilities.

### Changed

- Multiplied cumulative return by 100 for percentage representation.
- Commented out certain tests in market cap tests for further review.

## 2024-09-04

### Added

- Introduced smoke tests for the backtesting layer to ensure basic functionality.
- Enhanced commit hooks to automate the handling of test documentation.
- Updated project dependencies and hash in the manifest file.

## 2024-09-08

### Enhanced

- Improved `process_branch` and `execute_backtest` functions to handle multiple nodes in sequences, increasing robustness of backtesting.

### Added

- New test cases to verify enhancements in handling multiple nodes in sequences.

### Changed

- Commented out certain test cases to focus on error handling and reduce test failures.

## 2024-09-05

### Added

- Introduced new routes for handling backtesting and technical analysis using Genie framework.
- Added startup script for dynamic thread allocation based on available CPU cores.

### Changed

- Updated server error responses to use status code 400 for improved error handling.
- Refactored code to remove unnecessary print statements and improve clarity.

### Fixed

- Resolved issues with cache handling and JSON file reading in stock data processing.

## 2024-09-03

### Fixed

- Resolved path issues in stock data retrieval functions to ensure correct file access.

## 2024-08-28

### Added

- Integrated `Parquet2.jl` for writing parquet files, replacing DuckDB for data storage.
- Updated environment with new package dependencies to support Parquet2 functionality.

### Fixed

- Adjusted tolerance levels in calculations to resolve allocation errors.

## 2024-08-28

### Fixed

- Updated expected values in unit tests to ensure accuracy and correctness.
- Renamed variables in tests for clarity and consistency.

## 2024-08-26

### Fixed

- Resolved NaN issue in stock weight calculations to ensure accurate daily return computations.

## 2024-08-24

### Fixed

- Addressed division by zero errors in portfolio value calculations to improve stability and accuracy.

## 2024-08-22

### Added

- Introduced new routes for technical analysis and backtesting services, enhancing API functionality.
- Added comprehensive unit tests for technical analysis functions to ensure robustness.
- Implemented error handling improvements across backtesting services.

### Changed

- Refactored backtesting service to improve modularity and maintainability.
- Enhanced logging and debugging capabilities in backtesting utilities.

## 2024-08-22

### Added

- Implemented new routes for TA_API and backtesting services in Julia.
- Added comprehensive unit tests for various technical analysis functions.
- Introduced error handling for server responses in backtesting services.
- Added scripts for generating test logs and handling stock ratio calculations.

### Changed

- Refactored backtesting service to include new functionalities and improve modularity.
- Updated Dockerfile to run the new server configuration.

## 2024-08-19

### Added

- Introduced unit tests for backtesting functions to ensure reliability and accuracy.
- Added Python scripts for stock ratio calculations and difference analysis in backtesting.
- Implemented new functions for calculating stock ratios and percentage differences.

### Changed

- Refactored and optimized various functions in backtesting utilities for improved performance.

## 2024-08-15

### Added

- Added support for additional sort functions in backtesting, including Moving Average of Price, Exponential Moving Average of Price, Cumulative Return, Max Drawdown, Moving Average of Return, Standard Deviation of Return, and Standard Deviation of Price.
- Introduced new helper functions to optimize performance and accuracy in backtesting calculations.

### Fixed

- Fixed calculation errors in cumulative returns and optimized standard deviation calculations for improved performance and accuracy.

## 2024-08-13

### Changed

- Switched CI/CD pipelines to use self-hosted runners instead of `ubuntu-latest`.

## 2024-08-07

### Added

- Included precompilation and instantiation commands in pre-commit hook and package installation script.
- Added missing tests for stock data and indicator functionalities.
- Introduced coverage reporting for `Stock_Data.jl`.

### Fixed

- Resolved errors in stock data and indicator tests.
- Corrected date handling in `calculate_inverse_volatility_for_stocks` function.

## 2024-08-19

### Added

- Implemented CircleCI configuration for automating the CI/CD pipeline.
- Integrated Discord notifications for job status updates.
- Defined jobs for environment setup, dependency checks, and code formatting.

## 2024-08-07

### Added

- Included precompilation and instantiation commands in pre-commit hook and package installation script.

### Changed

- Reordered and updated setup instructions for hooks in `README.md`.

## 2024-08-01

### Added

- Integrated all indicators into the backtest framework.
- Introduced local caching in `tree_return_curve` function to improve performance.
- Added error checking for various error types in pre-push checks.
- Implemented a new function to run flow and added timing macros for backtesting functions.
- Added serialization to TOML and caching mechanisms to speed up JSON processing.

### Fixed

- Resolved bug in `Jet-JuliaFormatter.py` that prevented script from picking up files.
- Fixed allocation weighting and sorting issues in backtesting service.
- Corrected errors in flow processing and removed unused `min_days` parameter.

### Changed

- Updated pre-push checks to exclude unit tests.
- Refactored variable naming and removed redundant parameters in `vec_backtest_service.jl`.
- Enhanced VSCode settings and ensured consistent formatting across all files.

## 2024-08-04

### Added

- Introduced new utility functions for project root detection and directory operations.
- Added local caching and serialization for JSON data to improve performance.
- Enhanced backtesting functions with additional indicators and error handling.
- Introduced `maybe_time` macro to conditionally enable timing in backtesting functions.
- Implemented new hooks to abort commit on failed tests.
- Added error handling and improved error messages for various functions.

### Fixed

- Fixed bugs in `Jet-JuliaFormatter.py` and allocation weighting issues.
- Corrected various minor bugs and updated settings.
- Fixed issues with fetching and processing stock data in backtesting functions.

## 2024-08-02

### Added

- Added error handling and improved error messages for various functions.
- Implemented new hooks to abort commit on failed tests.
- Introduced new utility functions for project root detection and directory operations.
- Added local caching and serialization for JSON data to improve performance.
- Enhanced backtesting functions with additional indicators and error handling.
- Introduced `maybe_time` macro to conditionally enable timing in backtesting functions.

### Fixed

- Fixed bugs in `Jet-JuliaFormatter.py` and allocation weighting issues.
- Corrected various minor bugs and updated settings.
- Fixed issues with fetching and processing stock data in backtesting functions.

## 2024-08-01

### Added

- Added all indicators in backtest.
- Introduced local caching in `tree_return_curve` function.
- Implemented error checking for all types of errors in pre-push checks.
- Added function to run flow and macro `maybe_time` to conditionally enable timing in backtesting functions.
- Added serialization to TOML and caching to speed up JSON processing.
- Introduced new hooks to abort commit on failed tests.

### Fixed

- Fixed bug in `Jet-JuliaFormatter.py` script.
- Corrected allocation weighting and sorting issues.
- Fixed various minor bugs and updated settings.

## 2024-07-15

### Added

- Introduced multiple new indicators for backtesting, including Cumulative Return, Exponential Moving Average of Price, Max Drawdown, Moving Average of Return, Standard Deviation of Return, and Standard Deviation of Price.
- Implemented local caching for various indicators to enhance performance.
- Updated the URL for the flow request in `live_execution.py` to use localhost and added a commented-out URL for the server.

## 2024-07-11

### Added

- Implemented global caching mechanism using hash values in backtesting.
- Updated backtest API to include `period` and `hash` parameters.
- Enhanced README with new example calls for backtest requests.

## 2024-06-27

### Added

- Completed implementation of Market Cap weighting in allocation nodes.
- Introduced `populate_dates` function to ensure date consistency.
- Added unit tests for Market Cap weighting functionality.

## 2024-06-26

### Added

- Introduced new functions for handling folders and icons in allocation nodes.
- Started work on Market Cap weighting in allocation nodes.
- Added utility scripts for fetching parquet files and extracting stock symbols.

### Fixed

- Fixed Dockerfile issues.
- Corrected allocation parsing bug.

### Changed

- Refactored stock data functions to remove redundant print statements and improve performance.

## 2024-06-22

### Added

- Implemented inverse volatility weighting in allocation nodes.
- Added `tree_return_curve` and updated `final_return_curve` for return calculations.
- Introduced new functions in `TA_Functions.jl` for daily returns and inverse volatility calculations.

### Fixed

- Fixed bug where all tickers were not being accounted for in weight calculations.
- Corrected weight calculation to multiply inverse volatility percentage instead of appending.

### Changed

- Refactored weight calculation by changing `weightAtLevel` to `weightTomorrow` for future weight calculations.

## 2024-06-14

### Changed

- Split the CI workflow into three separate jobs: `setup_and_check`, `tests`, and `format`.
- Updated Julia version to `1.10.2` in the `tests` and `format` jobs.
- Modified installation steps and dependencies in the CI configuration.

## 2024-06-13

### Added

- Added `make_sort_branches` function to handle branch extraction in sort nodes.
- Updated `process_sort_node` to utilize `make_sort_branches` for improved branch handling.

## 2024-06-11

### Changed

- Added a newline at the end of the `ta_functions_julia/README.md` file to adhere to formatting standards.

## 2024-06-09

### Added

- Introduced `Stock_Data_V2` module for enhanced stock data handling.
- Added `TA_Functions_V2` module for technical analysis indicators like RSI, SMA, and EMA.
- Included configuration module with API keys and constants.

### Fixed

- Fixed bugs related to indicator returns.

## 2024-06-02

### Changed

- Refactored backtest processing functions for performance optimization.
- Added detailed comments and review notes to improve code clarity and future development.

## 2024-05-30

### Added

- Introduced new vectorized backtesting functionality.
- Added allocation calculation and sorting logic.
- Implemented parallelized sorting for improved performance.

## 2024-06-01

### Added

- SIMD-based comparison functions for performance enhancement.
- Unit tests for SIMD-based comparison functions.
- JET.jl script for static analysis and error checking.

### Changed

- Refactored configuration constants into a module for better encapsulation.
- Enhanced error handling and logging in various functions.

## 2024-05-27

### Added

- Comprehensive unit tests for various stock data retrieval and processing functions.
- Logging of execution times and test summaries to 'execution_times.txt'.

### Changed

- Updated API URL for live data retrieval.
- Minor formatting enhancement in the README documentation.

### Fixed

- Included a TODO note for a necessary bug fix in the `find_previous_business_day` function.
