function New-MacOSKeychainItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        
        [Parameter(Mandatory = $true)]
        [string]$Username,

        [Parameter(Mandatory = $true)]
        [SecureString]$Password,

        [Parameter()]
        [string]$Comment
    )
    
    # Validate platform
    if (-not $script:IsMacOS) {
        Write-Error -Message "New-MacOSKeychainItem can only be used on macOS" -ErrorAction Stop
    }
    
    # Get module configuration for consistent naming
    $config = Get-ModuleConfiguration
    $serviceName = "$($config.NamePrefix)$Name"
    
    try {
        # Check if credential already exists
        $existingKeychainItem = Get-AllKeychainObjects | Where-Object { $_.Name -eq $serviceName -and $_.UserName -eq $Username }
        if ($existingKeychainItem) {
            Write-Error -Message "Credential with name '$Name' and username '$Username' already exists." -ErrorAction Stop
        }
        
        # Create keychain entry with password
        Set-KeyChainEntry -Username $Username -Name $serviceName -Password $Password -Comment $Comment -Description 'PoShCredential'
        
        # Get final password for return object
        $finalPassword = Get-KeyChainPassword -Name $serviceName -Username $Username | ConvertTo-SecureString -AsPlainText
        
        # Return standardized credential object
        $objParams = @{
            Name = $Name
            Username = $Username
            Password = $finalPassword
            Comment = $Comment
            dateCreated = Get-Date
            dateModified = Get-Date
            Result = "Created"
        }
        $credentialObject = New-StoredCredentialObject @objParams
        Write-Output $credentialObject
    }
    catch {
        Write-Error -Message "Failed to create credential '$Name': $($_.Exception.Message)" -ErrorAction Continue
        Write-Output $null
    }
}