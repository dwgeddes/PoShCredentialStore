# PSCredentialStore - Cross-platform PowerShell credential management module
# Copyright (c) 2025 PSCredentialStore Contributors
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

function Test-CredentialStoreAccess {
    <#
    .SYNOPSIS
        Validates access to the credential store for the specified operation type
    .DESCRIPTION
        Checks if the current user has appropriate permissions to perform credential operations
        on the native credential store. Provides platform-specific validation and helpful
        error messages when access is denied.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Read', 'Write', 'Delete')]
        [string]$OperationType
    )
    
    try {
        $currentPlatform = Get-OSPlatform
        Write-Verbose "Validating credential store access for '$OperationType' operation on platform '$currentPlatform'"
        
        switch ($currentPlatform) {
            'Windows' {
                return Test-WindowsCredentialAccess -OperationType $OperationType
            }
            'MacOS' {
                return Test-MacOSKeychainAccess -OperationType $OperationType
            }
            'Linux' {
                return Test-LinuxSecretServiceAccess -OperationType $OperationType
            }
            default {
                Write-Warning "Unsupported platform for credential store access validation: $currentPlatform"
                return $false
            }
        }
    }
    catch {
        Write-Warning "Unexpected error during credential store access validation: $($_.Exception.Message)"
        return $false
    }
}

function Test-WindowsCredentialAccess {
    [CmdletBinding()]
    param([string]$OperationType)
    
    try {
        $windowsIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        if ($null -eq $windowsIdentity) {
            Write-Warning "Unable to determine Windows identity. Credential operations may fail."
            return $false
        }
        
        # Test basic credential manager access by attempting to enumerate
        if ($OperationType -in @('Read', 'Write', 'Delete')) {
            try {
                $null = Microsoft.PowerShell.Security\Get-StoredCredential -ErrorAction Stop
            }
            catch [System.ComponentModel.Win32Exception] {
                Write-Warning "Windows Credential Manager is not accessible. Error: $($_.Exception.Message)"
                return $false
            }
            catch {
                # Other errors might be normal (like no credentials found)
                Write-Verbose "Credential Manager access test completed with non-critical error: $($_.Exception.Message)"
            }
        }
        
        return $true
    }
    catch [System.Security.SecurityException] {
        Write-Warning "Insufficient security permissions for Windows Credential Manager access. Try running as administrator."
        return $false
    }
    catch {
        Write-Warning "Unexpected error validating Windows credential store access: $($_.Exception.Message)"
        return $false
    }
}

function Test-MacOSKeychainAccess {
    [CmdletBinding()]
    param([string]$OperationType)
    
    try {
        $keychainListResult = security list-keychains 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Unable to access macOS Keychain. The keychain may be locked or inaccessible."
            return $false
        }
        
        if ($null -eq $keychainListResult) {
            Write-Warning "No keychains found. macOS Keychain may not be properly configured."
            return $false
        }
        
        # For write operations, test if we can access the default keychain
        if ($OperationType -in @('Write', 'Delete')) {
            try {
                $defaultKeychainResult = security default-keychain 2>$null
                if ($LASTEXITCODE -ne 0) {
                    Write-Warning "Cannot access default keychain for write operations. The keychain may be locked."
                    return $false
                }
            }
            catch {
                Write-Warning "Error accessing default keychain: $($_.Exception.Message)"
                return $false
            }
        }
        
        return $true
    }
    catch {
        Write-Warning "Error validating macOS Keychain access: $($_.Exception.Message). Ensure the 'security' command is available."
        return $false
    }
}

function Test-LinuxSecretServiceAccess {
    [CmdletBinding()]
    param([string]$OperationType)
    
    try {
        $secretToolCommand = Get-Command secret-tool -ErrorAction SilentlyContinue
        if (-not $secretToolCommand) {
            Write-Warning "secret-tool command not found. Please install the libsecret-tools package: sudo apt install libsecret-tools"
            return $false
        }
        
        if ([string]::IsNullOrEmpty($env:DBUS_SESSION_BUS_ADDRESS)) {
            Write-Warning "No D-Bus session found (DBUS_SESSION_BUS_ADDRESS not set). Credential operations require a desktop session."
            return $false
        }
        
        # Test basic secret service access
        try {
            $secretServiceTest = secret-tool search --all service PSCredentialStore 2>$null
            if ($LASTEXITCODE -gt 1) { # Exit code 1 is normal for "not found"
                Write-Warning "Secret service is not accessible. Ensure the secret service daemon is running."
                return $false
            }
        }
        catch {
            Write-Warning "Error testing secret service access: $($_.Exception.Message)"
            return $false
        }
        
        return $true
    }
    catch {
        Write-Warning "Error validating Linux secret service access: $($_.Exception.Message)"
        return $false
    }
}
