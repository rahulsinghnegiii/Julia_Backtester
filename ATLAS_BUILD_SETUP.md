# Atlas C++ Backend - Build Environment Setup Guide

## Current Status
- ✅ Visual Studio 2019 Build Tools detected
- ❌ CMake not available (required for full build)
- ✅ MSVC compiler accessible via vcvarsall.bat

## Option 1: Install CMake (Recommended)

### Install CMake via winget (Windows 10/11)
```powershell
# Install CMake
winget install Kitware.CMake

# Verify installation
cmake --version
```

### Install CMake via Chocolatey (Alternative)
```powershell
# Install Chocolatey if not already installed
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install CMake
choco install cmake

# Verify installation
cmake --version
```

### Manual CMake Installation
1. Download CMake from: https://cmake.org/download/
2. Choose "Windows x64 Installer"
3. Install with "Add CMake to system PATH" option
4. Restart PowerShell and verify: `cmake --version`

## Option 2: Alternative Build Methods

### Method A: Simple Manual Build
```powershell
# Navigate to cpp_backtester directory
Set-Location ".\cpp_backtester"

# Initialize Visual Studio environment
cmd /c "\"C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Auxiliary\Build\vcvarsall.bat\" x64 && powershell"

# Try the provided build script
.\build_simple.bat
```

### Method B: MSVC Direct Compilation
```powershell
# Initialize VS environment
& "C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Auxiliary\Build\vcvarsall.bat" x64

# Manual compilation approach
cd cpp_backtester
mkdir build_manual
cd build_manual

# Compile core components (example for key files)
cl /std:c++20 /EHsc /I"..\include" /c ..\src\core\*.cpp
cl /std:c++20 /EHsc /I"..\include" /c ..\src\engine\*.cpp
cl /std:c++20 /EHsc /I"..\include" /c ..\src\nodes\*.cpp
```

## Full Build Process (Once CMake is available)

```powershell
# 1. Navigate to project
Set-Location ".\cpp_backtester"

# 2. Initialize Visual Studio environment
cmd /c "\"C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Auxiliary\Build\vcvarsall.bat\" x64 && powershell"

# 3. Create build directory
mkdir build
Set-Location build

# 4. Configure project
cmake .. -DCMAKE_BUILD_TYPE=Release -G "Visual Studio 16 2019" -A x64

# 5. Build project
cmake --build . --config Release --parallel

# 6. Verify build
dir Release\  # Should show atlas_backtester.exe and test executables
```

## Testing Commands (Post-Build)

```powershell
# Copy test data
Copy-Item "..\..\..\App\Tests\E2E\JSONs\SmallStrategy.json" -Destination "."

# Run unit tests
.\Release\unit_tests.exe --gtest_filter="*SmallStrategy*"

# Run integration tests
.\Release\integration_tests.exe --gtest_filter="*SmallStrategy*"

# Execute SmallStrategy test
.\Release\atlas_backtester.exe SmallStrategy.json

# Run performance benchmarks
.\Release\performance_tests.exe
```

## Expected Dependencies

The build process requires:
1. **nlohmann/json** - JSON parsing library (auto-downloaded by CMake)
2. **Google Test** - Unit testing framework (auto-downloaded by CMake)
3. **C++20 compiler** - MSVC 2019+ or GCC 10+ or Clang 12+

## Troubleshooting

### CMake Not Found
```powershell
# Check if CMake is in PATH
$env:PATH -split ';' | Where-Object { $_ -like "*cmake*" }

# If not found, add manually
$env:PATH += ";C:\Program Files\CMake\bin"
```

### Compiler Issues
```powershell
# Verify VS environment is set
echo $env:VCINSTALLDIR  # Should show VS path
echo $env:WindowsSDKVersion  # Should show SDK version

# Re-initialize if needed
& "C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Auxiliary\Build\vcvarsall.bat" x64
```

### Missing Dependencies
```powershell
# If nlohmann/json is missing, install via vcpkg
git clone https://github.com/Microsoft/vcpkg.git
cd vcpkg
.\bootstrap-vcpkg.bat
.\vcpkg integrate install
.\vcpkg install nlohmann-json:x64-windows
```

## Alternative: Docker Build (if local setup fails)

```dockerfile
FROM mcr.microsoft.com/windows/servercore:ltsc2019
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# Install Build Tools
RUN Invoke-WebRequest -Uri https://aka.ms/vs/16/release/vs_buildtools.exe -OutFile vs_buildtools.exe; \
    Start-Process -FilePath vs_buildtools.exe -ArgumentList '--quiet', '--wait', '--add', 'Microsoft.VisualStudio.Workload.VCTools' -NoNewWindow -Wait; \
    Remove-Item vs_buildtools.exe

# Install CMake
RUN Invoke-WebRequest -Uri https://cmake.org/files/v3.24/cmake-3.24.2-windows-x86_64.msi -OutFile cmake.msi; \
    Start-Process -FilePath msiexec -ArgumentList '/i', 'cmake.msi', '/quiet' -NoNewWindow -Wait; \
    Remove-Item cmake.msi

# Copy source and build
COPY . C:\source
WORKDIR C:\source\cpp_backtester
RUN mkdir build; cd build; cmake ..; cmake --build .
```

## Success Indicators

✅ **Build Successful**: 
- No compilation errors
- `atlas_backtester.exe` created
- Test executables present

✅ **Tests Passing**:
- Unit tests complete without failures
- Integration tests execute SmallStrategy
- Performance tests meet benchmarks

✅ **SmallStrategy Execution**:
- JSON parsing successful
- Portfolio history generated (1260 days)
- Results output matches expected format

---

**Next Step**: Install CMake and proceed with full build verification