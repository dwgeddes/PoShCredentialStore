# PSCredentialStore - PowerShell credential management module for macOS
# Copyright (c) 2025 PSCredentialStore Contributors
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

function Get-StoredCredential {
    <#
    .SYNOPSIS
        Retrieves credential(s) from the native credential store
    .DESCRIPTION
        Gets previously saved credentials from the platform's native credential store.
        When run without a Name parameter, returns all stored credentials.
        Returns credential objects with Username and Password (SecureString) properties.
        Use -AsCredential to get PSCredential objects directly.
        Use -AsPlainText to get passwords as plain text (security warning will be shown).
    .PARAMETER Name
        The unique name(s) of credential(s) to retrieve. If not specified, all credentials are returned.
        Supports pipeline input and arrays for bulk operations.
    .PARAMETER AsCredential
        Return credentials as PSCredential objects instead of the default object structure.
        Cannot be used with -AsPlainText.
    .PARAMETER AsPlainText
        Return credentials with passwords in plain text format. Use with extreme caution.
        Cannot be used with -AsCredential.
    .PARAMETER Force
        Continue processing even if some credential names are invalid or inaccessible
    .EXAMPLE
        Get-StoredCredential -Name "MyApp"
        # Retrieves the credential with SecureString password
    .EXAMPLE
        Get-StoredCredential -Name "MyApp" -AsCredential
        # Returns a PSCredential object
    .EXAMPLE
        Get-StoredCredential -Name "MyApp" -AsPlainText
        # Returns credential with plain text password (shows security warning)
    .EXAMPLE
        Get-StoredCredential
        # Lists all stored credentials with SecureString passwords
    .EXAMPLE
        "App1", "App2", "App3" | Get-StoredCredential -AsCredential
        # Retrieves multiple credentials as PSCredential objects via pipeline
    .OUTPUTS
        [PSCustomObject] Default: credential object with Name, Username, Password (SecureString), Metadata
        [PSCredential] When -AsCredential is used
        [PSCustomObject] When -AsPlainText is used: includes plain text Password property
    #>
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    [OutputType([PSCustomObject], [PSCredential])]
    param (
        [Parameter(Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Name,
        
        [Parameter(ParameterSetName = 'AsCredential')]
        [switch]$AsCredential,
        
        [Parameter(ParameterSetName = 'AsPlainText')]
        [switch]$AsPlainText,
        
        [Parameter()]
        [switch]$Force
    )
    
    begin {
        Write-Verbose "Starting Get-StoredCredential operation"
        $allResults = @()
        $provider = $null
        $hasProcessedNames = $false
        
        # Only list all credentials if no Name parameter was provided AND nothing comes from pipeline
        # We'll determine this during processing
    }
    
    process {
        # Pipeline null input: skip processing
        if ($null -eq $Name) { return @() }

        if ($Name -and $Name.Count -gt 0) {
            $hasProcessedNames = $true
            Write-Verbose "Processing $($Name.Count) credential name(s) from pipeline"
            
            $operationScript = {
                param(
                    [string]$Name,
                    [System.Management.Automation.PSCredential]$Credential,
                    [object]$Provider,
                    [int]$Index,
                    [switch]$Force,
                    [bool]$Detailed
                )

                # Validate credential name unless Force is specified
                if (-not $Force) {
                    $validation = Test-CredentialId -CredentialIdentifier $Name
                    if (-not $validation.IsValid) {
                        $errorMessage = "Invalid credential name '$Name': " + ($validation.ValidationErrors -join "; ")
                        throw [System.ArgumentException]::new($errorMessage)
                    }
                }
                
                Write-Verbose "Retrieving credential '$Name' from credential store"
                
                # Use retry logic for robust retrieval
                $retrieveScript = {
                    $credential = & $Provider.Get $Name
                    if (-not $credential) {
                        throw [System.InvalidOperationException]::new("Credential with name '$Name' was not found in the credential store")
                    }
                    return $credential
                }
                
                $rawCredential = Invoke-WithRetry -ScriptBlock $retrieveScript -MaxRetries 2
                
                # Convert to new object structure based on what was stored
                Write-Verbose "Raw credential structure for '$Name': HasCredential=$($null -ne $rawCredential.Credential), HasUsername=$($null -ne $rawCredential.Username), HasPassword=$($null -ne $rawCredential.Password), HasMetadata=$($null -ne $rawCredential.Metadata)"
                
                if ($rawCredential.Metadata -and $rawCredential.Metadata['_CredentialStructure'] -eq 'NewAPI') {
                    # New API format stored with legacy provider
                    Write-Verbose "Converting stored credential to new API format for '$Name'"
                    $credentialObject = ConvertTo-CredentialObject -Name $Name -PSCredential $rawCredential.Credential -Metadata $rawCredential.Metadata
                } elseif ($rawCredential.Credential) {
                    # Legacy format (may have additional properties)
                    Write-Verbose "Converting legacy credential format for '$Name'"
                    $credentialObject = ConvertTo-CredentialObject -Name $Name -PSCredential $rawCredential.Credential -Metadata ($rawCredential.Metadata ?? @{})
                } elseif ($rawCredential.Username -and $rawCredential.Password) {
                    # Pure new format (future provider compatibility)
                    Write-Verbose "Using native new format for '$Name'"
                    $credentialObject = $rawCredential
                } else {
                    $structureDetails = "Properties: $($rawCredential | Get-Member -MemberType Properties | ForEach-Object Name)"
                    throw [System.InvalidOperationException]::new("Credential '$Name' has unrecognized structure. $structureDetails")
                }
                
                # Apply output format conversion
                if ($AsCredential) {
                    return ConvertFrom-CredentialObject -CredentialObject $credentialObject -AsCredential
                } elseif ($AsPlainText) {
                    return ConvertFrom-CredentialObject -CredentialObject $credentialObject -AsPlainText
                } else {
                    return ConvertFrom-CredentialObject -CredentialObject $credentialObject
                }
            }
            
            $results = Invoke-PipelineOperation -Operation 'Get' -Names $Name -ScriptBlock $operationScript -InitializeProvider -ValidateAccess 'Read' -Force:$Force
            
            if ($results) {
                $allResults += $results
            }
        }
    }
    
    end {
        try {
            # If no specific names were provided or processed, list all credentials
            if (-not $hasProcessedNames -and -not $PSBoundParameters.ContainsKey('Name')) {
                Write-Verbose "Listing all stored credentials"
                
                # Provider should already be initialized in begin block
                if (-not $provider) {
                    $provider = Get-CredentialProvider
                }
                
                if (-not $provider) {
                    throw [System.InvalidOperationException]::new("Failed to initialize credential provider")
                }
                
                Write-Verbose "Provider initialized: $($provider.GetType().Name)"
                Write-Verbose "Provider methods: $($provider | Get-Member -MemberType Method | ForEach-Object Name)"
                
                $listScript = {
                    if (-not $provider) {
                        throw [System.InvalidOperationException]::new("Provider is not initialized")
                    }
                    
                    # Check for List method (it's a NoteProperty, not a Method)
                    $hasListMethod = $provider | Get-Member -Name "List" -MemberType NoteProperty
                    
                    if (-not $hasListMethod) {
                        # Try alternative method names
                        $allMembers = $provider | Get-Member | Select-Object -ExpandProperty Name
                        throw [System.NotSupportedException]::new("Provider does not support listing credentials. Available members: $($allMembers -join ', ')")
                    }
                    
                    $result = & $provider.List
                    if ($null -ne $result) {
                        Write-Verbose "Provider.List() returned: $($result.Count) items"
                    } else {
                        Write-Verbose "Provider.List() returned null"
                    }
                    
                    if ($null -eq $result) {
                        Write-Verbose "Provider.List() returned null - no credentials found"
                        return @()
                    }
                    
                    return $result
                }
                
                $allCredentials = Invoke-WithRetry -ScriptBlock $listScript -MaxRetries 2
                
                if ($null -eq $allCredentials -or $allCredentials.Count -eq 0) {
                    Write-Verbose "No credentials found in store"
                    return @()
                }
                
                # Convert all credentials and apply format
                $convertedCredentials = @()
                foreach ($cred in $allCredentials) {
                    try {
                        # Check for new API structure first
                        if ($cred.Metadata -and $cred.Metadata['_CredentialStructure'] -eq 'NewAPI') {
                            Write-Verbose "Using new API format for '$($cred.Name)'"
                            # Already has the new structure - use it directly or convert from embedded PSCredential
                            if ($cred.Credential) {
                                $credentialObject = ConvertTo-CredentialObject -Name $cred.Name -PSCredential $cred.Credential -Metadata $cred.Metadata
                            } else {
                                $credentialObject = $cred
                            }
                        } elseif ($cred.Credential) {
                            # Legacy format with PSCredential object
                            Write-Verbose "Converting legacy credential format for '$($cred.Name)'"
                            $credentialObject = ConvertTo-CredentialObject -Name $cred.Name -PSCredential $cred.Credential -Metadata ($cred.Metadata ?? @{})
                        } elseif ($cred.Username -and $cred.Password) {
                            # Pure new format (future provider compatibility)
                            Write-Verbose "Using pure new format for '$($cred.Name)'"
                            $credentialObject = $cred
                        } else {
                            Write-Warning "Skipping credential '$($cred.Name)' - invalid structure"
                            continue
                        }
                        
                        # Apply output format
                        if ($AsCredential) {
                            $formattedCred = ConvertFrom-CredentialObject -CredentialObject $credentialObject -AsCredential
                        } elseif ($AsPlainText) {
                            $formattedCred = ConvertFrom-CredentialObject -CredentialObject $credentialObject -AsPlainText
                        } else {
                            $formattedCred = ConvertFrom-CredentialObject -CredentialObject $credentialObject
                        }
                        $convertedCredentials += $formattedCred
                    }
                    catch {
                        Write-Warning "Failed to process credential '$($cred.Name)': $($_.Exception.Message)"
                        if (-not $Force) {
                            throw
                        }
                    }
                }
                
                return $convertedCredentials
            }
            
            # Return results from pipeline processing
            if ($allResults.Count -eq 1 -and ($Name.Count -eq 1 -or ($Name -and $Name.Count -eq 1))) {
                return $allResults[0]
            } else {
                return $allResults
            }
        }
        catch {
            Write-Error "Failed to retrieve credentials: $($_.Exception.Message)"
            # Return empty array on error to match Get-* conventions
            return @()
        }
    }
}