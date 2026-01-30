@echo off
REM Extract ostress.exe from RMLSetup.msi
REM Run this from the tools directory

echo ================================================================
echo   Extracting ostress.exe from RML Utilities
echo ================================================================
echo.

cd /d "%~dp0"

if not exist "RMLSetup.msi" (
    echo ERROR: RMLSetup.msi not found!
    echo Please ensure RMLSetup.msi is in this directory.
    pause
    exit /b 1
)

echo [1/5] Extracting MSI contents...
msiexec /a "%CD%\RMLSetup.msi" /qn TARGETDIR="%CD%\extracted"
if errorlevel 1 (
    echo ERROR: Failed to extract MSI
    pause
    exit /b 1
)

echo [2/5] Waiting for extraction to complete...
timeout /t 10 /nobreak >nul

echo [3/5] Copying ostress.exe...
copy "extracted\Program Files\Microsoft Corporation\RMLUtils\ostress.exe" . /Y
copy "extracted\Program Files\Microsoft Corporation\RMLUtils\RMLUtils.dll" . /Y
copy "extracted\Program Files\Microsoft Corporation\RMLUtils\ostress.pdb" . /Y 2>nul

echo [4/5] Cleaning up...
rmdir /s /q extracted
del RMLSetup.msi

echo [5/5] Unblocking files...
powershell -Command "Get-ChildItem '*.exe','*.dll' | Unblock-File"

echo.
echo ================================================================
echo   EXTRACTION COMPLETE
echo ================================================================
echo.
echo Bundled files:
dir ostress.exe RMLUtils.dll 2>nul
echo.
echo Testing ostress.exe...
ostress.exe -? 2>nul
if errorlevel 1 (
    echo.
    echo WARNING: ostress.exe test failed
    echo You may need Visual C++ Redistributables
) else (
    echo.
    echo SUCCESS: ostress.exe is working!
)

echo.
echo Next steps:
echo   1. Commit to repository: git add *.exe *.dll
echo   2. Test /testscript skill
echo.
pause
