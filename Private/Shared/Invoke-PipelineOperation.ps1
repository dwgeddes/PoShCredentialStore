# PSCredentialStore - PowerShell credential management module
# Copyright (c) 2025 PSCredentialStore Contributors
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

function Invoke-PipelineOperation {
    <#
    .SYNOPSIS
        Executes credential operations with pipeline support and consistent error handling
    .DESCRIPTION
        Provides standardized pipeline processing for all credential operations,
        handling multiple names and credentials with proper validation and error handling
    .PARAMETER Operation
        The credential operation type
    .PARAMETER Names
        Array of credential names to process
    .PARAMETER Credentials
        Array of credentials (optional)
    .PARAMETER ScriptBlock
        The operation script block to execute
    .PARAMETER InitializeProvider
        Whether to initialize the credential provider
    .PARAMETER ValidateAccess
        Access validation level required
    .PARAMETER ReturnSingleResult
        Whether to return single result for single input
    .PARAMETER Force
        Whether to force operations
    .PARAMETER Detailed
        Whether to return detailed results
    .OUTPUTS
        Results from the operation script block
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Operation,
        
        [Parameter(Mandatory = $true)]
        [string[]]$Names,
        
        [Parameter()]
        [System.Management.Automation.PSCredential[]]$Credentials,
        
        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,
        
        [Parameter()]
        [switch]$InitializeProvider,
        
        [Parameter()]
        [string]$ValidateAccess,
        
        [Parameter()]
        [switch]$ReturnSingleResult,
        
        [Parameter()]
        [switch]$Force,
        
        [Parameter()]
        [switch]$Detailed
    )
    
    $results = @()
    $provider = $null
    
    # Initialize provider if requested
    if ($InitializeProvider) {
        $provider = Get-CredentialProvider
    }
    
    # Validate access if requested
    if ($ValidateAccess -and $provider) {
        if (-not (Test-CredentialStoreAccess -Operation $ValidateAccess)) {
            throw "Insufficient access for $ValidateAccess operations"
        }
    }
    
    # Process each name
    for ($i = 0; $i -lt $Names.Count; $i++) {
        $name = $Names[$i]
        
        # Handle credential assignment logic
        $credential = $null
        if ($Credentials) {
            if ($Credentials.Count -eq 1) {
                # Single credential for all operations
                $credential = $Credentials[0]
            } elseif ($i -lt $Credentials.Count) {
                # Match credentials by index
                $credential = $Credentials[$i]
            }
            # If no credential available for this index, $credential remains $null
        }
        
        try {
            $result = & $ScriptBlock -Name $name -Credential $credential -Provider $provider -Index $i -Force:$Force -Detailed:$Detailed
            if ($null -ne $result) {
                $results += $result
            }
        }
        catch {
            # Handle errors based on Force parameter
            if ($Force) {
                Write-Warning "Operation failed for '$name': $($_.Exception.Message)"
                $results += New-StoredCredentialObject -Name $name -Result "Failed" -Message $_.Exception.Message
            } else {
                throw
            }
        }
    }
    
    # Return appropriate result format
    if ($ReturnSingleResult -and $Names.Count -eq 1) {
        return $results[0]
    } else {
        return $results
    }
}
