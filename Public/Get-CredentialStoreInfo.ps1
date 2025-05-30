function Get-CredentialStoreInfo {
    <#
    .SYNOPSIS
    Gets information about the credential store module and capabilities.
    
    .DESCRIPTION
    Returns diagnostic information about the PoShCredentialStore module including
    platform detection, storage capabilities, and module status.
    
    .OUTPUTS
    PSCustomObject with module information and status.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()
    
    try {
        $moduleInfo = Get-Module PoShCredentialStore
        
        if (-not $moduleInfo) {
            $moduleInfo = Import-Module PoShCredentialStore -PassThru -Force
        }
        
        $storageMethod = if ($script:IsWindows) { 'Windows Credential Manager (with file fallback)' } else { 'Encrypted file storage' }
        
        $userStorePath = if ($script:IsWindows) {
            Join-Path $env:APPDATA 'PoShCredentialStore\user'
        } elseif ($PSVersionTable.Platform -eq 'Unix') {
            Join-Path $env:HOME '.poshcredentialstore/user'
        } else {
            Join-Path $env:USERPROFILE 'AppData\Roaming\PoShCredentialStore\user'
        }
        
        $machineStorePath = if ($script:IsWindows) {
            Join-Path $env:ProgramData 'PoShCredentialStore\machine'
        } elseif ($PSVersionTable.Platform -eq 'Unix') {
            '/etc/poshcredentialstore/machine'
        } else {
            Join-Path $env:ProgramData 'PoShCredentialStore\machine'
        }
        
        return [PSCustomObject]@{
            ModuleName = $moduleInfo.Name
            Version = $moduleInfo.Version
            Status = 'Loaded'
            Platform = $PSVersionTable.Platform
            PSVersion = $PSVersionTable.PSVersion
            IsWindows = $script:IsWindows
            StorageMethod = $storageMethod
            UserStorePath = $userStorePath
            MachineStorePath = $machineStorePath
            SupportedOperations = @('Get', 'Set', 'Remove')
            ExportedFunctions = $moduleInfo.ExportedFunctions.Keys
            Issues = @()
        }
    }
    catch {
        return [PSCustomObject]@{
            ModuleName = 'PoShCredentialStore'
            Status = 'Error'
            Error = $_.Exception.Message
            Issues = @("Module failed to load: $($_.Exception.Message)")
        }
    }
}
