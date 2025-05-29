# PSCredentialStore - PowerShell credential management module for macOS
# Copyright (c) 2025 PSCredentialStore Contributors
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

function ConvertFrom-CredentialObject {
    <#
    .SYNOPSIS
        Converts standardized credential object to PSCredential or plain text
    .DESCRIPTION
        Internal helper function that converts the new credential object structure
        to PSCredential objects or plain text format as needed.
    .PARAMETER CredentialObject
        The standardized credential object to convert
    .PARAMETER AsCredential
        Return as PSCredential object
    .PARAMETER AsPlainText
        Return as object with plain text password (includes security warning)
    .OUTPUTS
        [PSCredential] When AsCredential is specified
        [PSCustomObject] When AsPlainText is specified or no conversion requested
    #>
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSCustomObject]$CredentialObject,
        
        [Parameter(ParameterSetName = 'AsCredential')]
        [switch]$AsCredential,
        
        [Parameter(ParameterSetName = 'AsPlainText')]
        [switch]$AsPlainText
    )
    
    process {
        try {
            # Validate input object structure
            if (-not $CredentialObject.Username -or -not $CredentialObject.Password) {
                throw [System.ArgumentException]::new('Invalid credential object: missing Username or Password property')
            }
            
            if ($AsCredential) {
                # Convert to PSCredential
                Write-Verbose "Converting credential object to PSCredential for '$($CredentialObject.Name)'"
                return [System.Management.Automation.PSCredential]::new(
                    $CredentialObject.Username,
                    $CredentialObject.Password
                )
            }
            elseif ($AsPlainText) {
                # Convert password to plain text with warning
                Write-Warning "Retrieving credential with plain text password for '$($CredentialObject.Name)'. Use with extreme caution."
                
                $plainPassword = ConvertFrom-SecureStringToPlainText -SecureString $CredentialObject.Password
                
                # Return object with plain text password
                $result = [PSCustomObject]@{
                    Name = $CredentialObject.Name
                    Username = $CredentialObject.Username
                    Password = $plainPassword
                    Metadata = $CredentialObject.Metadata
                    RetrievedAt = Get-Date
                    PSTypeName = 'PSCredentialStore.PlainTextCredential'
                }
                
                Write-Verbose "Converted credential object to plain text format for '$($CredentialObject.Name)'"
                return $result
            }
            else {
                # Return original object (SecureString format)
                Write-Verbose "Returning credential object in SecureString format for '$($CredentialObject.Name)'"
                return $CredentialObject
            }
        }
        catch {
            Write-Error "Failed to convert credential object for '$($CredentialObject.Name)': $($_.Exception.Message)"
            throw
        }
    }
}
