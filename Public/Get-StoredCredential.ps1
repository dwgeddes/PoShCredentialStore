# PoShCredentialStore - Cross-platform PowerShell credential management module
# Copyright (c) 2025 PoShCredentialStore Contributors
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

function Get-StoredCredential {
    <#
    .SYNOPSIS
        Retrieves a stored credential from the credential store
    .DESCRIPTION
        Gets a previously stored credential from the platform-specific credential store
    .PARAMETER Name
        Name of the credential to retrieve
    .PARAMETER Username
        Username of the credential to retrieve (useful when multiple credentials exist with the same name)
    .EXAMPLE
        Get-StoredCredential -Name "MyService"
        Retrieves the credential named "MyService"
    .EXAMPLE
        Get-StoredCredential -Name "MyService" -Username "john.doe"
        Retrieves the specific credential named "MyService" for user "john.doe"
    .OUTPUTS
        PSCredential object
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCredential])]
    param(
        [Parameter(Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string[]]$Name,
        
        [Parameter()]
        [string]$Username
    )
    
    process {
        # Validate supported platform
        if (-not $script:IsMacOS) {
            Write-Error -Message "Platform not supported. This module only supports macOS credential stores." -ErrorAction Stop
        }
        
        # If no names provided, list all credentials
        if (-not $Name) {
            Write-Verbose "No credential names specified, listing all stored credentials"
            
            try {
                $allCredentials = Get-MacOSKeychainList
                Write-Output $allCredentials
            }
            catch {
                Write-Error -Message "Failed to list credentials: $($_.Exception.Message)" -ErrorAction Stop
            }
        }
        
        foreach ($credName in $Name) {
            # Validate individual name values
            if ([string]::IsNullOrWhiteSpace($credName)) {
                Write-Warning "Skipping empty or null credential name"
                continue
            }
            
            try {
                Write-Verbose "Retrieving credential: $credName"
                
                # Get credential using macOS keychain
                $credential = $null
                
                if ($Username) {
                    $credential = Get-MacOSKeychainItem -Name $credName -Username $Username
                } else {
                    $credential = Get-MacOSKeychainItem -Name $credName
                }
                
                if ($credential) {
                    Write-Output $credential
                } else {
                    Write-Verbose "Credential '$credName' not found"
                    Write-Output $null
                }
            }
            catch {
                Write-Error -Message "Failed to retrieve credential '$credName': $($_.Exception.Message)" -ErrorAction Continue
                Write-Output $null
            }
        }
    }
}