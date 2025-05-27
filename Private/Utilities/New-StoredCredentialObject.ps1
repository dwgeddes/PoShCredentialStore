# PSCredentialStore - PowerShell credential management module
# Copyright (c) 2025 PSCredentialStore Contributors
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

function New-StoredCredentialObject {
    <#
    .SYNOPSIS
        Creates standardized credential objects for consistent module output
    .DESCRIPTION
        Internal utility function that creates consistent PSCustomObject instances
        for all credential operations throughout the module with standardized properties.
        The object contains core properties (Name, UserName, Credential, Metadata) with
        optional Result and Message properties for operation feedback.
    .PARAMETER Name
        The credential identifier
    .PARAMETER Credential
        The PSCredential object (optional)
    .PARAMETER Metadata
        Hashtable of credential metadata (contains Created, Modified, Description, Application, Url, etc.)
    .PARAMETER Result
        Operation result (Created, Modified, Removed) - optional for Get operations
    .PARAMETER Message
        Result message (for operation results) - optional
    .OUTPUTS
        [PSCustomObject] Standardized credential object with Name, UserName, Credential, Metadata, and optional Result/Message properties
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        
        [Parameter()]
        [System.Management.Automation.PSCredential]$Credential,
        
        [Parameter()]
        [hashtable]$Metadata = @{},
        
        [Parameter()]
        [string]$Result,
        
        [Parameter()]
        [string]$Message
    )
    
    # Create standardized object structure
    $obj = [PSCustomObject]@{
        PSTypeName = 'PSCredentialStore.StoredCredential'
        Name = $Name
        UserName = if ($Credential) { $Credential.UserName } else { $Metadata.UserName }
        Credential = $Credential
        Metadata = $Metadata
    }
    
    # Add Result property if provided (for operation results, not for Get operations)
    if ($Result) {
        $obj | Add-Member -NotePropertyName 'Result' -NotePropertyValue $Result
    }
    
    # Add Message property if provided (for detailed operation results)
    if ($Message) {
        $obj | Add-Member -NotePropertyName 'Message' -NotePropertyValue $Message
    }
    
    return $obj
}