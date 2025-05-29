# PSCredentialStore - Cross-platform PowerShell credential management module
# Copyright (c) 2025 PSCredentialStore Contributors
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

function Set-StoredCredential {
    <#
    .SYNOPSIS
        Updates an existing stored credential
    .DESCRIPTION
        Updates the password and/or metadata for an existing credential in the store.
        Only specified properties are updated - existing metadata is preserved.
        Supports both PSCredential objects and separate username/password parameters.
    .PARAMETER Name
        The name of the credential to update
    .PARAMETER Credential
        The new credential (username and password). Cannot be used with Username/Password parameters.
    .PARAMETER Username
        The username for the credential. Must be used with Password parameter.
    .PARAMETER Password
        The password as SecureString. Must be used with Username parameter.
    .PARAMETER Description
        Optional description for the credential. Set to empty string to remove.
    .PARAMETER Url
        Optional URL associated with the credential. Set to empty string to remove.
    .PARAMETER Application
        Optional application name for the credential. Set to empty string to remove.
    .PARAMETER Metadata
        Additional metadata hashtable to merge with existing metadata
    .PARAMETER Force
        Skip validation checks and warnings
    .EXAMPLE
        Set-StoredCredential -Name "MyApp" -Credential (Get-Credential)
        # Updates the credential with new PSCredential, preserves existing metadata
    .EXAMPLE
        $securePass = Read-Host -AsSecureString -Prompt "New Password"
        Set-StoredCredential -Name "MyApp" -Username "newuser@domain.com" -Password $securePass
        # Updates with separate username and password parameters
    .EXAMPLE
        Set-StoredCredential -Name "MyApp" -Description "New description"
        # Updates only the description, preserves credential and other metadata
    .OUTPUTS
        [PSCustomObject] Updated credential object with Name, Username, Password (SecureString), Metadata
    #>
    
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'PSCredential')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Position = 1, ValueFromPipeline = $true, ParameterSetName = 'PSCredential')]
        [System.Management.Automation.PSCredential]$Credential,
        
        [Parameter(Mandatory, ParameterSetName = 'UsernamePassword')]
        [ValidateNotNullOrEmpty()]
        [string]$Username,
        
        [Parameter(Mandatory, ParameterSetName = 'UsernamePassword')]
        [System.Security.SecureString]$Password,
        
        [Parameter(ParameterSetName = 'MetadataOnly')]
        [switch]$MetadataOnly,
        
        [Parameter()]
        [string]$Description,
        
        [Parameter()]
        [string]$Url,
        
        [Parameter()]
        [string]$Application,
        
        [Parameter()]
        [hashtable]$Metadata = @{},
        
        [Parameter()]
        [switch]$Force
    )
    
    begin {
        # Early validation: Name cannot be null or empty
        if ($null -eq $Name -or $Name.Trim() -eq '') {
            Write-Error "Parameter 'Name' cannot be null or empty"
            return
        }
    }
    
    process {
        # Skip null pipeline inputs
        if ($null -eq $Name) { return }
        try {
            # Capture parameter flags before entering scriptblock (scoping issue)
            $hasDescription = $PSBoundParameters.ContainsKey('Description')
            $hasUrl = $PSBoundParameters.ContainsKey('Url')
            $hasApplication = $PSBoundParameters.ContainsKey('Application')
            
            # Get existing credential first
            $existingCredential = $null
            try {
                $existingCredential = Get-StoredCredential -Name $Name -Force
            }
            catch {
                if (-not $Force) {
                    Write-Error "Credential '$Name' does not exist. Use New-StoredCredential to create it first."
                    return
                }
            }
            
            # Determine what to update
            $updatedCredentialObject = $null
            
            if ($PSCmdlet.ParameterSetName -eq 'PSCredential' -and $Credential) {
                # Update with PSCredential
                $combinedMetadata = if ($existingCredential) { $existingCredential.Metadata.Clone() } else { @{} }
                $updatedCredentialObject = ConvertTo-CredentialObject -Name $Name -PSCredential $Credential -Metadata $combinedMetadata
            }
            elseif ($PSCmdlet.ParameterSetName -eq 'UsernamePassword') {
                # Update with Username/Password
                $combinedMetadata = if ($existingCredential) { $existingCredential.Metadata.Clone() } else { @{} }
                $updatedCredentialObject = ConvertTo-CredentialObject -Name $Name -Username $Username -SecurePassword $Password -Metadata $combinedMetadata
            }
            elseif ($PSCmdlet.ParameterSetName -eq 'MetadataOnly' -or (-not $Credential -and -not $Username)) {
                # Metadata-only update
                if (-not $existingCredential) {
                    Write-Error "Cannot update metadata: credential '$Name' does not exist"
                    return
                }
                $updatedCredentialObject = $existingCredential
            }
            else {
                Write-Error "Invalid parameter combination"
                return
            }
            
            # Update metadata based on provided parameters
            if ($hasDescription) { 
                if ([string]::IsNullOrEmpty($Description)) {
                    $updatedCredentialObject.Metadata.Remove('Description')
                } else {
                    $updatedCredentialObject.Metadata['Description'] = $Description 
                }
            }
            if ($hasUrl) { 
                if ([string]::IsNullOrEmpty($Url)) {
                    $updatedCredentialObject.Metadata.Remove('Url')
                } else {
                    $updatedCredentialObject.Metadata['Url'] = $Url 
                }
            }
            if ($hasApplication) { 
                if ([string]::IsNullOrEmpty($Application)) {
                    $updatedCredentialObject.Metadata.Remove('Application')
                } else {
                    $updatedCredentialObject.Metadata['Application'] = $Application 
                }
            }
            
            # Add additional metadata if provided
            if ($Metadata -and $Metadata.Count -gt 0) {
                foreach ($key in $Metadata.Keys) {
                    $updatedCredentialObject.Metadata[$key] = $Metadata[$key]
                }
            }
            
            # Always update ModifiedDate
            $updatedCredentialObject.Metadata['ModifiedDate'] = Get-Date

            if ($PSCmdlet.ShouldProcess($Name, "Update stored credential")) {
                # Get provider and update
                $provider = Get-CredentialProvider
                
                # Convert to legacy format for provider
                $legacyCredential = ConvertFrom-CredentialObject -CredentialObject $updatedCredentialObject -AsCredential
                
                $updateScript = {
                    return & $provider.Set $Name $legacyCredential $updatedCredentialObject.Metadata
                }
                
                $result = Invoke-WithRetry -ScriptBlock $updateScript -MaxRetries 2
                
                if ($result) {
                    Write-Verbose "Updated credential '$Name' with username '$($updatedCredentialObject.Username)'"
                    return $updatedCredentialObject
                } else {
                    Write-Error "Provider failed to update credential '$Name'"
                    return
                }
            }
        }
        catch {
            Write-Error "Failed to update credential '$Name': $($_.Exception.Message)"
            return
        }
    }
    
    end {
        # No additional processing needed since we return directly from process block
    }
}