function Set-MacOSKeychainItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        
        [Parameter()]
        [string]$Username,

        [Parameter()]
        [SecureString]$Password,

        [Parameter()]
        [string]$Comment
    )
    
    # Validate platform
    if (-not $script:IsMacOS) {
        Write-Error -Message "Set-MacOSKeychainItem can only be used on macOS" -ErrorAction Stop
    }
    
    # Get module configuration for consistent naming
    $config = Get-ModuleConfiguration
    $serviceName = "$($config.NamePrefix)$Name"
    
    try {
        # Get existing account details
        Write-Verbose "Looking for service name: $serviceName"
        
        $allKeychainItems = Get-AllKeychainObjects
        Write-Verbose "Found $($allKeychainItems.Count) total keychain items"
        
        # Debug: Show what names we're actually finding
        $allKeychainItems | ForEach-Object { Write-Verbose "Found keychain item with Name: '$($_.Name)'" }
        
        $existingKeychainItem = $allKeychainItems | Where-Object { $_.Name -eq $serviceName }
        Write-Verbose "Filtered items matching '$serviceName': $($existingKeychainItem.Count)"
        
        if (-not $existingKeychainItem) {
            Write-Error -Message "Credential with name '$Name' does not exist. Use New-StoredCredential to create it first." -ErrorAction Stop
        }
        
        # Handle multiple credentials scenario - error out if multiple found
        if ($existingKeychainItem.count -gt 1) {
            Write-Error -Message "Multiple credentials exist with name '$Name'. Please remove duplicates first." -ErrorAction Stop
        }
        
        # Store original values
        $originalUsername = $existingKeychainItem.Username
        
        # Determine final values (use provided values or fall back to existing)
        $finalUsername = if ($Username) { $Username } else { $existingKeychainItem.Username }
        $finalComment = if ($Comment) { $Comment } else { $existingKeychainItem.Comment }
        
        # Get password to use
        $finalPassword = if ($Password) {
            $Password
        } else {
            Get-KeyChainPassword -Name $serviceName -Username $originalUsername
        }
        
        # If username is changing, we need to remove the old entry and create a new one
        if ($Username -and $Username -ne $originalUsername) {
            # Remove the old entry
            Remove-KeyChainEntry -Name $serviceName -Username $originalUsername
            
            # Create new entry with new username
            Set-KeyChainEntry -Username $finalUsername -Name $serviceName -Comment $finalComment -Password $finalPassword -Description 'PoShCredential'
        } else {
            # Update existing entry - always pass name, username, and comment
            Set-KeyChainEntry -Username $finalUsername -Name $serviceName -Comment $finalComment -Password $finalPassword -Description 'PoShCredential' -Update
        }
        
        # Return standardized credential object
        $objParams = @{
            Name = $Name
            Username = $finalUsername
            Password = $finalPassword
            Comment = $finalComment
            dateCreated = $existingKeychainItem.CreationDate
            dateModified = Get-Date
            Result = "Modified"
        }
        $credentialObject = New-StoredCredentialObject @objParams
        Write-Output $credentialObject
    }
    catch {
        Write-Error -Message "Failed to set credential '$Name': $($_.Exception.Message)" -ErrorAction Continue
        Write-Output $null
    }
}