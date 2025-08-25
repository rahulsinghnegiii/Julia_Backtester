@echo off
echo ================================================================================
echo SMALLSTRATEGY.JSON TEST SUITE
echo ================================================================================
echo.

echo Changing to App directory...
cd App

echo.
echo Running SmallStrategy tests with Julia...
julia --project=. -e "include(\"Tests/RunSmallStrategyTests.jl\")"

echo.
echo Test execution completed.
pause