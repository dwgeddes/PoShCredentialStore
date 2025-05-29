# PSCredentialStore - Cross-platform PowerShell credential management module
# Copyright (c) 2025 PSCredentialStore Contributors
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

function Get-CredentialProvider {
    <#
    .SYNOPSIS
        Returns the appropriate credential provider for the current platform
    .DESCRIPTION
        Factory function that creates platform-specific credential providers with
        consistent interfaces and shared configuration
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()
    
    $platform = Get-OSPlatform
    $config = Get-ModuleConfiguration
    
    # Create base provider with common functionality using modern hashtable syntax
    $baseProvider = @{
        PSTypeName = 'PSCredentialStore.CredentialProvider'
        Platform = $platform
        Configuration = $config
    }
    
    # Use modern switch with expression assignment
    $providerMethods = switch ($platform) {
        'Windows' {
            @{
                Get = { param($Name) Invoke-WindowsCredentialManager -Operation Get -Name $Name }
                Set = { param($Name, $Credential, $Metadata = @{}) Invoke-WindowsCredentialManager -Operation Set -Name $Name -Credential $Credential -Metadata $Metadata }
                Remove = { param($Name) Invoke-WindowsCredentialManager -Operation Remove -Name $Name }
                List = { Invoke-WindowsCredentialManager -Operation List }
                Test = { param($Name) Invoke-WindowsCredentialManager -Operation Test -Name $Name }
                New = { param($Name, $Credential, $Metadata = @{}) Invoke-WindowsCredentialManager -Operation New -Name $Name -Credential $Credential -Metadata $Metadata }
            }
        }
        'MacOS' {
            @{
                Get = { param($Name) Invoke-MacOSKeychain -Operation Get -Name $Name }
                Set = { param($Name, $Credential, $Metadata = @{}) Invoke-MacOSKeychain -Operation Set -Name $Name -Credential $Credential -Metadata $Metadata }
                Remove = { param($Name) Invoke-MacOSKeychain -Operation Remove -Name $Name }
                List = { Invoke-MacOSKeychain -Operation List }
                Test = { param($Name) Invoke-MacOSKeychain -Operation Test -Name $Name }
                New = { param($Name, $Credential, $Metadata = @{}) Invoke-MacOSKeychain -Operation New -Name $Name -Credential $Credential -Metadata $Metadata }
            }
        }
        'Linux' {
            throw "Linux is not supported in this version. Supported platforms: Windows, macOS"
        }
        default {
            throw "Unsupported platform: $platform. Supported platforms: Windows, macOS"
        }
    }
    
    # Merge provider methods into base provider
    $baseProvider += $providerMethods
    
    return [PSCustomObject]$baseProvider
}
