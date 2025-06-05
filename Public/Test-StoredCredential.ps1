# PoShCredentialStore - Cross-platform PowerShell credential management module
# Copyright (c) 2025 PoShCredentialStore Contributors
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

function Test-StoredCredential {
    <#
    .SYNOPSIS
        Tests if a credential exists in the credential store
    .DESCRIPTION
        Checks whether a named credential exists in the platform-specific credential store
    .PARAMETER Name
        Name of the credential to test
    .PARAMETER Username
        Specific username to test (optional for additional specificity)
    .EXAMPLE
        Test-StoredCredential -Name "MyService"
        Returns $true if credential exists, $false otherwise
    .EXAMPLE
        Test-StoredCredential -Name "MyService" -Username "user@domain.com"
        Tests for specific username/service combination
    .OUTPUTS
        Boolean indicating whether credential exists
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Name,
        
        [Parameter()]
        [string]$Username
    )
    
    process {
        # Validate supported platform
        if (-not $script:IsMacOS) {
            Write-Error -Message "Platform not supported. This module only supports macOS credential stores." -ErrorAction Stop
        }
        
        foreach ($credName in $Name) {
            try {
                # Validate credential name
                if ([string]::IsNullOrWhiteSpace($credName)) {
                    Write-Warning "Skipping empty or null credential name"
                    Write-Output $false
                    continue
                }

                Write-Verbose "Testing credential: $credName"
                
                # Test using macOS keychain
                $exists = Test-MacOSKeychainItem -Name $credName -Username $Username
                
                Write-Verbose "Credential '$credName' exists: $exists"
                Write-Output $exists
            }
            catch {
                Write-Verbose "Error testing credential '$credName': $($_.Exception.Message)"
                Write-Output $false
            }
        }
    }
}