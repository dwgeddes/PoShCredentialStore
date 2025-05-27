function Invoke-PipelineOperation {
    <#
    .SYNOPSIS
        Executes credential operations with pipeline support and consistent error handling
    .DESCRIPTION
        Provides standardized pipeline processing for all credential operations,
        handling multiple names and credentials with proper validation and error handling
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Get', 'Set', 'New', 'Remove', 'Test', 'List')]
        [string]$Operation,
        
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Names,
        
        [Parameter()]
        [System.Management.Automation.PSCredential[]]$Credentials,
        
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,
        
        [Parameter()]
        [switch]$InitializeProvider,
        
        [Parameter()]
        [ValidateSet('Read', 'Write', 'Delete')]
        [string]$ValidateAccess,
        
        [Parameter()]
        [switch]$ReturnSingleResult,
        
        [Parameter()]
        [switch]$Force,
        
        [Parameter()]
        [switch]$Detailed
    )
    
    begin {
        $results = @()
        $provider = $null
        
        # Initialize provider if requested
        if ($InitializeProvider) {
            try {
                $provider = Get-CredentialProvider
                Write-Verbose "Initialized credential provider for platform: $($provider.Platform)"
            }
            catch {
                throw "Failed to initialize credential provider: $($_.Exception.Message)"
            }
        }
        
        # Validate access if requested
        if ($ValidateAccess -and $provider) {
            if (-not (Test-CredentialStoreAccess -Operation $ValidateAccess)) {
                throw "Insufficient access for $ValidateAccess operations on platform $($provider.Platform)"
            }
            Write-Verbose "Validated credential store access for $ValidateAccess operations"
        }
    }
    
    process {
        # Process each name with corresponding credential
        for ($i = 0; $i -lt $Names.Count; $i++) {
            $name = $Names[$i]
            
            # Handle credential assignment with flexible matching
            $credential = $null
            if ($Credentials) {
                if ($Credentials.Count -eq 1) {
                    # Single credential applies to all operations
                    $credential = $Credentials[0]
                } elseif ($i -lt $Credentials.Count) {
                    # Match credentials by index position
                    $credential = $Credentials[$i]
                }
                # If no credential available for this index, remains $null
            }
            
            try {
                Write-Verbose "Processing $Operation operation for credential '$name' (index: $i)"
                
                $operationParams = @{
                    Name = $name
                    Credential = $credential
                    Provider = $provider
                    Index = $i
                    Force = $Force.IsPresent
                    Detailed = $Detailed.IsPresent
                }
                
                $result = & $ScriptBlock @operationParams
                
                if ($null -ne $result) {
                    $results += $result
                    Write-Verbose "Successfully processed '$name'"
                }
            }
            catch {
                $errorMessage = "Operation '$Operation' failed for credential '$name': $($_.Exception.Message)"
                
                if ($Force) {
                    Write-Warning $errorMessage
                    $results += New-StoredCredentialObject -Name $name -Result "Failed" -Message $_.Exception.Message
                } else {
                    Write-Error $errorMessage -ErrorAction Stop
                }
            }
        }
    }
    
    end {
        # Return appropriate result format based on input count and preferences
        if ($ReturnSingleResult -and $Names.Count -eq 1 -and $results.Count -le 1) {
            return $results | Select-Object -First 1
        } else {
            return $results
        }
    }
}
