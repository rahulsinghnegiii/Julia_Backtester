@echo off
REM Simple build script for Atlas Backtesting Engine
REM This script compiles the core components for basic testing

echo Atlas Backtesting Engine - Simple Build
echo ==========================================

REM Check for C++ compiler
where g++ >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Error: g++ compiler not found in PATH
    echo Please install MinGW-w64 or similar C++ compiler
    pause
    exit /b 1
)

echo Found g++ compiler

REM Create build directory
if not exist \"build_simple\" mkdir build_simple
cd build_simple

echo.
echo Compiling Atlas core components...

REM Compile core types
g++ -c -std=c++20 -I\"../include\" -O2 ../src/core/stock_info.cpp -o stock_info.o
if %ERRORLEVEL% NEQ 0 goto :error

g++ -c -std=c++20 -I\"../include\" -O2 ../src/core/day_data.cpp -o day_data.o
if %ERRORLEVEL% NEQ 0 goto :error

g++ -c -std=c++20 -I\"../include\" -O2 ../src/core/cache_data.cpp -o cache_data.o
if %ERRORLEVEL% NEQ 0 goto :error

g++ -c -std=c++20 -I\"../include\" -O2 ../src/core/subtree_context.cpp -o subtree_context.o
if %ERRORLEVEL% NEQ 0 goto :error

g++ -c -std=c++20 -I\"../include\" -O2 ../src/core/types.cpp -o types.o
if %ERRORLEVEL% NEQ 0 goto :error

echo Core types compiled successfully

REM Compile node processors
g++ -c -std=c++20 -I\"../include\" -O2 ../src/nodes/node_processor.cpp -o node_processor.o
if %ERRORLEVEL% NEQ 0 goto :error

g++ -c -std=c++20 -I\"../include\" -O2 ../src/nodes/stock_node.cpp -o stock_node.o
if %ERRORLEVEL% NEQ 0 goto :error

echo Node processors compiled successfully

REM Note: Engine compilation requires nlohmann/json header
echo.
echo Note: Complete compilation requires nlohmann/json library
echo Core components compiled successfully!
echo.
echo To complete the build:
echo 1. Install nlohmann/json library
echo 2. Use CMake for full build: cmake .. && cmake --build .
echo 3. Or manually link with: g++ -std=c++20 -I../include *.o ../src/engine/*.cpp ../src/main.cpp

goto :success

:error
echo.
echo Build failed! Check compiler errors above.
pause
exit /b 1

:success
echo.
echo Build completed successfully!
cd ..
pause", "original_text": "", "replace_all": false}]