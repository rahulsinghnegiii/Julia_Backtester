import os
import stat

# Define hook content
pre_push_content = """#!/bin/bash

# Get the list of files that are being pushed, excluding deleted files
files=$(git diff-tree --no-commit-id --name-only --diff-filter=d -r HEAD)

# Debug: Print the list of files
echo "Debug: Files to be pushed: $files"

# Run the Julia script with the list of files
julia --project=./App "./Scripts/Types&ErrorCheck/PrePushCheck.jl" $files

# Check the exit status of the Julia script
if [ $? -ne 0 ]; then
    echo "Pre-push hook failed. Aborting push."
    message="PrePushCheck.jl found type issues"
    if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" || "$OSTYPE" == "windows" ]]; then
        # Windows
        echo "Windows"
        powershell.exe -Command "Add-Type -AssemblyName PresentationFramework; [System.Windows.MessageBox]::Show('$message')"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        echo "macOS"
        osascript -e "tell app \\"System Events\\" to display dialog \\"$message\\" buttons {\\"OK\\"} default button \\"OK\\" with title \\"Error\\""
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        echo "Linux"
        if ! command -v zenity &> /dev/null; then
            echo "zenity could not be found. Installing zenity..."
            sudo apt-get update && sudo apt-get install -y zenity
        fi
        zenity --error --text="$message"
    else
        echo "Unsupported OS: $OSTYPE"
        exit 1
    fi
    exit 1
fi
"""

pre_commit_content = """#!/bin/bash
# Format julia files
julia --project=./App -e 'using Pkg; Pkg.activate("./App"); Pkg.precompile(); Pkg.instantiate();'
julia --project=./App ./Scripts/Formatter/FilesFormatter.jl
"""

def create_test_snippet(testname: str, testfilepath: str):
    return (f"""
rm -rf SubtreeCache/
rm -rf Cache/
rm -rf IndicatorData/

mkdir SubtreeCache
mkdir SubtreeCache/SyntheticReturns
mkdir Cache
mkdir IndicatorData

echo "----- {testname} Tests -----" >> "$commit_msg_file"
echo "### {testname} Tests" >> "$test_output_file"
julia_output=$(julia --project=./App {testfilepath})
julia_exit_status=$?

echo "$julia_output" >> "$test_output_file"
if [ $julia_exit_status -ne 0 ]; then
    echo "Aborting push: {testname} Tests failed."
    exit 1
fi
    """)

def generate_prepare_commit_msg_content():
    return f"""#!/bin/bash

# File passed to the script as the first argument
commit_msg_file=$1

# Check if the commit message contains the Tests.md commit message
if grep -q "tests: Add weekly test report" "$commit_msg_file"; then
    exit 0
fi

# Create test reports directory if it doesn't exist
test_reports_dir="TestReports"
mkdir -p "$test_reports_dir"

# Get the current timestamp
current_timestamp=$(date "+%Y-%m-%d")

# Initialize the test output file path variable
test_output_file=""

# Find the most recent test report file
most_recent_file=$(ls -t "$test_reports_dir"/tests_*.md 2>/dev/null | head -n 1)

if [ -z "$most_recent_file" ]; then
    # No existing test report files, create a new one
    test_output_file="$test_reports_dir/tests_$current_timestamp.md"
    echo "Creating new weekly test report: $test_output_file"
else
    # Extract timestamp from the most recent file
    filename=$(basename "$most_recent_file")
    file_timestamp=$(echo "$filename" | sed -E 's/tests_([0-9-]+)\\.md/\\1/')
    
    # Calculate days between file timestamp and current timestamp
    days_diff=$(( ( $(date -d "$current_timestamp" +%s) - $(date -d "$file_timestamp" +%s) ) / 86400 ))
    
    if [ "$days_diff" -gt 7 ]; then
        # More than a week has passed, create a new file
        test_output_file="$test_reports_dir/tests_$current_timestamp.md"
        echo "Creating new weekly test report: $test_output_file"
    else
        # Use the existing file for this week
        test_output_file="$most_recent_file"
        echo "Appending to existing weekly test report: $test_output_file"
    fi
fi

{create_test_snippet("GlobalLRUCache", "./App/Tests/UnitTests/GlobalLRUCacheTest.jl")}

echo "Running API tests..."
python ./App/Tests/E2E/SubtreeComparator.py

# Check the exit status of the Python script
if [ $? -ne 0 ]; then
    echo "Pre-commit hook failed: API tests failed"
    message="API tests failed. Check the test output for details."
    if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" || "$OSTYPE" == "windows" ]]; then
        # Windows
        powershell.exe -Command "Add-Type -AssemblyName PresentationFramework; [System.Windows.MessageBox]::Show('$message')"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        osascript -e "tell app \\"System Events\\" to display dialog \\"$message\\" buttons \\"OK\\" default button \\"OK\\" with title \\"Error\\""
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        if ! command -v zenity &> /dev/null; then
            echo "zenity could not be found. Installing zenity..."
            sudo apt-get update && sudo apt-get install -y zenity
        fi
        zenity --error --text="$message"
    else
        echo "Unsupported OS: $OSTYPE"
        exit 1
    fi
    exit 1
fi

# Get the current date and time
current_datetime=$(date "+%Y-%m-%d %H:%M:%S")

# Append start test section to commit message and output file
echo "-----------------------" >> "$commit_msg_file"
echo "----- Start Tests -----" >> "$commit_msg_file"
echo "## $current_datetime" >> "$test_output_file"



echo "----- Node Tests -----" >> "$commit_msg_file"
echo "### Node Tests" >> "$test_output_file"

{create_test_snippet("Allocation Node", "./App/Tests/NodeTests/AllocationNodeTest.jl")}
{create_test_snippet("Conditional Node", "./App/Tests/NodeTests/ConditionalNodeTest.jl")}
{create_test_snippet("LockOnTrigger Node", "./App/Tests/NodeTests/LockOnTriggerNodeTest.jl")}
{create_test_snippet("Sort Node", "./App/Tests/NodeTests/SortNodeTest.jl")}
{create_test_snippet("Stock Node", "./App/Tests/NodeTests/StockNodeTest.jl")}
{create_test_snippet("Cloud Node", "./App/Tests/NodeTests/CloudNodeTest.jl")}

echo "----- Smoke Tests ----- " >> "$commit_msg_file"
echo "### Smoke Tests" >> "$test_output_file"

{create_test_snippet("API", "./App/Tests/SmokeTests/APITests.jl")}
{create_test_snippet("SyntheticStock", "./App/Tests/SmokeTests/SyntheticStockTests.jl")}
{create_test_snippet("OneDayRun", "./App/Tests/SmokeTests/OneDayRun/TestOneDayRun.jl")}
{create_test_snippet("Ignore Comment", "./App/Tests/SmokeTests/IgnoreCommentTest.jl")}
{create_test_snippet("Return Ticker Dates", "./App/Tests/SmokeTests/ReturnTickerDatesTest.jl")}
{create_test_snippet("Strategy with Everything", "./App/Tests/SmokeTests/TimeComparisonTest.jl")}

echo "----- Unit Tests -----" >> "$commit_msg_file"
echo "### Unit Tests" >> "$test_output_file"

{create_test_snippet("SmallStrategy", "./App/Tests/UnitTests/SmallStrategyTest.jl")}
{create_test_snippet("BacktestService", "./App/Tests/UnitTests/BacktestServiceTests.jl")}
{create_test_snippet("Backtest", "./App/Tests/UnitTests/BacktestTests.jl")}
{create_test_snippet("FlowMap", "./App/Tests/UnitTests/FlowMapTests.jl")}
{create_test_snippet("MetaData", "./App/Tests/UnitTests/MetaDataTests.jl")}
{create_test_snippet("SIMD", "./App/Tests/UnitTests/SIMDTests.jl")}
{create_test_snippet("StockData", "./App/Tests/UnitTests/StockDataTests.jl")}
{create_test_snippet("SubTreeCache", "./App/Tests/UnitTests/SubTreeCacheTest.jl")}
{create_test_snippet("TAFunctions", "./App/Tests/UnitTests/TAFunctionsTests.jl")}

# Read the commit message file's content
commit_msg_content=$(cat "$commit_msg_file")

# Commit the test report and add the original commit message in the description
git add "$test_output_file"
git commit -m "$commit_msg_content" -m "tests: Add weekly test report"
"""

prepare_commit_msg_content = generate_prepare_commit_msg_content()

def create_hook(hook_path, content):
    with open(hook_path, 'w') as f:
        f.write(content)
    # Make the hook executable
    st = os.stat(hook_path)
    os.chmod(hook_path, st.st_mode | stat.S_IEXEC)

def main():
    # Define hook paths
    pre_push_path = './.git/hooks/pre-push'
    pre_commit_path = './.git/hooks/pre-commit'
    prepare_commit_msg_path = "./.git/hooks/prepare-commit-msg"

    # Check and create pre-push hook
    if os.path.exists(pre_push_path):
        print("Pre-push hook already exists. Deleting and creating new hook...")
        os.remove(pre_push_path)
    else:
        print("Creating pre-push hook...")
    create_hook(pre_push_path, prepare_commit_msg_content)

    # Check and create pre-commit hook
    if os.path.exists(pre_commit_path):
        print("Pre-commit hook already exists. Deleting and creating new hook...")
        os.remove(pre_commit_path)
    else:
        print("Creating pre-commit hook...")
    create_hook(pre_commit_path, pre_commit_content)

    # Create initial TestReports directory if it doesn't exist
    reports_dir = "./TestReports"
    if not os.path.exists(reports_dir):
        print(f"Creating TestReports directory at {reports_dir}...")
        os.makedirs(reports_dir)

if __name__ == "__main__":
    main()