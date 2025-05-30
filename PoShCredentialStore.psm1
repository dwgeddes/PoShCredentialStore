#Requires -Version 5.1

<#
.SYNOPSIS
PoShCredentialStore - Cross-platform credential storage module

.DESCRIPTION
Securely store and retrieve credentials using Windows Credential Manager on Windows
and encrypted file storage on other platforms.

.NOTES
Module: PoShCredentialStore
Author: PoShCredentialStore Contributors
Version: 1.0.0
#>

# Module-level variables using proper scoping
$script:ModuleName = 'PoShCredentialStore'
$script:ModuleVersion = '1.0.0'

# Cross-platform detection with enhanced logic
$script:IsWindows = if ($PSVersionTable.PSVersion.Major -ge 6) { 
    $IsWindows 
} else { 
    $env:OS -eq 'Windows_NT' 
}

# Module initialization
Write-Verbose "Initializing $script:ModuleName v$script:ModuleVersion"
Write-Verbose "Platform detection: Windows = $script:IsWindows"

# Validate module structure
$moduleRoot = $PSScriptRoot
$privatePath = Join-Path $moduleRoot 'Private'
$publicPath = Join-Path $moduleRoot 'Public'

if (-not (Test-Path $privatePath)) {
    Write-Warning "Private function directory not found: $privatePath"
}

if (-not (Test-Path $publicPath)) {
    Write-Warning "Public function directory not found: $publicPath"
}

# Load private functions with error handling
$privateFunctions = @()
if (Test-Path $privatePath) {
    try {
        $privateFunctions = Get-ChildItem -Path "$privatePath/*.ps1" -ErrorAction Stop
        foreach ($function in $privateFunctions) {
            Write-Verbose "Loading private function: $($function.Name)"
            . $function.FullName
        }
        Write-Verbose "Loaded $($privateFunctions.Count) private functions"
    }
    catch {
        Write-Error "Failed to load private functions: $($_.Exception.Message)"
        throw
    }
}

# Load public functions with error handling
$publicFunctions = @()
if (Test-Path $publicPath) {
    try {
        $publicFunctions = Get-ChildItem -Path "$publicPath/*.ps1" -ErrorAction Stop
        foreach ($function in $publicFunctions) {
            Write-Verbose "Loading public function: $($function.Name)"
            . $function.FullName
        }
        Write-Verbose "Loaded $($publicFunctions.Count) public functions"
    }
    catch {
        Write-Error "Failed to load public functions: $($_.Exception.Message)"
        throw
    }
}

# Module info function - enhanced for diagnostics
function Get-CredentialStoreInfo {
    <#
    .SYNOPSIS
    Gets information about the PoShCredentialStore module.
    
    .DESCRIPTION
    Returns comprehensive information about the module state, platform compatibility,
    and available operations.
    
    .EXAMPLE
    Get-CredentialStoreInfo
    
    .OUTPUTS
    PSCustomObject with module information
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()
    
    try {
        # Get loaded function names
        $loadedPublicFunctions = $publicFunctions | ForEach-Object { 
            [System.IO.Path]::GetFileNameWithoutExtension($_.Name) 
        }
        
        # Platform-specific capability detection
        $capabilities = @{
            WindowsCredentialManager = $script:IsWindows
            FileBasedStorage = $true
            CrossPlatformPaths = $true
            SecureStringEncryption = $true
        }
        
        # Module health check
        $healthStatus = 'Ready'
        $issues = @()
        
        if ($publicFunctions.Count -eq 0) {
            $healthStatus = 'Warning'
            $issues += 'No public functions loaded'
        }
        
        if (-not $script:IsWindows -and -not (Get-Command 'chmod' -ErrorAction SilentlyContinue)) {
            $issues += 'chmod command not available for file permissions'
        }
        
        return [PSCustomObject]@{
            ModuleName = $script:ModuleName
            Version = $script:ModuleVersion
            Status = $healthStatus
            Issues = $issues
            Platform = $PSVersionTable.Platform
            IsWindows = $script:IsWindows
            PSVersion = $PSVersionTable.PSVersion.ToString()
            PSEdition = $PSVersionTable.PSEdition
            SupportedOperations = $loadedPublicFunctions
            Capabilities = $capabilities
            ModuleRoot = $moduleRoot
            PrivateFunctionsLoaded = $privateFunctions.Count
            PublicFunctionsLoaded = $publicFunctions.Count
            LoadedAt = Get-Date
        }
    }
    catch {
        Write-Error "Failed to get module information: $($_.Exception.Message)"
        return $null
    }
}

# Validate critical assumptions before export
try {
    # Test module-scoped variable access
    if ($null -eq $script:ModuleName) {
        throw "Module-scoped variables not accessible"
    }
    
    # Test platform detection
    if ($null -eq $script:IsWindows) {
        throw "Platform detection failed"
    }
    
    Write-Verbose "Module validation passed"
}
catch {
    Write-Error "Module validation failed: $($_.Exception.Message)"
    throw
}

# Export functions explicitly for better control
$functionsToExport = @()

# Add public function names
if ($publicFunctions.Count -gt 0) {
    $functionsToExport += $publicFunctions | ForEach-Object { 
        [System.IO.Path]::GetFileNameWithoutExtension($_.Name) 
    }
}

# Always export the info function
$functionsToExport += 'Get-CredentialStoreInfo'

# Remove duplicates and export
$functionsToExport = $functionsToExport | Select-Object -Unique

if ($functionsToExport.Count -gt 0) {
    Export-ModuleMember -Function $functionsToExport
    Write-Verbose "Exported functions: $($functionsToExport -join ', ')"
} else {
    Write-Warning "No functions available for export"
}

# Module cleanup on removal
$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
    Write-Verbose "Cleaning up $script:ModuleName module"
    # Clean up any module-scoped resources if needed
}

Write-Verbose "$script:ModuleName module loaded successfully"