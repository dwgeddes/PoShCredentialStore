[CmdletBinding()]
param (
    [Parameter()]
    [switch]$SkipIntegrationTests,
    
    [Parameter()]
    [switch]$CodeCoverage,
    
    [Parameter()]
    [string[]]$Tag = @(),
    
    [Parameter()]
    [switch]$CleanupLegacyTests
)

# Check for PowerShell version
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Error "This module requires PowerShell 7 or later. Current version: $($PSVersionTable.PSVersion)"
    exit 1
}

# Ensure Pester is installed with proper version for PS7
if (-not (Get-Module -Name Pester -ListAvailable | Where-Object { $_.Version -ge '5.0' })) {
    Write-Host "Compatible Pester module not found. Installing latest Pester..." -ForegroundColor Yellow
    Install-Module -Name Pester -Force -SkipPublisherCheck -Scope CurrentUser -MinimumVersion 5.0
}

# Import Pester
Import-Module Pester -MinimumVersion 5.0 -Force

# Handle cleanup of legacy test files if requested
if ($CleanupLegacyTests) {
    Write-Host "Cleaning up legacy test files..." -ForegroundColor Yellow
    $legacyFiles = @(
        "ActualBugTest.Tests.ps1",
        "BugFixed.Tests.ps1", 
        "Get-StoredCredentialPlainText.Tests.ps1",
        "PipelineIntegration.Tests.ps1",
        "PSCredentialStore.Tests.ps1",
        "RealBugCatch.Tests.ps1",
        "RealIntegration.Tests.ps1"
    )
    
    foreach ($file in $legacyFiles) {
        $filePath = Join-Path $PSScriptRoot $file
        if (Test-Path $filePath) {
            Write-Host "  Removing: $file" -ForegroundColor Gray
            Remove-Item $filePath -Force
        }
    }
    Write-Host "Legacy test cleanup complete." -ForegroundColor Green
    return
}

# Define organized test files in execution order
$organizedTests = @(
    "01-Module.Tests.ps1",
    "02-CoreFunctions.Tests.ps1", 
    "03-PlainTextFunction.Tests.ps1",
    "04-MacOSPlatform.Tests.ps1",
    "05-Integration.Tests.ps1",
    "06-Advanced.Tests.ps1"
)

# Verify all organized test files exist
$missingTests = @()
foreach ($testFile in $organizedTests) {
    if (-not (Test-Path (Join-Path $PSScriptRoot $testFile))) {
        $missingTests += $testFile
    }
}

if ($missingTests) {
    Write-Warning "Missing organized test files: $($missingTests -join ', ')"
    Write-Host "Using all available test files instead..." -ForegroundColor Yellow
    $testPath = $PSScriptRoot
} else {
    Write-Host "Running organized test suite..." -ForegroundColor Green
    $testPath = $organizedTests | ForEach-Object { Join-Path $PSScriptRoot $_ }
}

# Set Pester configuration with PS7 improvements
$PesterConfig = [PesterConfiguration]::Default
$PesterConfig.Run.Path = $testPath
$PesterConfig.Run.Exit = $true
$PesterConfig.TestResult.Enabled = $false
$PesterConfig.Output.Verbosity = "Detailed"

# Handle tag filters
if ($Tag.Count -gt 0) {
    Write-Host "Running only tests with tag(s): $($Tag -join ', ')" -ForegroundColor Yellow
    $PesterConfig.Filter.Tag = $Tag
}
# Handle integration tests
elseif ($SkipIntegrationTests) {
    Write-Host "Skipping integration and advanced tests..." -ForegroundColor Yellow
    $PesterConfig.Filter.Tag = @("Unit")
}

# Set up code coverage if requested, using PS7's improved collection functionality
if ($CodeCoverage) {
    $ModulePath = $PSScriptRoot | Split-Path -Parent
    $AllFunctions = Get-ChildItem -Path @("$ModulePath/Public", "$ModulePath/Private") -Filter "*.ps1" -Recurse

    $PesterConfig.CodeCoverage.Enabled = $true
    $PesterConfig.CodeCoverage.Path = $AllFunctions.FullName
    $PesterConfig.CodeCoverage.OutputPath = "$PSScriptRoot/Coverage.xml"
    $PesterConfig.CodeCoverage.OutputFormat = 'JaCoCo'
}

# Run the tests using PS7's improved Pester integration
Invoke-Pester -Configuration $PesterConfig

# PSScriptAnalyzer disable=PSAvoidUsingConvertToSecureStringWithPlainText,PSAvoidUsingWriteHost,PSAvoidUsingCmdletAliases,PSReviewUnusedParameter