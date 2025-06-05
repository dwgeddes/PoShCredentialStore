function Remove-MacOSKeychainItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$Username,

        [switch]$PassThru
    )
    
    # Validate platform
    if (-not $script:IsMacOS) {
        Write-Error -Message "Remove-MacOSKeychainItem can only be used on macOS" -ErrorAction Stop
    }
    
    # Get module configuration for consistent naming
    $config = Get-ModuleConfiguration
    $serviceName = "$($config.NamePrefix)$Name"
    
    try {
        # Get existing account details before removal
        $existingKeychainItem = Get-KeychainObject -Name $serviceName -Username $Username -ErrorAction SilentlyContinue
        if (-not $existingKeychainItem) {
            Write-Error -Message "Credential with name '$Name' does not exist." -ErrorAction Stop
        }
                
        # Remove from keychain
        Remove-KeyChainEntry -Name $existingKeychainItem.Name -Username $Username
        
        # Return confirmation object if requested
        if ($PassThru) {
            $objParams = @{
                Name = $Name
                Username = $existingKeychainItem.Username
                Password = $null
                Comment = $existingKeychainItem.Comment
                Result = "Removed"
                dateCreated = $existingKeychainItem.CreationDate
                dateModified = $existingKeychainItem.ModificationDate
            }
            $credentialObject = New-StoredCredentialObject @objParams
            Write-Output $credentialObject
        }
    }
    catch {
        Write-Error -Message "Failed to remove credential '$Name': $($_.Exception.Message)" -ErrorAction Continue
        Write-Output $null
    }
}