function Test-MacOSKeychainItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter()]
        [string]$Username
    )
    
    # Validate platform
    if (-not $script:IsMacOS) {
        Write-Error -Message "Test-MacOSKeychainItem can only be used on macOS" -ErrorAction Stop
    }
    
    # Get module configuration for consistent naming
    $config = Get-ModuleConfiguration
    $serviceName = "$($config.NamePrefix)$Name"
    
    try {
        # Check if credential exists using the same pattern as Get-MacOSKeychainItem
        if ($Name -and $Username) {
            $keychainItem = Get-KeychainObject -Name $serviceName -Username $Username -ErrorAction SilentlyContinue
        }
        else {
            $keychainItem = Get-AllKeychainObjects | Where-Object { $_.Name -eq $serviceName }
        }
        
        Write-Output ($null -ne $keychainItem)
    }
    catch {
        # If we can't get the credential, it doesn't exist
        Write-Output $false
    }
}