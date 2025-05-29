# PSCredentialStore - Cross-platform PowerShell credential management module
# Copyright (c) 2025 PSCredentialStore Contributors
# Licensed under the MIT License. See LICENSE file in the project root for full license information.

function Test-CredentialId {
    <#
    .SYNOPSIS
        Validates and sanitizes credential identifiers for security and platform compatibility
    .DESCRIPTION
        Performs comprehensive validation of credential identifiers to prevent injection attacks,
        ensure cross-platform compatibility, and enforce security best practices.
        
        Returns detailed validation results including sanitized identifiers and specific error messages.
    .PARAMETER CredentialIdentifier
        The credential identifier to validate and sanitize
    .PARAMETER AllowWildcardCharacters
        Whether to allow wildcard characters (* and ?) in the identifier
    .OUTPUTS
        [PSCustomObject] Validation result with IsValid, ValidationErrors, and SanitizedIdentifier properties
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [AllowEmptyString()]
        [string]$CredentialIdentifier,
        
        [Parameter()]
        [switch]$AllowWildcardCharacters
    )
    
    # Create result object with modern syntax
    $validationResult = [PSCustomObject]@{
        IsValid = $true
        ValidationErrors = [System.Collections.Generic.List[string]]::new()
        SanitizedIdentifier = $CredentialIdentifier
        OriginalIdentifier = $CredentialIdentifier
    }
    
    try {
        # Quick validation for null/empty - use modern null checking
        if ([string]::IsNullOrWhiteSpace($CredentialIdentifier)) {
            $validationResult.IsValid = $false
            $validationResult.ValidationErrors.Add("Credential identifier cannot be null, empty, or contain only whitespace characters")
            return $validationResult
        }
        
        # Sanitize input
        $validationResult.SanitizedIdentifier = $CredentialIdentifier.Trim()
        $sanitizedId = $validationResult.SanitizedIdentifier
        
        # Length validation - combine checks
        if ($sanitizedId.Length -gt 255) {
            $validationResult.IsValid = $false
            $validationResult.ValidationErrors.Add("Credential identifier exceeds maximum length of 255 characters. Current length: $($sanitizedId.Length)")
        }
        
        if ($sanitizedId.Length -lt 1) {
            $validationResult.IsValid = $false
            $validationResult.ValidationErrors.Add("Credential identifier cannot be empty after removing whitespace")
            return $validationResult
        }
        
        # Define validation patterns - use more efficient array
        $dangerousPatterns = @(
            @{ Pattern = '[\r\n\t]'; Description = 'Control characters (carriage return, line feed, tab)' }
            @{ Pattern = '[;&|]|&&|\|\|'; Description = 'Command separator characters' }
            @{ Pattern = '[\$`''""]'; Description = 'Variable expansion and quote characters' }
            @{ Pattern = '\.\.|[/\\]'; Description = 'Path traversal characters' }
            @{ Pattern = '[%~<>]'; Description = 'Environment variable expansion and redirection characters' }
        )
        
        # Check dangerous patterns efficiently
        foreach ($pattern in $dangerousPatterns) {
            if ($sanitizedId -match $pattern.Pattern) {
                $validationResult.IsValid = $false
                $validationResult.ValidationErrors.Add("Contains dangerous characters: $($pattern.Description)")
            }
        }
        
        # Platform-specific validation using modern approach
        $invalidChars = [System.IO.Path]::GetInvalidFileNameChars()
        $foundInvalidChars = $invalidChars | Where-Object { $sanitizedId.Contains($_) }
        if ($foundInvalidChars) {
            $validationResult.IsValid = $false
            $charList = ($foundInvalidChars | ForEach-Object { "'$_'" }) -join ', '
            $validationResult.ValidationErrors.Add("Contains platform-invalid characters: $charList")
        }
        
        # Wildcard validation
        if (-not $AllowWildcardCharacters -and ($sanitizedId.Contains('*') -or $sanitizedId.Contains('?'))) {
            $validationResult.IsValid = $false
            $validationResult.ValidationErrors.Add("Wildcard characters (* and ?) are not allowed unless explicitly permitted")
        }
        
        # Reserved names check - use modern contains operation
        $reservedNames = @('CON', 'PRN', 'AUX', 'NUL', 'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9', 'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9')
        if ($reservedNames -contains $sanitizedId.ToUpper()) {
            $validationResult.IsValid = $false
            $validationResult.ValidationErrors.Add("Cannot use reserved system name: '$sanitizedId'")
        }
        
        # Security pattern validation - simplified
        $securityPatterns = @(
            @{ Pattern = '\.{3,}'; Description = 'Multiple consecutive dots (potential path traversal)' }
            @{ Pattern = '^-'; Description = 'Leading dash (potential command injection)' }
            @{ Pattern = '\s{2,}'; Description = 'Multiple consecutive spaces' }
            @{ Pattern = '^\.|\.{2,}'; Description = 'Leading dots or multiple dots (hidden files/path traversal)' }
            @{ Pattern = '\$$'; Description = 'Trailing dollar sign (environment variable injection)' }
        )
        
        foreach ($pattern in $securityPatterns) {
            if ($sanitizedId -match $pattern.Pattern) {
                $validationResult.IsValid = $false
                $validationResult.ValidationErrors.Add("Contains suspicious security pattern: $($pattern.Description)")
            }
        }
        
        # ASCII validation - use modern LINQ-style approach
        $nonPrintableChars = $sanitizedId.ToCharArray() | Where-Object { [int]$_ -lt 32 -or [int]$_ -gt 126 }
        if ($nonPrintableChars) {
            $validationResult.IsValid = $false
            $firstIndex = $sanitizedId.IndexOfAny($nonPrintableChars)
            $asciiValue = [int]$nonPrintableChars[0]
            $validationResult.ValidationErrors.Add("Contains non-printable character at position $firstIndex (ASCII code: $asciiValue). Only printable ASCII characters (32-126) are allowed.")
        }
        
        return $validationResult
    }
    catch {
        $validationResult.IsValid = $false
        $validationResult.ValidationErrors.Add("Unexpected error during validation: $($_.Exception.Message)")
        return $validationResult
    }
}