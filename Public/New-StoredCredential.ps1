# PSCredentialStore - Cross-platform PowerShell credential management module
# Copyright (c) 2025 PSCredentialStore Contributors
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

function New-StoredCredential {
    <#
    .SYNOPSIS
        Creates a new credential in the native credential store
    .DESCRIPTION
        Adds a new credential to the platform's native credential store.
        Will fail if a credential with the same name already exists.
        Supports pipeline input and rich metadata storage.
    .PARAMETER Name
        A unique name for the credential. Must be valid for the platform's credential store.
    .PARAMETER Credential
        The PSCredential object to store.
    .PARAMETER Description
        Optional description for the credential
    .PARAMETER Url
        Optional URL associated with the credential
    .PARAMETER Application
        Optional application name for the credential
    .PARAMETER Metadata
        Additional metadata hashtable to store with the credential
    .EXAMPLE
        New-StoredCredential -Name "MyApp" -Credential (Get-Credential)
        # Creates a new credential with the specified name
    .OUTPUTS
        [PSCustomObject] The created credential object with all properties
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
        [hashtable]$Metadata = @{}
    )

    try {
        # If no credential provided, prompt for it
        if (-not $Credential) {
            $Credential = Get-Credential -Message "Enter credentials for '$Name'"
            if (-not $Credential) {
                throw "Credential is required to create stored credential"
            }
        }
        
        # Initialize provider
        $provider = Get-CredentialProvider
        
        # Validate credential name
        $validation = Test-CredentialId -CredentialIdentifier $Name
        if (-not $validation.IsValid) {
            $errorMessage = "Invalid credential name '$Name': " + ($validation.ValidationErrors -join "; ")
            Write-Error $errorMessage -ErrorAction Stop
            return
        }
        
        # Check if credential already exists
        if (& $provider.Test $Name) {
            Write-Warning "A credential with name '$Name' already exists. Use Set-StoredCredential to update existing credentials"
            return $false
        }
        
        # Build comprehensive metadata
        $combinedMetadata = if ($Metadata) { $Metadata.Clone() } else { @{} }
        if ($Description) { $combinedMetadata.Description = $Description }
        if ($Url) { $combinedMetadata.Url = $Url }
        if ($Application) { $combinedMetadata.Application = $Application }
        $combinedMetadata.CreatedDate = Get-Date
        $combinedMetadata.UserName = $Credential.UserName
        
        # Confirm the operation
        if ($PSCmdlet.ShouldProcess($Name, "Create new credential")) {
            Write-Verbose "Creating new credential '$Name' in credential store"
            
            # Execute creation
            & $provider.New $Name $Credential $combinedMetadata | Out-Null
            
            # Return the credential object with result
            Write-Verbose "Successfully created credential '$Name'"
            return New-StoredCredentialObject -Name $Name -Credential $Credential -Metadata $combinedMetadata -Result "Created"
        } else {
            Write-Verbose "ShouldProcess declined creation for '$Name'"
            return $false
        }
    }
    catch {
        Write-Error "Failed to create credential '$Name': $($_.Exception.Message)" -ErrorAction Stop
        return
    }
}
