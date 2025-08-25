# SmallStrategy Test Runner for PowerShell
Write-Host "================================================================================" -ForegroundColor Green
Write-Host "SMALLSTRATEGY.JSON TEST SUITE" -ForegroundColor Green  
Write-Host "================================================================================" -ForegroundColor Green
Write-Host ""

Write-Host "Changing to App directory..." -ForegroundColor Yellow
Set-Location App

Write-Host ""
Write-Host "Running SmallStrategy test suite..." -ForegroundColor Yellow

# Method 1: Try running the comprehensive test runner
Write-Host "Method 1: Running RunSmallStrategyTests.jl..." -ForegroundColor Cyan
$testFile = "Tests/RunSmallStrategyTests.jl"
if (Test-Path $testFile) {
    julia --project=. $testFile
} else {
    Write-Host "Test file not found: $testFile" -ForegroundColor Red
}

Write-Host ""
Write-Host "Alternative: Running SmallStrategy Integration Test..." -ForegroundColor Cyan

# Method 2: Try running the integration test
$integrationTest = "Tests/SmallStrategyIntegrationTest.jl"
if (Test-Path $integrationTest) {
    julia --project=. $integrationTest
} else {
    Write-Host "Integration test not found: $integrationTest" -ForegroundColor Red
}

Write-Host ""
Write-Host "Test execution completed." -ForegroundColor Green
Write-Host "Press any key to continue..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")