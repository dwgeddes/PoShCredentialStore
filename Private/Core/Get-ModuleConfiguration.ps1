# PoShCredentialStore - Cross-platform PowerShell credential management module
# Copyright (c) 2025 PoShCredentialStore Contributors
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

function Get-ModuleConfiguration {
    <#
    .SYNOPSIS
        Gets the module configuration settings
    .DESCRIPTION
        Returns configuration object with platform-appropriate paths and settings
    .OUTPUTS
        [PSCustomObject] Configuration object
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()
    
    $platform = if ($IsWindows) { "Windows" } elseif ($IsMacOS) { "MacOS" } else { "Unknown" }
    
    # Determine base configuration directory
    $configBase = switch ($platform) {
        'Windows' { Join-Path $env:LOCALAPPDATA 'PoShCredentialStore' }
        'macOS' { Join-Path $env:HOME '.config/PoShCredentialStore' }
        default { throw "Unsupported platform: $platform. This module currently supports macOS only." }
    }
    
    # Create configuration object
    $config = [PSCustomObject]@{
        PSTypeName = 'PoShCredentialStore.Configuration'
        Platform = $platform
        ConfigPath = $configBase
        MetadataPath = Join-Path $configBase 'metadata'
        CachePath = Join-Path $configBase 'cache'
        LogPath = Join-Path $configBase 'logs'
        NamePrefix = "PoShCredentialStore:"
    }
    
    return $config
}
