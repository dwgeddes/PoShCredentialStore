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
        Supports pipeline input for retrieving multiple specific credentials.
    .PARAMETER Name
        The unique name(s) of credential(s) to retrieve. If not specified, all credentials are returned.
        Supports pipeline input and arrays for bulk operations.
    .PARAMETER Force
        Continue processing even if some credential names are invalid or inaccessible
    .EXAMPLE
        Get-StoredCredential -Name "MyApp"
        # Retrieves the credential named "MyApp"
    .EXAMPLE
        Get-StoredCredential
        # Lists all stored credentials
    .EXAMPLE
        "App1", "App2", "App3" | Get-StoredCredential
        # Retrieves multiple credentials via pipeline
    .EXAMPLE
        Get-StoredCredential -Name "InvalidName" -Force
        # Attempts to retrieve credential, continues on validation errors
    .OUTPUTS
        [PSCustomObject] Single credential object when Name is specified
        [PSCustomObject[]] Array of credential objects when listing all or multiple credentials
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject], [PSCustomObject[]])]
    param (
        [Parameter(Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Name,
        
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
        if ($Name -and $Name.Count -gt 0) {
            $hasProcessedNames = $true
            Write-Verbose "Processing $($Name.Count) credential name(s) from pipeline"
            
            $operationScript = {
                param($Name, $Credential, $Provider, $Index, $Force, $Detailed)
                
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
                
                return Invoke-WithRetry -ScriptBlock $retrieveScript -MaxRetries 2
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
                
                return $allCredentials
            }
            
            # Return results from pipeline processing
            if ($allResults.Count -eq 1 -and ($Name.Count -eq 1 -or ($Name -and $Name.Count -eq 1))) {
                return $allResults[0]
            } else {
                return $allResults
            }
        }
        catch {
            Write-Verbose "Error in Get-StoredCredential: $($_.Exception.Message)"
            
            # Ensure we have proper error handling functions available
            if (Get-Command Get-CredentialStoreErrorDetails -ErrorAction SilentlyContinue) {
                $errorDetails = Get-CredentialStoreErrorDetails -ThrownException $_.Exception -OperationType 'Get' -CredentialIdentifier $Name
                $errorRecord = New-CredentialStoreError -Exception $_.Exception -ErrorId $errorDetails.ErrorIdentifier -Category $errorDetails.ErrorCategory -TargetObject $Name -RecommendedAction $errorDetails.RecommendedUserAction
                $PSCmdlet.ThrowTerminatingError($errorRecord)
            } else {
                # Fallback error handling
                Write-Error "Failed to retrieve credentials: $($_.Exception.Message)" -ErrorAction Stop
            }
        }
    }
}