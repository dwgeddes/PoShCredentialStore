# PSCredentialStore - PowerShell credential management module
# Copyright (c) 2025 PSCredentialStore Contributors
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

function Invoke-MetadataOperation {
    <#
    .SYNOPSIS
        Unified interface for credential metadata operations across all platforms
    .DESCRIPTION
        Provides a consistent way to manage credential metadata regardless of the underlying platform.
        This function abstracts the metadata storage mechanism and provides Get, Set, and Remove operations.
    .PARAMETER Operation
        The metadata operation to perform (Get, Set, Remove)
    .PARAMETER Name
        The name/identifier of the credential
    .PARAMETER Metadata
        The metadata hashtable to store (required for Set operation)
    .EXAMPLE
        Invoke-MetadataOperation -Operation Get -Name "MyCredential"
    .EXAMPLE
        Invoke-MetadataOperation -Operation Set -Name "MyCredential" -Metadata @{ UserName = "john"; Created = Get-Date }
    .EXAMPLE
        Invoke-MetadataOperation -Operation Remove -Name "MyCredential"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Get', 'Set', 'Remove')]
        [string]$Operation,
        
        [Parameter(Mandatory = $true)]
        [string]$Name,
        
        [Parameter()]
        [hashtable]$Metadata = @{}
    )
    
    $config = Get-ModuleConfiguration
    $metadataDir = $config.MetadataPath
    $metadataPath = Join-Path $metadataDir "$Name.json"
    
    switch ($Operation) {
        'Get' {
            if (Test-Path $metadataPath) {
                try {
                    $content = Get-Content $metadataPath -Raw | ConvertFrom-Json -AsHashtable
                    return $content
                }
                catch {
                    Write-Verbose "Failed to read metadata for credential '$Name': $_"
                    return @{}
                }
            }
            return @{}
        }
        
        'Set' {
            try {
                # Ensure metadata directory exists
                if (-not (Test-Path $metadataDir)) {
                    New-Item -Path $metadataDir -ItemType Directory -Force | Out-Null
                }
                
                # Store metadata
                $Metadata | ConvertTo-Json -Depth 10 | Set-Content -Path $metadataPath -Force
                return $true
            }
            catch {
                Write-Warning "Failed to store metadata for credential '$Name': $_"
                return $false
            }
        }
        
        'Remove' {
            if (Test-Path $metadataPath) {
                try {
                    Remove-Item -Path $metadataPath -Force
                    return $true
                }
                catch {
                    Write-Warning "Failed to remove metadata for credential '$Name': $_"
                    return $false
                }
            }
            return $true
        }
    }
}
