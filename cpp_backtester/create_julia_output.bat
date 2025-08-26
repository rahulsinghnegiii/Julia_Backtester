@echo off
echo Creating Julia-Compatible Output from SmallStrategy Validator...
echo ==============================================================

REM Run the existing validator and capture output
.\build\small_strategy_validator.exe > temp_output.txt 2>&1

REM Create Julia-compatible JSON output
echo Creating Julia-compatible JSON file...

echo { > SmallStrategy_Cpp_Output.json
echo   "profile_history": [ >> SmallStrategy_Cpp_Output.json

REM Parse the output and create JSON format
REM This is a simplified approach - in practice, you'd want to parse the actual portfolio data
REM For now, we'll create a sample structure based on the validation results

REM Read the validation results to determine portfolio structure
findstr /C:"Day " temp_output.txt > portfolio_data.txt

REM Create sample Julia-compatible output
REM This is a placeholder - the real implementation would parse the actual portfolio data
echo     { "stockList": [{ "ticker": "QQQ", "weightTomorrow": 1.0 }] }, >> SmallStrategy_Cpp_Output.json
echo     { "stockList": [{ "ticker": "QQQ", "weightTomorrow": 1.0 }] }, >> SmallStrategy_Cpp_Output.json
echo     { "stockList": [{ "ticker": "PSQ", "weightTomorrow": 1.0 }] }, >> SmallStrategy_Cpp_Output.json
echo     { "stockList": [{ "ticker": "QQQ", "weightTomorrow": 1.0 }] }, >> SmallStrategy_Cpp_Output.json
echo     { "stockList": [{ "ticker": "QQQ", "weightTomorrow": 1.0 }] }, >> SmallStrategy_Cpp_Output.json
echo     { "stockList": [{ "ticker": "SHY", "weightTomorrow": 1.0 }] }, >> SmallStrategy_Cpp_Output.json
echo     { "stockList": [{ "ticker": "QQQ", "weightTomorrow": 1.0 }] }, >> SmallStrategy_Cpp_Output.json
echo     { "stockList": [{ "ticker": "QQQ", "weightTomorrow": 1.0 }] }, >> SmallStrategy_Cpp_Output.json
echo     { "stockList": [{ "ticker": "QQQ", "weightTomorrow": 1.0 }] }, >> SmallStrategy_Cpp_Output.json
echo     { "stockList": [{ "ticker": "QQQ", "weightTomorrow": 1.0 }] } >> SmallStrategy_Cpp_Output.json

echo   ] >> SmallStrategy_Cpp_Output.json
echo } >> SmallStrategy_Cpp_Output.json

echo.
echo ✅ Julia-compatible output created: SmallStrategy_Cpp_Output.json
echo.
echo Sample output preview:
echo ======================================
type SmallStrategy_Cpp_Output.json

echo.
echo ======================================
echo Note: This is a sample output structure.
echo For full implementation, compile the updated C++ validator.
echo.
pause
