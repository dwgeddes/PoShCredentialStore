# PSCredentialStore - PowerShell credential management module for macOS
# Copyright (c) 2025 PSCredentialStore Contributors
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

function Get-OSPlatform {
    <#
    .SYNOPSIS
        Detects the operating system platform.
    .DESCRIPTION
        Returns the current operating system platform (Windows or MacOS).
    .EXAMPLE
        Get-OSPlatform
    .OUTPUTS
        String with value "Windows" or "MacOS"
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [PSCustomObject]$Detector
    )

    if ($Detector -and $Detector.IsMocked) {
        return & $Detector.GetPlatform
    }

    # PowerShell 7 has built-in platform detection via automatic variables
    switch ($true) {
        $IsWindows { $operatingSystem = "Windows" }
        $IsMacOS { $operatingSystem = "MacOS" }
        $IsLinux { throw "Linux is not supported in this version. This module supports Windows and macOS only." }
        default { throw "Unsupported operating system. This module requires PowerShell 7 on Windows or macOS." }
    }
    return $operatingSystem
}