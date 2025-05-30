function Set-PoShCredential {
    <#
    .SYNOPSIS
    Stores a credential in the credential store.
    
    .DESCRIPTION
    Stores a credential in the platform-appropriate credential store.
    On Windows, uses the Windows Credential Manager. On other platforms, uses a secure file-based store.
    
    .PARAMETER Name
    The name/identifier for the credential.
    
    .PARAMETER Credential
    The PSCredential object to store.
    
    .PARAMETER Scope
    The scope of the credential (User or Machine). Defaults to User.
    
    .PARAMETER Force
    Overwrites existing credential if it exists.
    
    .EXAMPLE
    $cred = Get-Credential
    Set-PoShCredential -Name "MyService" -Credential $cred
    
    .OUTPUTS
    Boolean indicating success (true) or failure (false).
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [PSCredential]$Credential,
        
        [Parameter()]
        [ValidateSet('User', 'Machine')]
        [string]$Scope = 'User',
        
        [Parameter()]
        [switch]$Force
    )
    
    try {
        Write-Verbose "Storing credential '$Name' in $Scope scope"
        
        # Check if credential already exists
        $existingCredential = Get-PoShCredential -Name $Name -Scope $Scope -ErrorAction SilentlyContinue
        
        if ($null -ne $existingCredential -and -not $Force) {
            Write-Error "Credential '$Name' already exists in $Scope scope. Use -Force to overwrite."
            return $false
        }
        
        if ($PSCmdlet.ShouldProcess("Credential '$Name' ($Scope scope)", "Store credential")) {
            if ($script:IsWindows) {
                # Windows Credential Manager implementation
                $targetName = "PoShCredentialStore:$Name:$Scope"
                $result = Set-WindowsCredential -TargetName $targetName -Credential $Credential
                
                if ($result) {
                    Write-Verbose "Successfully stored credential '$Name' in Windows Credential Manager"
                    return $true
                } else {
                    Write-Error "Failed to store credential '$Name' in Windows Credential Manager"
                    return $false
                }
            } else {
                # Cross-platform file-based implementation
                $credentialPath = Get-CredentialStorePath -Name $Name -Scope $Scope
                $credentialDir = Split-Path $credentialPath -Parent
                
                # Ensure directory exists
                if (-not (Test-Path $credentialDir)) {
                    New-Item -Path $credentialDir -ItemType Directory -Force | Out-Null
                    Write-Verbose "Created credential directory: $credentialDir"
                }
                
                # Encrypt and store credential
                $encryptedData = ConvertTo-SecureCredential -Credential $Credential
                $jsonData = $encryptedData | ConvertTo-Json -Depth 3 -Compress
                
                Set-Content -Path $credentialPath -Value $jsonData -Force -NoNewline
                
                # Set restrictive permissions on Unix-like systems
                if ($PSVersionTable.Platform -eq 'Unix') {
                    & chmod 600 $credentialPath 2>$null
                }
                
                Write-Verbose "Successfully stored credential '$Name' in secure file store"
                return $true
            }
        }
        
        return $false
    }
    catch [System.Security.SecurityException] {
        Write-Error "Access denied storing credential '$Name': $($_.Exception.Message)"
        return $false
    }
    catch [System.UnauthorizedAccessException] {
        Write-Error "Unauthorized access storing credential '$Name': $($_.Exception.Message)"
        return $false
    }
    catch [System.IO.IOException] {
        Write-Error "I/O error storing credential '$Name': $($_.Exception.Message)"
        return $false
    }
    catch {
        Write-Error "Failed to store credential '$Name': $($_.Exception.Message)"
        return $false
    }
}
