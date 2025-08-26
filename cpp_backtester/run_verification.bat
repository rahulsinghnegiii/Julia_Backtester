@echo off
echo Running SmallStrategy Verification...
echo ======================================

.\build\small_strategy_validator.exe > verification_output.txt 2>&1

echo.
echo Verification completed. Output saved to verification_output.txt
echo.
echo Displaying results:
echo ======================================
type verification_output.txt

echo.
echo ======================================
echo Verification complete. Check verification_output.txt for full details.
pause
