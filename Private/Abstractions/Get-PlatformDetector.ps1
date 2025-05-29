# PSCredentialStore - PowerShell credential management module
# Copyright (c) 2025 PSCredentialStore Contributors
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

function Get-PlatformDetector {
    <#
    .SYNOPSIS
        Creates platform detection abstraction for testing
    .DESCRIPTION
        Provides an abstraction layer for platform detection that can be mocked during testing
    .PARAMETER MockPlatform
        Platform to return when mocking (for testing)
    .OUTPUTS
        [PSCustomObject] Platform detector object
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [ValidateSet('Windows', 'MacOS')]
        [string]$MockPlatform
    )
    
    if ($MockPlatform) {
        # Return mocked detector for testing
        return [PSCustomObject]@{
            PSTypeName = 'PSCredentialStore.PlatformDetector'
            IsMocked = $true
            GetPlatform = { $MockPlatform }.GetNewClosure()
        }
    }
    
    # Return real detector
    return [PSCustomObject]@{
        PSTypeName = 'PSCredentialStore.PlatformDetector'
        IsMocked = $false
        GetPlatform = { 
            switch ($true) {
                $IsWindows { return "Windows" }
                $IsMacOS { return "MacOS" }
                $IsLinux { throw "Linux is not supported in this version. This module supports Windows and macOS only." }
                default { throw "Unsupported operating system. This module supports Windows and macOS only." }
            }
        }.GetNewClosure()
    }
}
