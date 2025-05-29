# PSCredentialStore - PowerShell credential management module for macOS
# Copyright (c) 2025 PSCredentialStore Contributors
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

function ConvertTo-SecureStringFromPlainText {
    <#
    .SYNOPSIS
        Converts plain text to SecureString safely
    .DESCRIPTION
        Internal helper function that properly converts plain text strings to SecureString objects.
        Used for testing and conversion scenarios.
    .PARAMETER PlainText
        The plain text string to convert to SecureString
    .OUTPUTS
        [System.Security.SecureString] The SecureString representation
    #>
    [CmdletBinding()]
    [OutputType([System.Security.SecureString])]
    param(
        [Parameter(Mandatory)]
        [string]$PlainText
    )
    
    try {
        Write-Verbose "Converting plain text to SecureString (length: $($PlainText.Length))"
        return ConvertTo-SecureString -String $PlainText -AsPlainText -Force
    }
    catch {
        Write-Error "Failed to convert plain text to SecureString: $($_.Exception.Message)"
        throw
    }
}
