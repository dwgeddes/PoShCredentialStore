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
        If no credential is provided, only metadata will be updated.
        Set parameters to empty string to remove them from metadata.
    .PARAMETER Name
        The name of the credential to update
    .PARAMETER Credential
        The new credential (username and password). If not provided, only metadata will be updated.
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
        # Updates the credential with new password, preserves existing metadata
    .EXAMPLE
        Set-StoredCredential -Name "MyApp" -Description "New description"
        # Updates only the description, preserves credential and other metadata
    .EXAMPLE
        Set-StoredCredential -Name "MyApp" -Url ""
        # Removes the URL from the credential metadata
    .OUTPUTS
        [PSCustomObject] Standardized credential object with Result property
    #>
    
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        
        [Parameter(Position = 1, ValueFromPipeline = $true)]
        [System.Management.Automation.PSCredential]$Credential,
        
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
        # No pre-processing needed - credential validation happens in process block
    }
    
    process {
        try {
            # Capture parameter flags before entering scriptblock (scoping issue)
            $hasDescription = $PSBoundParameters.ContainsKey('Description')
            $hasUrl = $PSBoundParameters.ContainsKey('Url')
            $hasApplication = $PSBoundParameters.ContainsKey('Application')
            
            $operationScript = {
                if (-not $Force) {
                    $validation = Test-CredentialId -CredentialIdentifier $Name
                    if (-not $validation.IsValid) {
                        $errorMessage = "Invalid credential name '$Name': " + ($validation.ValidationErrors -join "; ")
                        throw [System.ArgumentException]::new($errorMessage)
                    }
                }
                
                Write-Verbose "Updating credential '$Name' in credential store"
                
                # Get provider
                $provider = Get-CredentialProvider
                
                # Check if credential exists first
                $exists = & $provider.Test $Name
                if (-not $exists -and -not $Force) {
                    Write-Warning "Credential '$Name' does not exist. Use New-StoredCredential to create it first, or use -Force to suppress this warning."
                    return New-StoredCredentialObject -Name $Name -Result "Failed" -Message "Credential does not exist"
                }
                
                # Get existing credential and metadata to preserve what wasn't specified
                $existingMetadata = @{}
                if ($exists) {
                    try {
                        $existingCredential = & $provider.Get $Name
                        if ($existingCredential -and $existingCredential.Metadata) {
                            $existingMetadata = $existingCredential.Metadata.Clone()
                        }
                    }
                    catch {
                        Write-Verbose "Could not retrieve existing metadata, starting fresh: $_"
                    }
                }
                
                # Build metadata - only update specified properties, preserve existing ones
                $combinedMetadata = @{}
                # Copy existing metadata
                foreach ($key in $existingMetadata.Keys) {
                    $combinedMetadata[$key] = $existingMetadata[$key]
                }
                
                if ($hasDescription) { 
                    if ([string]::IsNullOrEmpty($Description)) {
                        $combinedMetadata.Remove('Description')
                    } else {
                        $combinedMetadata['Description'] = $Description 
                    }
                }
                if ($hasUrl) { 
                    if ([string]::IsNullOrEmpty($Url)) {
                        $combinedMetadata.Remove('Url')
                    } else {
                        $combinedMetadata['Url'] = $Url 
                    }
                }
                if ($hasApplication) { 
                    if ([string]::IsNullOrEmpty($Application)) {
                        $combinedMetadata.Remove('Application')
                    } else {
                        $combinedMetadata['Application'] = $Application 
                    }
                }
                
                # Add additional metadata if provided
                if ($Metadata -and $Metadata.Count -gt 0) {
                    foreach ($key in $Metadata.Keys) {
                        $combinedMetadata[$key] = $Metadata[$key]
                    }
                }
                
                # Always update ModifiedDate and UserName if credential is provided
                $combinedMetadata['ModifiedDate'] = Get-Date
                if ($Credential) {
                    $combinedMetadata['UserName'] = $Credential.UserName
                }
                
                # Use existing credential if none provided (metadata-only update)
                $credentialToUse = $Credential
                if (-not $credentialToUse -and $exists) {
                    try {
                        $existing = & $provider.Get $Name
                        $credentialToUse = $existing.Credential
                    }
                    catch {
                        throw "Cannot update metadata without providing credential: existing credential could not be retrieved"
                    }
                }
                
                if (-not $credentialToUse) {
                    throw "Credential is required to update stored credential"
                }
                
                $updateScript = {
                    return & $provider.Set $Name $credentialToUse $combinedMetadata
                }
                
                $result = Invoke-WithRetry -ScriptBlock $updateScript -MaxRetries 2
                
                if ($result) {
                    return New-StoredCredentialObject -Name $Name -Credential $credentialToUse -Metadata $combinedMetadata -Result "Modified"
                } else {
                    return New-StoredCredentialObject -Name $Name -Result "Failed" -Message "Provider failed to update credential"
                }
            }
            
            if ($PSCmdlet.ShouldProcess($Name, "Update stored credential")) {
                $result = & $operationScript
                return $result
            }
        }
        catch {
            Write-Error "Failed to update credential '$Name': $_" -ErrorAction Continue
            return New-StoredCredentialObject -Name $Name -Result "Failed" -Message "Error updating credential: $_"
        }
    }
    
    end {
        # No additional processing needed since we return directly from process block
    }
}