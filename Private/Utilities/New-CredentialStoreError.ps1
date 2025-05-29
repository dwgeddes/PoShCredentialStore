# PSCredentialStore - Cross-platform PowerShell credential management module
# Copyright (c) 2025 PSCredentialStore Contributors
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

function New-CredentialStoreError {
    <#
    .SYNOPSIS
        Creates standardized error records for credential store operations with detailed context
    .DESCRIPTION
        Provides consistent error creation with appropriate categorization, context information,
        and recommended actions for users. Supports both terminating and non-terminating errors.
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.ErrorRecord])]
    param(
        [Parameter(Mandatory = $true)]
        [System.Exception]$Exception,
        
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ErrorId,
        
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.ErrorCategory]$Category,
        
        [Parameter()]
        [object]$TargetObject,
        
        [Parameter()]
        [string]$RecommendedAction
    )
    
    try {
        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
            $Exception,
            $ErrorId,
            $Category,
            $TargetObject
        )
        
        if (-not [string]::IsNullOrWhiteSpace($RecommendedAction)) {
            $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new($RecommendedAction)
        }
        
        return $errorRecord
    }
    catch {
        # Fallback error creation if primary method fails
        $fallbackMessage = "Failed to create standardized error record. Original error: $($Exception.Message). Error record creation error: $($_.Exception.Message)"
        $fallbackException = [System.InvalidOperationException]::new($fallbackMessage, $Exception)
        
        return [System.Management.Automation.ErrorRecord]::new(
            $fallbackException,
            'ErrorRecordCreationFailed',
            [System.Management.Automation.ErrorCategory]::InvalidOperation,
            $TargetObject
        )
    }
}

function Write-CredentialStoreError {
    <#
    .SYNOPSIS
        Writes standardized error messages for credential store operations with consistent formatting
    .DESCRIPTION
        Provides consistent error reporting with detailed context and user-friendly recommendations.
        Supports both terminating and non-terminating error scenarios.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCmdlet]$CmdletContext,
        
        [Parameter(Mandatory = $true)]
        [System.Exception]$Exception,
        
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ErrorId,
        
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.ErrorCategory]$Category,
        
        [Parameter()]
        [object]$TargetObject,
        
        [Parameter()]
        [string]$RecommendedAction,
        
        [Parameter()]
        [switch]$IsTerminating
    )
    
    try {
        $errorRecord = New-CredentialStoreError -Exception $Exception -ErrorId $ErrorId -Category $Category -TargetObject $TargetObject -RecommendedAction $RecommendedAction
        
        if ($IsTerminating) {
            $CmdletContext.ThrowTerminatingError($errorRecord)
        } else {
            $CmdletContext.WriteError($errorRecord)
        }
    }
    catch {
        # Fallback error handling if standardized error writing fails
        $fallbackMessage = "Critical error in error handling system. Original error: $($Exception.Message). Error handling error: $($_.Exception.Message)"
        Write-Warning $fallbackMessage
        
        if ($IsTerminating) {
            throw $Exception
        }
    }
}

function Get-CredentialStoreErrorDetails {
    <#
    .SYNOPSIS
        Analyzes exceptions and provides standardized error information with platform-specific guidance
    .DESCRIPTION
        Examines credential store exceptions and returns standardized error details including
        platform-specific recommendations and categorization for consistent error handling.
    .PARAMETER ThrownException
        The exception to analyze and categorize
    .PARAMETER OperationType
        The type of operation that was being performed when the error occurred
    .PARAMETER CredentialIdentifier
        The credential identifier involved in the failed operation
    .OUTPUTS
        [hashtable] Standardized error information with recommendations
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [System.Exception]$ThrownException,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet('Get', 'Set', 'Remove', 'List', 'Test', 'New')]
        [string]$OperationType,
        
        [Parameter()]
        [object]$CredentialIdentifier
    )
    
    try {
        $currentPlatform = Get-OSPlatform
        $errorDetails = @{
            ErrorIdentifier = "Credential${OperationType}OperationFailed"
            ErrorCategory = [System.Management.Automation.ErrorCategory]::InvalidOperation
            RecommendedUserAction = "Verify the credential identifier and try the operation again"
            AffectedObject = $CredentialIdentifier
            PlatformSpecificDetails = @{}
        }
        
        # Analyze exception type for better categorization
        switch ($ThrownException.GetType().Name) {
            'ArgumentException' {
                $errorDetails.ErrorIdentifier = "InvalidCredentialIdentifier"
                $errorDetails.ErrorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
                $errorDetails.RecommendedUserAction = "Provide a valid credential identifier that meets naming requirements. Use Test-CredentialId to validate identifier format."
            }
            'ArgumentNullException' {
                $errorDetails.ErrorIdentifier = "MissingRequiredParameter"
                $errorDetails.ErrorCategory = [System.Management.Automation.ErrorCategory]::InvalidArgument
                $errorDetails.RecommendedUserAction = "Provide all required parameters for the $OperationType operation."
            }
            'UnauthorizedAccessException' {
                $errorDetails.ErrorIdentifier = "CredentialStoreAccessDenied"
                $errorDetails.ErrorCategory = [System.Management.Automation.ErrorCategory]::PermissionDenied
                $errorDetails.RecommendedUserAction = switch ($currentPlatform) {
                    'Windows' { "Run PowerShell as administrator or verify Windows Credential Manager permissions" }
                    'MacOS' { "Unlock your keychain or grant keychain access permissions to PowerShell" }
                    default { "Check credential store access permissions for your platform" }
                }
            }
            'FileNotFoundException' {
                $errorDetails.ErrorIdentifier = "CredentialStoreServiceUnavailable"
                $errorDetails.ErrorCategory = [System.Management.Automation.ErrorCategory]::ResourceUnavailable
                $errorDetails.RecommendedUserAction = switch ($currentPlatform) {
                    'Windows' { "Ensure Windows Credential Manager service is running and accessible" }
                    'MacOS' { "Verify macOS Keychain Services are available and the 'security' command is accessible" }
                    default { "Verify credential store service is available on your platform" }
                }
            }
            'TimeoutException' {
                $errorDetails.ErrorIdentifier = "CredentialOperationTimeout"
                $errorDetails.ErrorCategory = [System.Management.Automation.ErrorCategory]::OperationTimeout
                $errorDetails.RecommendedUserAction = "The credential operation timed out. Check if the credential store is responsive and try again."
            }
            'InvalidOperationException' {
                if ($ThrownException.Message -match "not found|does not exist") {
                    $errorDetails.ErrorIdentifier = "CredentialNotFound"
                    $errorDetails.ErrorCategory = [System.Management.Automation.ErrorCategory]::ObjectNotFound
                    $errorDetails.RecommendedUserAction = "The credential '$CredentialIdentifier' was not found. Use Get-StoredCredential to list available credentials."
                } elseif ($ThrownException.Message -match "already exists") {
                    $errorDetails.ErrorIdentifier = "CredentialAlreadyExists"
                    $errorDetails.ErrorCategory = [System.Management.Automation.ErrorCategory]::ResourceExists
                    $errorDetails.RecommendedUserAction = "A credential with identifier '$CredentialIdentifier' already exists. Use Set-StoredCredential to update existing credentials."
                }
            }
            'System.ComponentModel.Win32Exception' {
                $errorDetails.PlatformSpecificDetails.Win32ErrorCode = $ThrownException.NativeErrorCode
                $errorDetails.RecommendedUserAction = "Windows system error occurred. Error code: $($ThrownException.NativeErrorCode). Check Windows Event Log for additional details."
            }
        }
        
        # Platform-specific error message analysis
        if (-not [string]::IsNullOrEmpty($ThrownException.Message)) {
            switch ($currentPlatform) {
                'Windows' {
                    if ($ThrownException.Message -match "0x80070490|ERROR_NOT_FOUND") {
                        $errorDetails.ErrorIdentifier = "CredentialNotFoundInWindowsStore"
                        $errorDetails.ErrorCategory = [System.Management.Automation.ErrorCategory]::ObjectNotFound
                        $errorDetails.RecommendedUserAction = "The credential was not found in Windows Credential Manager. Verify the credential name and check if it was previously stored."
                    } elseif ($ThrownException.Message -match "0x80070005|ACCESS_DENIED") {
                        $errorDetails.ErrorIdentifier = "WindowsCredentialManagerAccessDenied"
                        $errorDetails.ErrorCategory = [System.Management.Automation.ErrorCategory]::PermissionDenied
                        $errorDetails.RecommendedUserAction = "Access denied to Windows Credential Manager. Run PowerShell as administrator or check user permissions."
                    }
                }
                'MacOS' {
                    if ($ThrownException.Message -match "User interaction is not allowed|errSecUserCanceled") {
                        $errorDetails.ErrorIdentifier = "MacOSKeychainUserCanceled"
                        $errorDetails.ErrorCategory = [System.Management.Automation.ErrorCategory]::OperationStopped
                        $errorDetails.RecommendedUserAction = "Keychain operation was canceled by user. Re-run the command and approve keychain access when prompted."
                    } elseif ($ThrownException.Message -match "errSecItemNotFound") {
                        $errorDetails.ErrorIdentifier = "CredentialNotFoundInKeychain"
                        $errorDetails.ErrorCategory = [System.Management.Automation.ErrorCategory]::ObjectNotFound
                        $errorDetails.RecommendedUserAction = "The credential was not found in macOS Keychain. Verify the credential name and check if it was previously stored."
                    } elseif ($ThrownException.Message -match "errSecAuthFailed") {
                        $errorDetails.ErrorIdentifier = "MacOSKeychainAuthenticationFailed"
                        $errorDetails.ErrorCategory = [System.Management.Automation.ErrorCategory]::AuthenticationError
                        $errorDetails.RecommendedUserAction = "Keychain authentication failed. Unlock your keychain and try again."
                    }
                }
                default {
                    $errorDetails.ErrorIdentifier = "PlatformNotSupported"
                    $errorDetails.ErrorCategory = [System.Management.Automation.ErrorCategory]::NotImplemented
                    $errorDetails.RecommendedUserAction = "This platform is not supported. This module supports Windows and macOS only."
                }
            }
        }
        
        return $errorDetails
    }
    catch {
        # Fallback error details if analysis fails
        return @{
            ErrorIdentifier = "ErrorAnalysisFailed"
            ErrorCategory = [System.Management.Automation.ErrorCategory]::InvalidOperation
            RecommendedUserAction = "An error occurred while analyzing the original error. Original error: $($ThrownException.Message)"
            AffectedObject = $CredentialIdentifier
            PlatformSpecificDetails = @{}
        }
    }
}