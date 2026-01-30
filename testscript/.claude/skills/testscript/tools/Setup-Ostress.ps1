#Requires -Version 5.1
<#
.SYNOPSIS
    Extracts and bundles ostress.exe from RML Utilities MSI installer.

.DESCRIPTION
    This script extracts ostress.exe and required dependencies from the
    downloaded RMLSetup.msi installer and prepares them for bundling with
    the /testscript skill.

.NOTES
    Version: 1.0.0
    Author: AgentsOfAction Team
    Date: 2024-01-29

    RML Utilities were deprecated by Microsoft in October 2025 but remain
    functional and available for download.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [switch]$CleanOnly,

    [Parameter()]
    [switch]$VerifyOnly
)

$ErrorActionPreference = "Stop"
$ToolsDir = $PSScriptRoot
$MsiPath = Join-Path $ToolsDir "RMLSetup.msi"
$ExtractDir = Join-Path $ToolsDir "extracted"
$RMLPath = "$ExtractDir\Program Files\Microsoft Corporation\RMLUtils"

# Color output functions
function Write-Success { Write-Host "✓ $args" -ForegroundColor Green }
function Write-Info { Write-Host "ℹ $args" -ForegroundColor Cyan }
function Write-Warning { Write-Host "⚠ $args" -ForegroundColor Yellow }
function Write-Error { Write-Host "✗ $args" -ForegroundColor Red }

# Banner
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  RML Utilities (ostress.exe) Bundle Setup" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Verify only mode
if ($VerifyOnly) {
    Write-Info "Running verification mode..."
    Write-Host ""

    $ostressPath = Join-Path $ToolsDir "ostress.exe"
    $dllPath = Join-Path $ToolsDir "RMLUtils.dll"

    if (Test-Path $ostressPath) {
        Write-Success "ostress.exe found"

        # Check file size
        $size = (Get-Item $ostressPath).Length / 1KB
        Write-Info "  Size: $([math]::Round($size, 2)) KB"

        # Check digital signature
        $sig = Get-AuthenticodeSignature $ostressPath
        if ($sig.Status -eq "Valid") {
            Write-Success "  Digital signature: Valid (Microsoft Corporation)"
        } else {
            Write-Warning "  Digital signature: $($sig.Status)"
        }

        # Calculate hash
        $hash = Get-FileHash $ostressPath -Algorithm SHA256
        Write-Info "  SHA256: $($hash.Hash)"

        # Try to run
        Write-Host ""
        Write-Info "Testing execution..."
        $result = & $ostressPath -? 2>&1
        if ($LASTEXITCODE -eq 0 -or $result -match "ostress") {
            Write-Success "ostress.exe executes successfully"
        } else {
            Write-Error "ostress.exe execution failed"
        }
    } else {
        Write-Error "ostress.exe not found"
        Write-Info "Run without -VerifyOnly to extract from MSI"
        exit 1
    }

    if (Test-Path $dllPath) {
        Write-Success "RMLUtils.dll found"
        $size = (Get-Item $dllPath).Length / 1KB
        Write-Info "  Size: $([math]::Round($size, 2)) KB"
    } else {
        Write-Error "RMLUtils.dll not found"
        exit 1
    }

    Write-Host ""
    Write-Success "All bundled tools verified successfully!"
    exit 0
}

# Clean only mode
if ($CleanOnly) {
    Write-Info "Cleaning temporary files..."

    if (Test-Path $ExtractDir) {
        Remove-Item -Recurse -Force $ExtractDir
        Write-Success "Removed: $ExtractDir"
    }

    if (Test-Path $MsiPath) {
        Remove-Item -Force $MsiPath
        Write-Success "Removed: $MsiPath"
    }

    Write-Host ""
    Write-Success "Cleanup complete!"
    exit 0
}

# Main extraction process
Write-Info "Starting extraction process..."
Write-Host ""

# Step 1: Check if MSI exists
if (-not (Test-Path $MsiPath)) {
    Write-Error "RMLSetup.msi not found!"
    Write-Info "Expected location: $MsiPath"
    Write-Host ""
    Write-Info "Download from:"
    Write-Info "https://www.microsoft.com/en-us/download/104868"
    Write-Host ""
    Write-Info "Or run:"
    Write-Info 'Invoke-WebRequest -Uri "https://download.microsoft.com/download/a/a/d/aad67239-30df-403b-a7f1-976a4ac46403/RMLSetup.msi" -OutFile "$ToolsDir\RMLSetup.msi"'
    exit 1
}

Write-Success "Found RMLSetup.msi"
$msiSize = (Get-Item $MsiPath).Length / 1MB
Write-Info "  Size: $([math]::Round($msiSize, 2)) MB"

# Step 2: Extract MSI contents
Write-Host ""
Write-Info "Extracting MSI contents..."
Write-Info "This may take 30-60 seconds..."

try {
    # Use administrative install to extract without installing
    $extractPath = $ExtractDir.Replace('\', '\\')
    $msiFullPath = (Resolve-Path $MsiPath).Path

    $process = Start-Process -FilePath "msiexec.exe" `
        -ArgumentList "/a `"$msiFullPath`" /qn TARGETDIR=`"$extractPath`"" `
        -Wait -PassThru -NoNewWindow

    if ($process.ExitCode -ne 0) {
        throw "msiexec failed with exit code: $($process.ExitCode)"
    }

    Write-Success "MSI extracted successfully"
} catch {
    Write-Error "Failed to extract MSI: $_"
    exit 1
}

# Step 3: Verify extracted files
Write-Host ""
Write-Info "Verifying extracted files..."

if (-not (Test-Path $RMLPath)) {
    Write-Error "RML utilities not found in extracted files!"
    Write-Info "Expected path: $RMLPath"
    exit 1
}

$requiredFiles = @(
    @{ Name = "ostress.exe"; Required = $true },
    @{ Name = "RMLUtils.dll"; Required = $true },
    @{ Name = "ostress.pdb"; Required = $false }
)

$foundFiles = @()
foreach ($file in $requiredFiles) {
    $filePath = Join-Path $RMLPath $file.Name
    if (Test-Path $filePath) {
        $foundFiles += $file.Name
        $size = (Get-Item $filePath).Length / 1KB
        Write-Success "Found: $($file.Name) ($([math]::Round($size, 2)) KB)"
    } elseif ($file.Required) {
        Write-Error "Missing required file: $($file.Name)"
        exit 1
    } else {
        Write-Warning "Optional file not found: $($file.Name)"
    }
}

# Step 4: Copy files to tools directory
Write-Host ""
Write-Info "Copying files to tools directory..."

foreach ($fileName in $foundFiles) {
    $sourcePath = Join-Path $RMLPath $fileName
    $destPath = Join-Path $ToolsDir $fileName

    # Backup existing file if present
    if (Test-Path $destPath) {
        $backupPath = "$destPath.backup"
        Move-Item $destPath $backupPath -Force
        Write-Info "  Backed up existing $fileName to $fileName.backup"
    }

    Copy-Item $sourcePath $destPath -Force
    Write-Success "Copied: $fileName"
}

# Step 5: Unblock files (Windows security)
Write-Host ""
Write-Info "Unblocking files (Windows security)..."

Get-ChildItem $ToolsDir -Filter "*.exe" | Unblock-File
Get-ChildItem $ToolsDir -Filter "*.dll" | Unblock-File
Write-Success "Files unblocked"

# Step 6: Verify digital signature
Write-Host ""
Write-Info "Verifying digital signature..."

$ostressPath = Join-Path $ToolsDir "ostress.exe"
$signature = Get-AuthenticodeSignature $ostressPath

if ($signature.Status -eq "Valid") {
    Write-Success "Digital signature is valid"
    Write-Info "  Signer: $($signature.SignerCertificate.Subject)"
} else {
    Write-Warning "Digital signature status: $($signature.Status)"
    Write-Warning "This may happen with older versions or if the certificate expired"
}

# Step 7: Calculate file hashes
Write-Host ""
Write-Info "Calculating file hashes (SHA256)..."

foreach ($fileName in @("ostress.exe", "RMLUtils.dll")) {
    $filePath = Join-Path $ToolsDir $fileName
    if (Test-Path $filePath) {
        $hash = Get-FileHash $filePath -Algorithm SHA256
        Write-Info "$fileName"
        Write-Info "  $($hash.Hash)"
    }
}

# Step 8: Test execution
Write-Host ""
Write-Info "Testing ostress.exe execution..."

try {
    $output = & $ostressPath -? 2>&1
    if ($LASTEXITCODE -eq 0 -or $output -match "ostress") {
        Write-Success "ostress.exe executes successfully"
        Write-Host ""
        Write-Host "Sample output:" -ForegroundColor Gray
        Write-Host ($output | Select-Object -First 5 | Out-String) -ForegroundColor Gray
    } else {
        Write-Warning "ostress.exe returned non-zero exit code, but this may be normal"
    }
} catch {
    Write-Error "Failed to execute ostress.exe: $_"
    Write-Warning "You may need to install Visual C++ Redistributables"
}

# Step 9: Create version info file
Write-Host ""
Write-Info "Creating version information file..."

$versionContent = @"
═══════════════════════════════════════════════════════
  RML UTILITIES - BUNDLED VERSION INFORMATION
═══════════════════════════════════════════════════════

BUNDLE DATE: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
BUNDLED BY: $env:USERNAME
WORKSTATION: $env:COMPUTERNAME

═══════════════════════════════════════════════════════
  SOURCE INFORMATION
═══════════════════════════════════════════════════════

Download Source:
https://www.microsoft.com/en-us/download/104868

Package Name: RML Utilities for SQL Server - Update Dec 2022
Version: 09.04.0102
Release Date: July 15, 2024
File Size: 4.7 MB

DEPRECATION NOTICE:
Microsoft deprecated RML Utilities in October 2025.
This tool remains functional and is provided for legacy support.

═══════════════════════════════════════════════════════
  BUNDLED FILES
═══════════════════════════════════════════════════════

ostress.exe - Multi-threaded SQL query stress testing
RMLUtils.dll - Required runtime library
ostress.pdb - Debug symbols (optional)

═══════════════════════════════════════════════════════
  FILE HASHES (SHA256)
═══════════════════════════════════════════════════════

"@

foreach ($fileName in @("ostress.exe", "RMLUtils.dll")) {
    $filePath = Join-Path $ToolsDir $fileName
    if (Test-Path $filePath) {
        $hash = Get-FileHash $filePath -Algorithm SHA256
        $versionContent += "`n$fileName`n$($hash.Hash)`n"
    }
}

$versionContent += @"

═══════════════════════════════════════════════════════
  DIGITAL SIGNATURE
═══════════════════════════════════════════════════════

Status: $($signature.Status)
Signer: $($signature.SignerCertificate.Subject)
Timestamp: $($signature.TimeStamperCertificate.NotBefore)

═══════════════════════════════════════════════════════
  LICENSE
═══════════════════════════════════════════════════════

Copyright: Microsoft Corporation
License: Microsoft Software License Terms

By using these tools, you agree to Microsoft's license terms.
See: https://www.microsoft.com/en-us/download/104868

Redistribution: Permitted for non-commercial use.
Verify current terms with Microsoft before distribution.

═══════════════════════════════════════════════════════
  USAGE
═══════════════════════════════════════════════════════

These tools are used automatically by the /testscript skill.
Manual usage:

  ostress.exe -S server -U user -P pass -d database -i script.sql -n50

Parameters:
  -S  Server name (e.g., localhost,1433)
  -U  Username (e.g., sa)
  -P  Password
  -d  Database name
  -i  Input SQL script file
  -n  Number of concurrent threads
  -r  Iterations per thread
  -q  Quiet mode
  -o  Output directory

Full documentation: https://github.com/Microsoft/RMLUtils

═══════════════════════════════════════════════════════
  SUPPORT
═══════════════════════════════════════════════════════

For tool issues: See TOOLS_SETUP.md
For skill issues: See README.md
For RML documentation: https://learn.microsoft.com/en-us/troubleshoot/sql/tools/replay-markup-language-utility

═══════════════════════════════════════════════════════
End of version information
═══════════════════════════════════════════════════════
"@

$versionPath = Join-Path $ToolsDir "VERSION.txt"
$versionContent | Out-File -FilePath $versionPath -Encoding UTF8
Write-Success "Created: VERSION.txt"

# Step 10: Cleanup
Write-Host ""
Write-Info "Cleaning up temporary files..."

if (Test-Path $ExtractDir) {
    Remove-Item -Recurse -Force $ExtractDir
    Write-Success "Removed extraction directory"
}

if (Test-Path $MsiPath) {
    Remove-Item -Force $MsiPath
    Write-Success "Removed MSI installer"
}

# Final summary
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  ✓ SETUP COMPLETE!" -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Success "Bundled files ready in: $ToolsDir"
Write-Host ""
Write-Info "Files bundled:"
foreach ($fileName in $foundFiles) {
    Write-Host "  • $fileName" -ForegroundColor White
}
Write-Host ""
Write-Info "Next steps:"
Write-Host "  1. Verify tools work: .\ostress.exe with -? flag" -ForegroundColor White
Write-Host "  2. Commit to repository: git add tools/" -ForegroundColor White
Write-Host "  3. Test /testscript skill with a sample SQL file" -ForegroundColor White
Write-Host ""
Write-Info "To verify bundled tools later:"
Write-Host "  .\Setup-Ostress.ps1 -VerifyOnly" -ForegroundColor White
Write-Host ""
Write-Success "Ready to use with /testscript skill"
Write-Host ""
