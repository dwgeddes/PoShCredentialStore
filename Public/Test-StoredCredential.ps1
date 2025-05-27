# PSCredentialStore - PowerShell credential management module for macOS
# Copyright (c) 2025 PSCredentialStore Contributors
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

function Test-StoredCredential {
    <#
    .SYNOPSIS
        Tests if a stored credential exists and optionally validates the credential values
    .DESCRIPTION
        Verifies that a stored credential exists and optionally compares the stored credential
        against a provided credential to ensure they match.
    .PARAMETER Name
        The name of the credential to test
    .PARAMETER Credential
        Optional credential to compare against stored credential (username and password)
    .PARAMETER Force
        Bypasses validation checks for the credential name
    .EXAMPLE
        Test-StoredCredential -Name "MyApp"
        # Returns $true if credential exists, $false otherwise
    .EXAMPLE
        Test-StoredCredential -Name "MyApp" -Credential $cred
        # Tests existence and validates that stored credential matches provided credential
    .OUTPUTS
        [bool] True if credential exists (and matches if provided), false otherwise
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        
        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential,
        
        [Parameter()]
        [switch]$Force
    )
    
    
    try {
        # Validate credential name unless Force is specified
        if (-not $Force) {
            $validation = Test-CredentialId -CredentialIdentifier $Name
            if (-not $validation.IsValid) {
                Write-Verbose "Invalid credential name '$Name': $($validation.ValidationErrors -join '; ')"
                return $false
            }
        }
        
        # Initialize provider
        $provider = Get-CredentialProvider
        
        # Test if credential exists
        Write-Verbose "Testing existence of credential '$Name'"
        $exists = & $provider.Test $Name
        if (-not $exists) {
            Write-Verbose "Credential '$Name' does not exist"
            return $false
        }
        
        # If only testing existence, return true
        if (-not $PSBoundParameters.ContainsKey('Credential')) {
            Write-Verbose "Credential '$Name' exists"
            return $true
        }

        # Retrieve the stored credential for validation
        Write-Verbose "Retrieving credential '$Name' for credential validation"
        $storedCredential = & $provider.Get $Name
        if (-not $storedCredential) {
            Write-Verbose "Could not retrieve credential '$Name' for validation"
            return $false
        }

        # Test Credential if provided
        if (-not $storedCredential.Credential) {
            Write-Verbose "No credential stored for '$Name'"
            return $false
        }
        
        $usernameMatch = $storedCredential.Credential.UserName -eq $Credential.UserName
        $passwordMatch = $storedCredential.Credential.GetNetworkCredential().Password -eq $Credential.GetNetworkCredential().Password
        
        if (-not $usernameMatch) {
            Write-Verbose "Username mismatch for '$Name'. Expected: '$($Credential.UserName)', Actual: '$($storedCredential.Credential.UserName)'"
            return $false
        }
        
        if (-not $passwordMatch) {
            Write-Verbose "Password mismatch for '$Name'"
            return $false
        }
        
        Write-Verbose "Credential matches for '$Name'"
        return $true
    }
    catch {
        Write-Verbose "Error testing credential '$Name': $($_.Exception.Message)"
        return $false
    }
}