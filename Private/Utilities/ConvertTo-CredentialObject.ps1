# PSCredentialStore - PowerShell credential management module for macOS
# Copyright (c) 2025 PSCredentialStore Contributors
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

function ConvertTo-CredentialObject {
    <#
    .SYNOPSIS
        Converts PSCredential or username/password to standardized credential object
    .DESCRIPTION
        Internal helper function that creates the new standardized credential object structure
        with separate Username and Password (SecureString) properties plus metadata support.
    .PARAMETER Name
        The unique name/identifier for this credential
    .PARAMETER PSCredential
        A PSCredential object to convert
    .PARAMETER Username
        Username string (used with SecurePassword parameter)
    .PARAMETER SecurePassword
        SecureString password (used with Username parameter)
    .PARAMETER Metadata
        Optional hashtable of additional metadata
    .OUTPUTS
        [PSCustomObject] Standardized credential object with Name, Username, Password, Metadata properties
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        
        [Parameter(Mandatory, ParameterSetName = 'PSCredential')]
        [System.Management.Automation.PSCredential]$PSCredential,
        
        [Parameter(Mandatory, ParameterSetName = 'UsernamePassword')]
        [ValidateNotNullOrEmpty()]
        [string]$Username,
        
        [Parameter(Mandatory, ParameterSetName = 'UsernamePassword')]
        [System.Security.SecureString]$SecurePassword,
        
        [Parameter()]
        [hashtable]$Metadata = @{}
    )
    
    try {
        if ($PSCmdlet.ParameterSetName -eq 'PSCredential') {
            $resultUsername = $PSCredential.UserName
            $resultPassword = $PSCredential.Password
        } else {
            $resultUsername = $Username
            $resultPassword = $SecurePassword
        }
        
        # Validate the SecureString
        if ($null -eq $resultPassword) {
            throw [System.ArgumentNullException]::new('Password cannot be null')
        }
        
        # Create standardized credential object
        $credentialObject = [PSCustomObject]@{
            Name = $Name
            Username = $resultUsername
            Password = $resultPassword
            Metadata = $Metadata
            CreatedAt = Get-Date
            PSTypeName = 'PSCredentialStore.Credential'
        }
        
        Write-Verbose "Created credential object for '$Name' with username '$resultUsername'"
        return $credentialObject
    }
    catch {
        Write-Error "Failed to create credential object for '$Name': $($_.Exception.Message)"
        throw
    }
}
