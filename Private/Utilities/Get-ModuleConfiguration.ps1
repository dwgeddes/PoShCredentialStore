# PSCredentialStore - PowerShell credential management module
# Copyright (c) 2025 PSCredentialStore Contributors
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
    
    $platform = Get-OSPlatform
    
    # Determine base configuration directory
    $configBase = switch ($platform) {
        'Windows' { Join-Path $env:LOCALAPPDATA 'PSCredentialStore' }
        'MacOS' { Join-Path $env:HOME '.config/PSCredentialStore' }
        default { throw "Unsupported platform: $platform. This module supports Windows and macOS only." }
    }
    
    # Create configuration object
    $config = [PSCustomObject]@{
        PSTypeName = 'PSCredentialStore.Configuration'
        Platform = $platform
        ConfigPath = $configBase
        MetadataPath = Join-Path $configBase 'metadata'
        CachePath = Join-Path $configBase 'cache'
        LogPath = Join-Path $configBase 'logs'
    }
    
    return $config
}
