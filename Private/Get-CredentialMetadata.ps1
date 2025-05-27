# PSCredentialStore - Cross-platform PowerShell credential management module
# Copyright (c) 2025 PSCredentialStore Contributors
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

function Get-CredentialMetadataInfo {
    <#
    .SYNOPSIS
        Provides metadata mapping and validation for credential operations
    .DESCRIPTION
        Internal function that maps cross-platform metadata parameters to platform-specific
        implementations and validates which metadata is supported on each platform.
    .PARAMETER Platform
        The target platform (Windows or MacOS)
    .PARAMETER Metadata
        Hashtable of metadata to validate and map
    .OUTPUTS
        [PSCustomObject] with MappedMetadata, Warnings, and UnsupportedKeys properties
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Windows', 'MacOS')]
        [string]$Platform,
        
        [Parameter()]
        [hashtable]$Metadata = @{}
    )
    
    # Define metadata mapping between platforms
    $metadataMapping = @{
        Windows = @{
            # Common metadata mappings for Windows
            Description = 'Comment'           # Maps to Windows CredentialManager Comment field
            URL = 'TargetName'               # Maps to Windows TargetName (URL/service)
            Application = 'Application'       # Windows application name
            CreatedDate = 'CreatedDate'      # Read-only
            ModifiedDate = 'ModifiedDate'    # Read-only
            # Unsupported on Windows (will generate warnings)
            Synchronizable = $null           # Not supported on Windows
            Type = 'Type'                    # Windows credential type
        }
        MacOS = @{
            # Common metadata mappings for macOS Keychain
            Description = 'Description'       # Maps to Keychain Description field
            URL = 'Service'                  # Maps to Keychain Service name
            Application = 'Creator'          # Maps to Keychain Creator/Application
            CreatedDate = 'CreatedDate'      # Read-only keychain attribute
            ModifiedDate = 'ModifiedDate'    # Read-only keychain attribute
            Synchronizable = 'Synchronizable' # iCloud Keychain sync control
            Label = 'Label'                  # Keychain item label
            Kind = 'Kind'                    # Keychain item kind
        }
    }
    
    # Define read-only metadata (cannot be set, only retrieved)
    $readOnlyMetadata = @('CreatedDate', 'ModifiedDate')
    
    # Get platform-specific mapping
    $platformMapping = $metadataMapping[$Platform]
    if (-not $platformMapping) {
        throw "Unsupported platform: $Platform. This module supports Windows and macOS only."
    }
    
    $mappedMetadata = @{}
    $warnings = @()
    $unsupportedKeys = @()
    
    foreach ($key in $Metadata.Keys) {
        $value = $Metadata[$key]
        
        # Check if this metadata is read-only
        if ($readOnlyMetadata -contains $key) {
            $warnings += "Metadata '$key' is read-only and cannot be set"
            $unsupportedKeys += $key
            continue
        }
        
        # Check if this metadata is supported on the current platform
        if (-not $platformMapping.ContainsKey($key)) {
            $warnings += "Metadata '$key' is not recognized on platform '$Platform'"
            $unsupportedKeys += $key
            continue
        }
        
        $platformKey = $platformMapping[$key]
        
        # Check if the platform supports this metadata (null value means unsupported)
        if ($null -eq $platformKey) {
            $warnings += "Metadata '$key' is not supported on platform '$Platform' and will be ignored"
            $unsupportedKeys += $key
            continue
        }
        
        # Map to platform-specific key
        $mappedMetadata[$platformKey] = $value
    }
    
    return [PSCustomObject]@{
        MappedMetadata = $mappedMetadata
        Warnings = $warnings
        UnsupportedKeys = $unsupportedKeys
        Platform = $Platform
    }
}
