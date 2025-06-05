# PoShCredentialStore - Cross-platform PowerShell credential management module
# Copyright (c) 2025 PoShCredentialStore Contributors
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

function New-StoredCredentialObject {
    <#
    .SYNOPSIS
        Creates standardized credential objects for consistent module output
    .DESCRIPTION
        Internal utility function that creates PSCredential objects with extended properties
        for all credential operations throughout the module. The object contains core 
        PSCredential functionality with optional metadata properties for operation feedback.
    .PARAMETER Name
        The credential identifier/name
    .PARAMETER Username
        The username for the credential  
    .PARAMETER Password
        The SecureString password (required if creating functional credential)
    .PARAMETER Comment
        Optional comment/description for the credential
    .PARAMETER DateCreated
        Creation timestamp (can be string or datetime)
    .PARAMETER DateModified
        Last modification timestamp (can be string or datetime)
    .PARAMETER Result
        Operation result (Created, Modified, Removed) - optional for Get operations
    .OUTPUTS
        [PSCredential] PSCredential object with extended properties for Name, Comment, dates, and Result
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCredential])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Username,
        
        [Parameter()]
        [ValidateScript({
            if ($null -ne $_ -and $_ -is [string]) {
                Write-Error -Message "Password parameter must be a SecureString, not a plain text string. Use ConvertTo-SecureString to convert your password." -ErrorAction Stop
            }
            return $true
        })]
        [AllowNull()]
        [SecureString]$Password,
        
        [Parameter()]
        [string]$Comment,
        
        [Parameter()]
        [object]$DateCreated,
        
        [Parameter()]
        [object]$DateModified,
        
        [Parameter()]
        [AllowNull()]
        [string]$Result
    )
    
    try {
        # Add parameter validation logging for debugging
        Write-Verbose "Creating credential object for Name: '$Name', Username: '$Username'"
        Write-Verbose "Password provided: $($null -ne $Password)"
        Write-Verbose "Comment: '$Comment'"
        Write-Verbose "DateCreated: '$DateCreated'"
        Write-Verbose "DateModified: '$DateModified'"
        Write-Verbose "Result: '$Result'"
        
        # Handle null password by creating a proper empty SecureString
        $securePassword = if ($Password) { 
            $Password 
        } else { 
            # Create empty SecureString without using empty string
            $emptySecure = New-Object System.Security.SecureString
            $emptySecure.MakeReadOnly()
            $emptySecure
        }
        
        $storedCredential = [PSCustomObject]@{
            Name = $Name
            Username = $Username
            Password = $securePassword
            Created = $DateCreated
            Modified = $DateModified
            Comment = $Comment
        }
        
        # Add Result property if provided
        if ($Result) {
            $storedCredential | Add-Member -MemberType NoteProperty -Name 'Result' -Value $Result
        }
        
        # Assign consistent type name for formatting
        $storedCredential.PSObject.TypeNames.Insert(0, 'PoShCredentialStore.StoredCredential')
        
        # Add display methods for consistent formatting
        $storedCredential | Add-Member -MemberType ScriptMethod -Name 'ToString' -Value {
            return "[$($this.Name)] $($this.Username)"
        } -Force
        
        Write-Output $storedCredential
    }
    catch {
        Write-Error -Message "Failed to create credential object: $($_.Exception.Message)" -ErrorAction Stop
    }
}