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
        Supports both PSCredential objects and separate username/password parameters.
    .PARAMETER Name
        A unique name for the credential. Must be valid for the platform's credential store.
    .PARAMETER Credential
        The PSCredential object to store. Cannot be used with Username/Password parameters.
    .PARAMETER Username
        The username for the credential. Must be used with Password parameter.
    .PARAMETER Password
        The password as SecureString. Must be used with Username parameter.
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
        # Creates a new credential using PSCredential object
    .EXAMPLE
        $securePass = Read-Host -AsSecureString -Prompt "Password"
        New-StoredCredential -Name "MyApp" -Username "user@domain.com" -Password $securePass
        # Creates a new credential using separate username and password
    .OUTPUTS
        [PSCustomObject] The created credential object with Name, Username, Password (SecureString), Metadata
    #>
    
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'PSCredential')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        
        [Parameter(Position = 1, ValueFromPipeline, ParameterSetName = 'PSCredential')]
        [System.Management.Automation.PSCredential]$Credential,
        
        [Parameter(Mandatory, ParameterSetName = 'UsernamePassword')]
        [ValidateNotNullOrEmpty()]
        [string]$Username,
        
        [Parameter(Mandatory, ParameterSetName = 'UsernamePassword')]
        [System.Security.SecureString]$Password,
        
        [Parameter()]
        [string]$Description,
        
        [Parameter()]
        [string]$Url,
        
        [Parameter()]
        [string]$Application,
        
        [Parameter()]
        [hashtable]$Metadata = @{},
        
        [Parameter()]
        [switch]$NonInteractive
    )

    begin {
        # Early validation
        if ($null -eq $Name -or $Name.Trim() -eq '') {
            Write-Error "Parameter 'Name' cannot be null or empty"
            return
        }
    }

    process {
        try {
            # Create credential object from input parameters
            $credentialObject = $null
            if ($PSCmdlet.ParameterSetName -eq 'PSCredential') {
                # Handle missing credential based on NonInteractive flag
                if (-not $Credential) {
                    if ($NonInteractive) {
                        throw "Credential is required when NonInteractive flag is specified"
                    }
                    $Credential = Get-Credential -Message "Enter credentials for '$Name'"
                    if (-not $Credential) {
                        Write-Error "Credential is required to create stored credential"
                        return
                    }
                }
                
                # Build metadata
                $combinedMetadata = @{}
                if ($Metadata) { $combinedMetadata = $Metadata.Clone() }
                if ($Description) { $combinedMetadata.Description = $Description }
                if ($Url) { $combinedMetadata.Url = $Url }
                if ($Application) { $combinedMetadata.Application = $Application }
                
                $credentialObject = ConvertTo-CredentialObject -Name $Name -PSCredential $Credential -Metadata $combinedMetadata
            }
            else {
                # Username/Password parameter set
                # Build metadata
                $combinedMetadata = @{}
                if ($Metadata) { $combinedMetadata = $Metadata.Clone() }
                if ($Description) { $combinedMetadata.Description = $Description }
                if ($Url) { $combinedMetadata.Url = $Url }
                if ($Application) { $combinedMetadata.Application = $Application }
                
                $credentialObject = ConvertTo-CredentialObject -Name $Name -Username $Username -SecurePassword $Password -Metadata $combinedMetadata
            }

            $provider = Get-CredentialProvider

            # Check if credential already exists
            $testOp = $provider.Test
            if (& $testOp $Name) {
                Write-Warning "Credential '$Name' already exists. Skipping creation"
                return
            }

            if ($PSCmdlet.ShouldProcess($Name, 'Create new credential')) {
                # Store using provider (legacy PSCredential format)
                $legacyCredential = ConvertFrom-CredentialObject -CredentialObject $credentialObject -AsCredential
                
                # Add credential structure info to metadata for proper retrieval
                $enhancedMetadata = $credentialObject.Metadata.Clone()
                $enhancedMetadata['_CredentialStructure'] = 'NewAPI'
                $enhancedMetadata['_Username'] = $credentialObject.Username
                
                & $provider.New $Name $legacyCredential $enhancedMetadata | Out-Null
                
                Write-Verbose "Created credential '$Name' with username '$($credentialObject.Username)'"
                return $credentialObject
            } else {
                Write-Verbose "Creation declined for '$Name'"
                return
            }
        }
        catch {
            Write-Error "Failed to create credential '$Name': $($_.Exception.Message)"
            return
        }
    }

    end {
        # No cleanup needed
    }
}
