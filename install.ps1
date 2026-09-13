<#
.SYNOPSIS
    Single-Command Global Installer for Invoke-NetStress
.DESCRIPTION
    Installs the Invoke-NetStress module directly into the user's PowerShell module directory,
    enabling global execution of 'Invoke-NetStress' from any terminal without changing paths.
.EXAMPLE
    irm https://raw.githubusercontent.com/AlphaMvge/Invoke-NetStress/main/install.ps1 | iex
#>

$ErrorActionPreference = "Stop"

Write-Host "`n╔══════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║              INVOKE-NETSTRESS: AUTOMATED MODULE INSTALLER                    ║" -ForegroundColor Yellow
Write-Host "╚══════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host "Fetching latest release from GitHub (AlphaMvge/Invoke-NetStress)..." -ForegroundColor DarkGray

# Determine target user module directories (support both Windows PowerShell 5.1 and PS 7+)
$docsFolder = [Environment]::GetFolderPath('MyDocuments')
$moduleDirs = @(
    (Join-Path $docsFolder "WindowsPowerShell\Modules\Invoke-NetStress"),
    (Join-Path $docsFolder "PowerShell\Modules\Invoke-NetStress")
)

$baseUrl = "https://raw.githubusercontent.com/AlphaMvge/Invoke-NetStress/main"
$files = @(
    "Invoke-NetStress.psd1",
    "Invoke-NetStress.psm1",
    "Invoke-NetStress.ps1"
)

foreach ($dir in $moduleDirs) {
    try {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }

        foreach ($f in $files) {
            $srcUrl = "$baseUrl/$f"
            $dstFile = Join-Path $dir $f
            Invoke-RestMethod -Uri $srcUrl -OutFile $dstFile
        }
    } catch {}
}

# Import module into current session immediately
try {
    Import-Module Invoke-NetStress -Force -ErrorAction SilentlyContinue
} catch {}

Write-Host "`n[✓] SUCCESS: Invoke-NetStress is installed globally!" -ForegroundColor Green
Write-Host "You can now run 'Invoke-NetStress' from ANY directory in any PowerShell terminal.`n" -ForegroundColor Cyan
