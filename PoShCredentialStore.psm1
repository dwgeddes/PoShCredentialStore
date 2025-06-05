#Requires -Version 7.0

<#
.SYNOPSIS
    PoShCredentialStore - Cross-platform PowerShell credential management module

.DESCRIPTION
    This module provides secure credential storage and retrieval using platform-native
    credential stores: Windows Credential Manager and macOS Keychain.

.NOTES
    Copyright (c) 2025 PoShCredentialStore Contributors
    Licensed under the MIT License
#>

# Initialize platform detection
$script:IsWindows = $PSVersionTable.PSVersion.Major -ge 6 -and $IsWindows
$script:IsMacOS = $PSVersionTable.PSVersion.Major -ge 6 -and $IsMacOS

# Load Private functions first
$PrivateFunctions = @(Get-ChildItem -Path "$PSScriptRoot/Private/*.ps1" -Recurse -ErrorAction SilentlyContinue)
foreach ($Function in $PrivateFunctions) {
    try {
        . $Function.FullName
        Write-Verbose "Loaded private function: $($Function.Name)"
    }
    catch {
        Write-Error "Failed to load private function $($Function.Name): $($_.Exception.Message)"
    }
}

# Load Public functions 
$PublicFunctions = @(Get-ChildItem -Path "$PSScriptRoot/Public/*.ps1" -ErrorAction SilentlyContinue)
foreach ($Function in $PublicFunctions) {
    try {
        . $Function.FullName
        Write-Verbose "Loaded public function: $($Function.Name)"
    }
    catch {
        Write-Error "Failed to load public function $($Function.Name): $($_.Exception.Message)"
    }
}

# Export functions using static list that matches PSD1 exactly
Export-ModuleMember -Function @(
    'Get-StoredCredential',
    'Set-StoredCredential', 
    'New-StoredCredential',
    'Remove-StoredCredential',
    'Test-StoredCredential',
    'Get-CredentialStoreInfo',
    'Get-PoShCredential',
    'Set-PoShCredential',
    'Remove-PoShCredential'
)

# Module cleanup on removal
$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
    Write-Verbose "Cleaning up PoShCredentialStore module..."
    # Clear any module-scoped variables if needed
    Remove-Variable -Name IsWindows, IsMacOS -Scope Script -ErrorAction SilentlyContinue
}

Write-Verbose "PoShCredentialStore module loaded successfully."