# PSCredentialStore - Cross-platform PowerShell credential management module
# Copyright (c) 2025 PSCredentialStore Contributors
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

function Remove-StoredCredential {
    <#
    .SYNOPSIS
        Removes credential(s) from the native credential store
    .DESCRIPTION
        Deletes previously saved credentials from the platform's native credential store.
        Supports pipeline input for bulk operations and provides comprehensive validation.
    .PARAMETER Name
        The unique name(s) of credential(s) to remove. Supports pipeline input and arrays.
    .PARAMETER Force
        Removes credentials without prompting for confirmation and continues on validation errors
    .EXAMPLE
        Remove-StoredCredential -Name "MyApp"
        # Removes the credential named "MyApp" with confirmation
    .EXAMPLE
        "App1", "App2", "App3" | Remove-StoredCredential -Force
        # Removes multiple credentials without confirmation
    .EXAMPLE
        Get-StoredCredential | Remove-StoredCredential -Force
        # Removes all stored credentials without confirmation
    .OUTPUTS
        [PSCustomObject] Result object with Name, Result, and Message properties for each operation
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([PSCustomObject], [PSCustomObject[]])]
    param (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Name,
        
        [Parameter()]
        [switch]$Force
    )
    
    begin {
        Write-Verbose "Starting Remove-StoredCredential operation"
    }
    
    process {
        if ($Name -and $Name.Count -gt 0) {
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
                
                # Check if credential exists before attempting removal
                if (-not (& $Provider.Test $Name)) {
                    if ($Force) {
                        Write-Warning "Credential '$Name' does not exist - skipping removal"
                        return New-StoredCredentialObject -Name $Name -Result "Skipped" -Message "Credential does not exist"
                    } else {
                        throw [System.InvalidOperationException]::new("Credential with name '$Name' does not exist")
                    }
                }
                
                # Confirm the operation (unless Force is specified)
                if ($Force -or $PSCmdlet.ShouldProcess($Name, 'Remove credential')) {
                    Write-Verbose "Removing credential '$Name' from credential store"
                    
                    # Execute removal with retry logic
                    $removeScript = {
                        $result = & $Provider.Remove $Name
                        if (-not $result) {
                            throw [System.InvalidOperationException]::new("Provider failed to remove credential '$Name'")
                        }
                    }
                    
                    Invoke-WithRetry -ScriptBlock $removeScript -MaxRetries 2
                    
                    Write-Verbose "Successfully removed credential '$Name'"
                    return New-StoredCredentialObject -Name $Name -Result "Removed" -Message "Credential removed successfully"
                } else {
                    Write-Verbose "ShouldProcess declined removal for '$Name'"
                    return New-StoredCredentialObject -Name $Name -Result "Cancelled" -Message "Operation cancelled by user"
                }
            }
            
            $results = Invoke-PipelineOperation -Operation 'Remove' -Names $Name -ScriptBlock $operationScript -InitializeProvider -ValidateAccess 'Delete' -ReturnSingleResult -Force:$Force
            
            return $results
        }
    }
}