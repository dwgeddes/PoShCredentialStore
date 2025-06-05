function Get-MacOSKeychainItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter()]
        [string]$Username
    )
    
    # Validate platform
    if (-not $script:IsMacOS) {
        Write-Error -Message "Get-MacOSKeychainItem can only be used on macOS" -ErrorAction Stop
    }
    
    # Get module configuration for consistent naming
    $config = Get-ModuleConfiguration
    $serviceName = "$($config.NamePrefix)$Name"
    
    try {
        # Get account details using security command
        if ($Name -and $Username) {
            $keychainItem = Get-KeychainObject -Name $serviceName -Username $Username
        }
        else {
            $keychainItem = Get-AllKeychainObjects | Where-Object { $_.Name -eq $serviceName }
            if ($keychainItem.count -gt 1) {
                ForEach ($item in $keychainItem) {
                    Write-Output $keychainItem.Username
                }
                Write-Error -Message "Multiple credentials exist with that name. Try specifying a Username:`n$($keychainItem.Username -join "`n")" -ErrorAction Stop
            }
        }
        
        # Check if keychain item was found
        if (-not $keychainItem) {
            Write-Output $null
            return
        }
        
        $Username = $keychainItem.UserName
        # Use wrapper function to get password
        $securePassword = Get-KeyChainPassword -Name $serviceName -Username $Username | ConvertTo-SecureString -AsPlainText
        
        # Return standardized credential object
        $objParams = @{
            Name = $Name
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
        Write-Error -Message "$($_.Exception.Message)" -ErrorAction Continue
        Write-Output $null
    }
}
