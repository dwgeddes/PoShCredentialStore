function Remove-PoShCredential {
    <#
    .SYNOPSIS
    Removes a stored credential from the credential store.
    
    .PARAMETER Name
    The name/identifier of the credential to remove.
    
    .PARAMETER Scope
    The scope of the credential (User or Machine). Defaults to User.
    
    .PARAMETER Force
    Suppresses confirmation prompts.
    
    .OUTPUTS
    Boolean indicating success (true) or failure (false).
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        
        [Parameter()]
        [ValidateSet('User', 'Machine')]
        [string]$Scope = 'User',
        
        [Parameter()]
        [switch]$Force
    )
    
    process {
        try {
            Write-Verbose "Removing credential '$Name' from $Scope scope"
            
            # Check if credential exists
            $existingCredential = Get-PoShCredential -Name $Name -Scope $Scope -ErrorAction SilentlyContinue
            
            if ($null -eq $existingCredential) {
                Write-Warning "Credential '$Name' not found in $Scope scope"
                return $false
            }
            
            if ($Force) {
                $ConfirmPreference = 'None'
            }
            
            if ($PSCmdlet.ShouldProcess("Credential '$Name' ($Scope scope)", "Remove credential")) {
                if ($script:IsWindows) {
                    # Windows Credential Manager implementation
                    $targetName = "PoShCredentialStore:$Name:$Scope"
                    $result = Remove-WindowsCredential -TargetName $targetName
                    
                    if ($result) {
                        Write-Verbose "Successfully removed credential '$Name' from Windows Credential Manager"
                        return $true
                    } else {
                        Write-Error "Failed to remove credential '$Name' from Windows Credential Manager"
                        return $false
                    }
                } else {
                    # Cross-platform file-based implementation
                    $credentialPath = Get-CredentialStorePath -Name $Name -Scope $Scope
                    
                    if (Test-Path $credentialPath) {
                        Remove-Item $credentialPath -Force
                        Write-Verbose "Successfully removed credential '$Name' from secure file store"
                        return $true
                    } else {
                        Write-Warning "Credential file not found: $credentialPath"
                        return $false
                    }
                }
            }
            
            return $false
        }
        catch [System.Security.SecurityException] {
            Write-Error "Access denied removing credential '$Name': $($_.Exception.Message)"
            return $false
        }
        catch [System.UnauthorizedAccessException] {
            Write-Error "Unauthorized access removing credential '$Name': $($_.Exception.Message)"
            return $false
        }
        catch [System.IO.IOException] {
            Write-Error "I/O error removing credential '$Name': $($_.Exception.Message)"
            return $false
        }
        catch {
            Write-Error "Failed to remove credential '$Name': $($_.Exception.Message)"
            return $false
        }
    }
}
