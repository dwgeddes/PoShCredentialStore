function Get-MacOSKeychainList {
    [CmdletBinding()]
    param()
    
    # Validate platform
    if (-not $script:IsMacOS) {
        Write-Error -Message "Get-MacOSKeychainList can only be used on macOS" -ErrorAction Stop
    }
    
    try {
        # Get module configuration for consistent naming
        $config = Get-ModuleConfiguration
        $prefix = $config.NamePrefix
        
        # Get all keychain objects and filter by ones that begin with our prefix
        $keychainItems = Get-AllKeychainObjects | Where-Object { $_.Name -like "$prefix*" }
        
        foreach ($keychainItem in $keychainItems) {
            $serviceName = $keychainItem.Name
            # Extract the credential name by removing the prefix
            $credentialName = $serviceName.Substring($prefix.Length)

            try {
                $securePassword = Get-KeyChainPassword -Name $keychainItem.Name -Username $keychainItem.UserName
                $objParams = @{
                    Name = $credentialName
                    Username = $keychainItem.Username
                    Password = $securePassword
                    Comment = $keychainItem.Comment
                    dateCreated = $keychainItem.CreationDate
                    dateModified = $keychainItem.ModificationDate
                }
                $credentialObject = New-StoredCredentialObject @objParams
                Write-Output $credentialObject
            }
            catch {
                Write-Warning "Could not retrieve credential for '$($keychainItem.Name)': $_"
            }
        }
    }
    catch {
        Write-Warning "Failed to list credentials: $_"
        return @()
    }
}