# Tools Setup for /testscript Skill

This document explains the bundled tools and how to set them up.

## Bundled Tools

### ostress.exe (RML Utilities)
The skill includes ostress.exe for multi-threaded SQL Server load testing.

## Directory Structure

```
.claude/skills/testscript/
├── SKILL.md                    # Main skill implementation
├── README.md                   # User documentation
├── TOOLS_SETUP.md             # This file
└── tools/                     # Bundled executables
    ├── ostress.exe            # Main load testing tool
    ├── RMLUtils.dll           # Required dependency
    ├── ostress.pdb            # Debug symbols (optional)
    └── README_TOOLS.txt       # Tools information
```

## Installation Instructions

### For Repository Maintainers

To bundle ostress.exe with this skill:

#### Step 1: Download RML Utilities

1. Download from Microsoft:
   - URL: https://www.microsoft.com/en-us/download/details.aspx?id=103126
   - Package: "RML Utilities for SQL Server"
   - Version: Latest (currently v9.04.0004)

2. Install to temporary location:
   ```cmd
   RML_Setup_AMD64.msi /qn INSTALLDIR="C:\Temp\RML"
   ```

#### Step 2: Copy Required Files

Copy these files to `.claude/skills/testscript/tools/`:

```cmd
mkdir .claude\skills\testscript\tools

:: Core executable
copy "C:\Program Files\Microsoft Corporation\RMLUtils\ostress.exe" ^
     .claude\skills\testscript\tools\

:: Required DLLs
copy "C:\Program Files\Microsoft Corporation\RMLUtils\RMLUtils.dll" ^
     .claude\skills\testscript\tools\

:: Optional debug symbols
copy "C:\Program Files\Microsoft Corporation\RMLUtils\ostress.pdb" ^
     .claude\skills\testscript\tools\
```

**Alternative (manual download):**
1. Install RML Utilities normally
2. Navigate to: `C:\Program Files\Microsoft Corporation\RMLUtils`
3. Copy files to `.claude\skills\testscript\tools\`

#### Step 3: Verify Files

```cmd
dir .claude\skills\testscript\tools\
```

Expected output:
```
Directory of .claude\skills\testscript\tools

ostress.exe        ~500 KB
RMLUtils.dll       ~200 KB
ostress.pdb        ~800 KB (optional)
README_TOOLS.txt
```

#### Step 4: Test Bundled Tool

```cmd
cd .claude\skills\testscript\tools
ostress.exe -?
```

Should display usage information.

#### Step 5: Unblock Files (Windows Security)

Windows may block downloaded executables. Unblock them:

```powershell
Get-ChildItem .claude\skills\testscript\tools\*.exe | Unblock-File
Get-ChildItem .claude\skills\testscript\tools\*.dll | Unblock-File
```

#### Step 6: Commit to Repository

Ensure git tracks these files:

```bash
git add .claude/skills/testscript/tools/*.exe
git add .claude/skills/testscript/tools/*.dll
git commit -m "Bundle ostress.exe with /testscript skill"
```

**Note:** Update `.gitignore` if needed to allow .exe files in this specific directory:

```gitignore
# Allow bundled tools
!.claude/skills/testscript/tools/*.exe
!.claude/skills/testscript/tools/*.dll
```

## For End Users

### Verification

Users should verify ostress.exe is present:

```cmd
:: Check file exists
dir .claude\skills\testscript\tools\ostress.exe

:: Test execution
.claude\skills\testscript\tools\ostress.exe -?
```

### If Missing

If ostress.exe is not present in your copy:

1. **Option A:** Re-clone or re-download the skill directory from the repository
2. **Option B:** Manually download and place in `tools/` directory (see maintainer instructions above)
3. **Option C:** Report issue to repository maintainers

### Windows Security Warning

When running ostress.exe for the first time, Windows may show a security warning:

```
Windows protected your PC
Microsoft Defender SmartScreen prevented an unrecognized app from starting.
```

**Solutions:**

1. Click "More info" → "Run anyway"
2. Or unblock via PowerShell:
   ```powershell
   Unblock-File .claude\skills\testscript\tools\ostress.exe
   ```
3. Or unblock via File Properties:
   - Right-click `ostress.exe` → Properties
   - Check "Unblock" → Apply → OK

## License Information

### ostress.exe (RML Utilities)

- **Copyright:** Microsoft Corporation
- **License:** Microsoft Software License Terms
- **Distribution:** Free download from Microsoft
- **Redistribution:** Permitted for non-commercial use (verify current terms)

**License File Location:**
- Included with RML Utilities installation
- See: `C:\Program Files\Microsoft Corporation\RMLUtils\License.rtf`

**Important:** By bundling ostress.exe, we assume:
1. Microsoft allows redistribution for non-commercial/educational use
2. Users agree to Microsoft's license terms
3. No modifications made to ostress.exe

**Disclaimer:** This skill redistributes Microsoft's ostress.exe tool. Users must comply with Microsoft's license terms. If redistribution is not permitted, remove bundled tools and provide download instructions instead.

## Alternative Tools (If Unbundling Required)

If legal review determines we cannot bundle ostress.exe:

### Option 1: Auto-Download Script

Create `.claude/skills/testscript/tools/download-ostress.ps1`:

```powershell
# Auto-download ostress.exe on first run
$ToolsDir = $PSScriptRoot
$OstressPath = Join-Path $ToolsDir "ostress.exe"

if (-not (Test-Path $OstressPath)) {
    Write-Host "Downloading ostress.exe..."

    # Download RML Utilities installer
    $InstallerUrl = "https://download.microsoft.com/download/..."
    $InstallerPath = "$env:TEMP\RML_Setup.msi"

    Invoke-WebRequest -Uri $InstallerUrl -OutFile $InstallerPath

    # Install silently
    Start-Process msiexec.exe -ArgumentList "/i `"$InstallerPath`" /qn" -Wait

    # Copy to tools directory
    Copy-Item "C:\Program Files\Microsoft Corporation\RMLUtils\ostress.exe" $OstressPath

    Write-Host "ostress.exe downloaded successfully!"
}
```

### Option 2: Manual Download Instructions

Update SKILL.md to check for ostress.exe and provide download link if missing.

### Option 3: Alternative Load Testing

Use PowerShell-based load testing instead:

```powershell
# Simple alternative to ostress.exe
param(
    [string]$Server,
    [string]$Database,
    [string]$ScriptFile,
    [int]$Threads = 10,
    [int]$Iterations = 100
)

$jobs = @()
1..$Threads | ForEach-Object {
    $jobs += Start-Job -ScriptBlock {
        param($Server, $Database, $ScriptFile, $Iterations)

        for ($i = 0; $i -lt $Iterations; $i++) {
            Invoke-Sqlcmd -ServerInstance $Server `
                         -Database $Database `
                         -InputFile $ScriptFile
        }
    } -ArgumentList $Server, $Database, $ScriptFile, $Iterations
}

$jobs | Wait-Job | Receive-Job
$jobs | Remove-Job
```

## Troubleshooting

### Issue: "ostress.exe is not recognized"

**Cause:** File not in PATH or not in expected location

**Solution:**
```cmd
:: Use full path
.claude\skills\testscript\tools\ostress.exe -?

:: Or add to PATH temporarily
set PATH=%PATH%;%CD%\.claude\skills\testscript\tools
ostress.exe -?
```

### Issue: "Application failed to initialize"

**Cause:** Missing DLL dependencies

**Solution:** Ensure RMLUtils.dll is in same directory as ostress.exe:
```cmd
dir .claude\skills\testscript\tools\RMLUtils.dll
```

### Issue: "Access Denied" or "Permission Error"

**Cause:** Insufficient permissions or file blocked

**Solution:**
```powershell
# Run as administrator or unblock file
Unblock-File .claude\skills\testscript\tools\ostress.exe

# Check file permissions
icacls .claude\skills\testscript\tools\ostress.exe
```

### Issue: Large Repository Size

**Concern:** Bundled tools increase repo size (~1-2 MB)

**Solutions:**
1. Accept the size increase (reasonable for enterprise repos)
2. Use Git LFS (Large File Storage) for .exe files
3. Move to auto-download approach instead

**Git LFS Setup:**
```bash
git lfs install
git lfs track ".claude/skills/testscript/tools/*.exe"
git add .gitattributes
git commit -m "Track ostress.exe with Git LFS"
```

## Updates and Maintenance

### Checking for Updates

Check Microsoft's download page for new RML Utilities versions:
- URL: https://www.microsoft.com/en-us/download/details.aspx?id=103126
- Current bundled version: [Update this with actual version]

### Updating Bundled ostress.exe

```bash
# 1. Download latest RML Utilities
# 2. Install to temporary location
# 3. Copy updated files
copy "C:\Program Files\Microsoft Corporation\RMLUtils\ostress.exe" ^
     .claude\skills\testscript\tools\ostress.exe

# 4. Test
.claude\skills\testscript\tools\ostress.exe -?

# 5. Commit update
git add .claude/skills/testscript/tools/
git commit -m "Update ostress.exe to version X.X"
```

### Version Tracking

Create `.claude/skills/testscript/tools/VERSION.txt`:
```
ostress.exe Version: 9.04.0004
RML Utilities Build: 9.04.0004
Date Bundled: 2024-01-29
Source: https://www.microsoft.com/en-us/download/details.aspx?id=103126
```

## Security Considerations

### Antivirus False Positives

Some antivirus software may flag ostress.exe as suspicious due to:
- Creating multiple concurrent connections
- Consuming high CPU/memory
- Network activity patterns

**Mitigations:**
1. Add exception for `.claude/skills/testscript/tools/` directory
2. Download from official Microsoft source only
3. Verify file hash against known good version

### File Hash Verification

Verify ostress.exe hasn't been tampered with:

```powershell
# Calculate hash
Get-FileHash .claude\skills\testscript\tools\ostress.exe -Algorithm SHA256

# Compare with known good hash
# Expected: [Add hash from official Microsoft build]
```

### Code Signing

ostress.exe should be digitally signed by Microsoft:

```powershell
# Verify signature
Get-AuthenticodeSignature .claude\skills\testscript\tools\ostress.exe

# Should show:
# Status: Valid
# SignerCertificate: CN=Microsoft Corporation
```

## Support

For issues with bundled tools:
1. Verify file integrity (hash, signature)
2. Re-download from official source
3. Check Windows Event Viewer for errors
4. Report to repository maintainers with details

---

**Document Version:** 1.0
**Last Updated:** 2024-01-29
**Maintained By:** AgentsOfAction Team
