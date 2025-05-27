# PSCredentialStore - Cross-platform PowerShell credential management module
# Copyright (c) 2025 PSCredentialStore Contributors
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

function Invoke-SecureOperation {
    <#
    .SYNOPSIS
        Executes credential operations with security context and memory cleanup
    .DESCRIPTION
        Provides secure execution context for credential operations with proper
        memory cleanup and security validations
    .PARAMETER ScriptBlock
        The script block to execute securely
    .PARAMETER Variables
        Variables to make available in the secure context
    .PARAMETER TimeoutSeconds
        Maximum execution time in seconds
    .OUTPUTS
        The result of the script block execution
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,
        
        [Parameter()]
        [string[]]$Variables = @(),
        
        [Parameter()]
        [ValidateRange(1, 300)]
        [int]$TimeoutSeconds = 30
    )
    
    try {
        # Create secure execution context
        $secureContext = @{}
        
        # Add specified variables to context
        foreach ($varName in $Variables) {
            if (Get-Variable -Name $varName -Scope 1 -ErrorAction SilentlyContinue) {
                $secureContext[$varName] = Get-Variable -Name $varName -Scope 1 -ValueOnly
            }
        }
        
        # Execute with timeout
        $job = Start-Job -ScriptBlock {
            param($ScriptBlock, $Context)
            
            # Import variables into job context
            foreach ($key in $Context.Keys) {
                Set-Variable -Name $key -Value $Context[$key]
            }
            
            # Execute the script block
            & $ScriptBlock
        } -ArgumentList $ScriptBlock, $secureContext
        
        $result = Wait-Job -Job $job -Timeout $TimeoutSeconds | Receive-Job
        Remove-Job -Job $job -Force
        
        return $result
    }
    finally {
        # Clear sensitive variables from memory
        foreach ($varName in $Variables) {
            if (Get-Variable -Name $varName -Scope 1 -ErrorAction SilentlyContinue) {
                Remove-Variable -Name $varName -Scope 1 -Force -ErrorAction SilentlyContinue
            }
        }
        
        # Force garbage collection for sensitive data cleanup
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
        [System.GC]::Collect()
    }
}

function Invoke-WithRetry {
    <#
    .SYNOPSIS
        Executes a script block with retry logic and exponential backoff
    .DESCRIPTION
        Provides robust retry mechanism for credential operations that may fail due to 
        temporary issues like OS credential store locks or network problems
    .PARAMETER ScriptBlock
        The script block to execute
    .PARAMETER MaxRetries
        Maximum number of retry attempts (default: 3)
    .PARAMETER InitialDelayMs
        Initial delay in milliseconds before first retry (default: 100)
    .PARAMETER MaxDelayMs
        Maximum delay in milliseconds between retries (default: 5000)
    .PARAMETER RetryCondition
        Script block that determines if the error should trigger a retry
    .OUTPUTS
        The result of the successful script block execution
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
            
            # Exponential backoff with jitter
            $delay = [Math]::Min($delay * 2 + (Get-Random -Maximum 100), $MaxDelayMs)
        }
    } while ($attempt -le $MaxRetries)
}

function Test-CredentialStoreAccess {
    <#
    .SYNOPSIS
        Validates access to the credential store
    .DESCRIPTION
        Checks if the current user has appropriate permissions to perform credential operations
    .PARAMETER Operation
        The type of operation to validate (Read, Write, Delete)
    .OUTPUTS
        [bool] True if access is available
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Read', 'Write', 'Delete')]
        [string]$Operation
    )
    
    try {
        $platform = Get-OSPlatform
        
        switch ($platform) {
            'Windows' {
                # On Windows, most users can access their credential manager
                # Check if we're in a restricted environment
                try {
                    $null = [System.Security.Principal.WindowsIdentity]::GetCurrent()
                    return $true
                }
                catch {
                    Write-Warning "Unable to access Windows identity. Credential operations may fail."
                    return $false
                }
            }
            'MacOS' {
                # Check keychain access
                try {
                    $result = security list-keychains 2>$null
                    return $null -ne $result
                }
                catch {
                    Write-Warning "Unable to access macOS Keychain. You may need to unlock your keychain."
                    return $false
                }
            }
            'Linux' {
                # Check if secret-tool is available and D-Bus session exists
                if (-not (Get-Command secret-tool -ErrorAction SilentlyContinue)) {
                    Write-Warning "secret-tool not found. Please install libsecret-tools package."
                    return $false
                }
                
                if (-not $env:DBUS_SESSION_BUS_ADDRESS) {
                    Write-Warning "No D-Bus session found. Credential operations may fail."
                    return $false
                }
                
                return $true
            }
            default {
                Write-Warning "Unknown platform: $platform"
                return $false
            }
        }
    }
    catch {
        Write-Warning "Failed to validate credential store access: $($_.Exception.Message)"
        return $false
    }
}