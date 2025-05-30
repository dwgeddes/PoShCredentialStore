function Get-PoShCredential {
    <#
    .SYNOPSIS
    Retrieves a stored credential from the credential store.
    
    .DESCRIPTION
    Retrieves a previously stored credential from the platform-appropriate credential store.
    On Windows, uses the Windows Credential Manager. On other platforms, uses a secure file-based store.
    
    .PARAMETER Name
    The name/identifier of the credential to retrieve.
    
    .PARAMETER Scope
    The scope of the credential (User or Machine). Defaults to User.
    
    .EXAMPLE
    $cred = Get-PoShCredential -Name "MyService"
    Retrieves the credential named "MyService" from the user scope.
    
    .EXAMPLE
    $cred = Get-PoShCredential -Name "DatabaseConnection" -Scope Machine
    Retrieves the credential from the machine scope.
    
    .OUTPUTS
    PSCredential object if found, null if not found.
    #>
    [CmdletBinding()]
    [OutputType([PSCredential])]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        
        [Parameter()]
        [ValidateSet('User', 'Machine')]
        [string]$Scope = 'User'
    )
    
    process {
        if ([string]::IsNullOrWhiteSpace($Name)) {
            Write-Error "Credential name cannot be null, empty, or whitespace"
            return $null
        }
        
        try {
            Write-Verbose "Retrieving credential '$Name' from $Scope scope"
            
            if ($script:IsWindows) {
                # Windows Credential Manager implementation
                $targetName = "PoShCredentialStore:$Name:$Scope"
                $credential = Get-WindowsCredential -TargetName $targetName
                
                if ($null -eq $credential) {
                    Write-Verbose "Credential '$Name' not found in Windows Credential Manager"
                    return $null
                }
                
                Write-Verbose "Successfully retrieved credential '$Name' from Windows Credential Manager"
                return $credential
            } else {
                # Cross-platform file-based implementation
                $credentialPath = Get-CredentialStorePath -Name $Name -Scope $Scope
                
                if (-not (Test-Path $credentialPath)) {
                    Write-Verbose "Credential file not found: $credentialPath"
                    return $null
                }
                
                try {
                    $encryptedData = Get-Content $credentialPath -Raw -ErrorAction Stop
                    if ([string]::IsNullOrWhiteSpace($encryptedData)) {
                        Write-Verbose "Credential file is empty: $credentialPath"
                        return $null
                    }
                    
                    $jsonData = $encryptedData | ConvertFrom-Json -ErrorAction Stop
                    $credential = ConvertFrom-SecureCredential -EncryptedData $jsonData
                    
                    Write-Verbose "Successfully retrieved credential '$Name' from secure file store"
                    return $credential
                }
                catch [System.ArgumentException] {
                    Write-Error "Invalid credential data format for '$Name': $($_.Exception.Message)"
                    return $null
                }
                catch [System.Management.Automation.PSInvalidOperationException] {
                    Write-Error "Failed to decrypt credential '$Name': $($_.Exception.Message)"
                    return $null
                }
                catch {
                    Write-Error "Failed to retrieve credential '$Name' from file: $($_.Exception.Message)"
                    return $null
                }
            }
        }
        catch [System.Security.SecurityException] {
            Write-Error "Access denied retrieving credential '$Name': $($_.Exception.Message)"
            return $null
        }
        catch [System.UnauthorizedAccessException] {
            Write-Error "Unauthorized access to credential '$Name': $($_.Exception.Message)"
            return $null
        }
        catch [System.IO.IOException] {
            Write-Error "I/O error accessing credential '$Name': $($_.Exception.Message)"
            return $null
        }
        catch {
            Write-Error "Failed to retrieve credential '$Name': $($_.Exception.Message)"
            return $null
        }
    }
}
