# PoShCredentialStore - Cross-platform PowerShell credential management module
# Copyright (c) 2025 PoShCredentialStore Contributors
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

function Get-CredentialStoreInfo {
    <#
    .SYNOPSIS
        Gets information about the credential store
    .DESCRIPTION
        Returns information about the current platform and credential storage capabilities
    .EXAMPLE
        Get-CredentialStoreInfo
        Returns platform and storage information
    .OUTPUTS
        PSCustomObject with credential store information
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()
    
    # Validate supported platform
    if (-not $script:IsMacOS) {
        Write-Error -Message "Unsupported operating system. This module supports macOS only." -ErrorAction Stop
    }
    
    try {
        $platformInfo = "MacOS"
        $issues = @()
        $supportedOps = @('Get', 'Set', 'Remove', 'Test')
        
        Write-Verbose "Checking credential store capabilities for platform: $platformInfo"
        
        # Check macOS keychain capabilities
        # Check if security command is available
        try {
            $null = Get-Command "security" -ErrorAction Stop
        }
        catch {
            $issues += "security command not available"
        }

        $storeInfo = [PSCustomObject]@{
            ModuleName = 'PoShCredentialStore'
            Version = '0.9.0'
            Platform = $platformInfo
            IsWindows = $false
            IsMacOS = $script:IsMacOS
            StorageType = 'macOS Keychain'
            SupportedOperations = $supportedOps
            Status = if ($issues.Count -eq 0) { 'Healthy' } else { 'Issues Detected' }
            Issues = $issues
            LastChecked = Get-Date
        }
        
        Write-Verbose "Credential store status: $($storeInfo.Status)"
        Write-Output $storeInfo
    }
    catch {
        Write-Error -Message "Failed to get credential store info: $($_.Exception.Message)" -ErrorAction Continue
        Write-Output $null
    }
}
