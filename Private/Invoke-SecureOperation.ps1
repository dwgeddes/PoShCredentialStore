# PSCredentialStore - Cross-platform PowerShell credential management module
# Copyright (c) 2025 PSCredentialStore Contributors
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

function Invoke-WithRetry {
    <#
    .SYNOPSIS
        Executes a script block with retry logic and exponential backoff
    .DESCRIPTION
        Provides robust retry mechanism for credential operations that may fail due to 
        temporary issues like OS credential store locks or network problems
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,
        
        [Parameter()]
        [ValidateRange(1, 10)]
        [int]$MaxRetries = 3,
        
        [Parameter()]
        [ValidateRange(10, 5000)]
        [int]$InitialDelayMs = 100,
        
        [Parameter()]
        [ValidateRange(100, 30000)]
        [int]$MaxDelayMs = 5000,
        
        [Parameter()]
        [scriptblock]$RetryCondition = { $true }
    )
    
    $attempt = 0
    $delay = $InitialDelayMs
    
    do {
        try {
            Write-Verbose "Executing operation (attempt $($attempt + 1)/$($MaxRetries + 1))"
            return & $ScriptBlock
        }
        catch {
            $attempt++
            $shouldRetry = & $RetryCondition -ErrorRecord $_
            
            if ($attempt -gt $MaxRetries -or -not $shouldRetry) {
                Write-Verbose "Operation failed after $attempt attempts. Not retrying."
                throw
            }
            
            Write-Verbose "Operation failed (attempt $attempt/$($MaxRetries + 1)). Retrying after ${delay}ms. Error: $($_.Exception.Message)"
            Start-Sleep -Milliseconds $delay
            
            # Exponential backoff with jitter to prevent thundering herd
            $jitterMs = Get-Random -Maximum 100
            $delay = [Math]::Min(($delay * 2) + $jitterMs, $MaxDelayMs)
        }
    } while ($attempt -le $MaxRetries)
    
    # This should never be reached due to the throw in the catch block
    throw "Maximum retry attempts exceeded without success"
}

function Test-CredentialStoreAccess {
    <#
    .SYNOPSIS
        Validates access to the credential store for the specified operation type
    .DESCRIPTION
        Checks if the current user has appropriate permissions to perform credential operations
        on the native credential store. Provides platform-specific validation and helpful
        error messages when access is denied.
    .PARAMETER OperationType
        The type of operation to validate access for
    .OUTPUTS
        [bool] True if access is available for the specified operation
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
                # On Windows, validate Windows identity and credential manager access
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
            'MacOS' {
                # Check keychain accessibility using security command
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
            default {
                Write-Warning "Unsupported platform for credential store access validation: $currentPlatform. This module supports Windows and macOS only."
                return $false
            }
        }
    }
    catch {
        Write-Warning "Unexpected error during credential store access validation: $($_.Exception.Message)"
        return $false
    }
}
