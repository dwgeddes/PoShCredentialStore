<#
.SYNOPSIS
Basic usage examples for PoShCredentialStore module.

.DESCRIPTION
This script demonstrates the core functionality of the PoShCredentialStore module
including storing, retrieving, and removing credentials.
#>

# Import the module
Import-Module "$PSScriptRoot\..\PoShCredentialStore.psd1" -Force

# Example 1: Basic credential storage and retrieval
Write-Host "=== Example 1: Basic CRUD Operations ===" -ForegroundColor Green

try {
    # Create a test credential
    $testPassword = ConvertTo-SecureString "TestPassword123!" -AsPlainText -Force
    $testCredential = New-Object PSCredential("TestUser", $testPassword)
    
    # Store the credential
    Write-Host "Storing credential 'Example1'..."
    New-StoredCredential -Name "Example1" -Credential $testCredential -Force | Out-Null
    Write-Host "Credential stored successfully"
    
    # Test if the credential exists
    Write-Host "Testing if credential 'Example1' exists..."
    $exists = Test-StoredCredential -Name "Example1"
    Write-Host "Credential exists: $exists"
    
    # Retrieve the credential
    Write-Host "Retrieving credential 'Example1'..."
    $retrievedCred = Get-StoredCredential -Name "Example1"
    
    if ($retrievedCred) {
        Write-Host "Retrieved username: $($retrievedCred.Username)"
        # Convert SecureString to plain text to get length (for demo purposes only)
        $tempPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($retrievedCred.Password))
        Write-Host "Password length: $($tempPassword.Length)"
        # Clear the temporary password from memory
        $tempPassword = $null
    } else {
        Write-Warning "Failed to retrieve credential"
    }
    
    # Update the credential
    Write-Host "Updating credential 'Example1'..."
    $newPassword = ConvertTo-SecureString "UpdatedPassword123!" -AsPlainText -Force
    Set-StoredCredential -Name "Example1" -UserName "UpdatedUser" -Password $newPassword -Comment "Updated credential"
    
    # Clean up
    Write-Host "Removing credential 'Example1'..."
    Remove-StoredCredential -Name "Example1" -Force
    Write-Host "Credential removed successfully"
}
catch {
    Write-Error "Example 1 failed: $($_.Exception.Message)"
}

# Example 2: Working with usernames and comments
Write-Host "`n=== Example 2: Usernames and Comments ===" -ForegroundColor Green

try {
    # Create credential with comment
    Write-Host "Creating credential with comment..."
    $cred = New-Object PSCredential("service.account", (ConvertTo-SecureString "ServicePass123!" -AsPlainText -Force))
    New-StoredCredential -Name "ServiceAccount" -Credential $cred -Comment "Production service account credentials"
    
    # Retrieve and display
    $retrieved = Get-StoredCredential -Name "ServiceAccount"
    if ($retrieved) {
        Write-Host "Service account retrieved: $($retrieved.UserName)"
    }
    
    # Test with username parameter
    $existsWithUser = Test-StoredCredential -Name "ServiceAccount" -Username "service.account"
    Write-Host "Credential exists for specific username: $existsWithUser"
    
    # Clean up
    Remove-StoredCredential -Name "ServiceAccount" -Force
}
catch {
    Write-Error "Example 2 failed: $($_.Exception.Message)"
}

# Example 3: Pipeline operations
Write-Host "`n=== Example 3: Pipeline Operations ===" -ForegroundColor Green

try {
    # Create multiple test credentials
    $testCredentials = @(
        @{Name = "Service1"; Credential = (New-Object PSCredential("User1", (ConvertTo-SecureString "Pass1" -AsPlainText -Force)))},
        @{Name = "Service2"; Credential = (New-Object PSCredential("User2", (ConvertTo-SecureString "Pass2" -AsPlainText -Force)))},
        @{Name = "Service3"; Credential = (New-Object PSCredential("User3", (ConvertTo-SecureString "Pass3" -AsPlainText -Force)))}
    )
    
    # Store all credentials
    Write-Host "Storing multiple credentials..."
    foreach ($cred in $testCredentials) {
        New-StoredCredential -Name $cred.Name -Credential $cred.Credential -Force | Out-Null
    }
    
    # Test credentials using pipeline
    Write-Host "Testing credentials using pipeline..."
    $testResults = $testCredentials.Name | Test-StoredCredential
    Write-Host "Test results: $($testResults -join ', ')"
    
    # Retrieve using pipeline
    Write-Host "Retrieving credentials using pipeline..."
    $retrievedCreds = $testCredentials.Name | Get-StoredCredential
    
    Write-Host "Retrieved $($retrievedCreds.Count) credentials:"
    foreach ($cred in $retrievedCreds) {
        if ($cred) {
            Write-Host "  - $($cred.UserName)"
        }
    }
    
    # Clean up using pipeline
    Write-Host "Cleaning up credentials..."
    $testCredentials.Name | Remove-StoredCredential -Force
}
catch {
    Write-Error "Pipeline example failed: $($_.Exception.Message)"
}

# Example 4: Error handling
Write-Host "`n=== Example 4: Error Handling ===" -ForegroundColor Green

try {
    # Try to get a non-existent credential
    Write-Host "Attempting to retrieve non-existent credential..."
    $nonExistent = Get-StoredCredential -Name "DoesNotExist" -ErrorAction SilentlyContinue
    
    if ($null -eq $nonExistent) {
        Write-Host "Correctly returned null for non-existent credential"
    }
    
    # Test non-existent credential
    $doesNotExist = Test-StoredCredential -Name "DoesNotExist"
    Write-Host "Test for non-existent credential: $doesNotExist"
    
    # Try to store credential with empty name (should fail)
    Write-Host "Attempting to store credential with invalid name..."
    try {
        New-StoredCredential -Name "" -UserName "test" -Password (ConvertTo-SecureString "test" -AsPlainText -Force) -ErrorAction Stop
        Write-Warning "This should have failed!"
    }
    catch {
        Write-Host "Correctly rejected empty credential name: $($_.Exception.Message)"
    }
    
    # Try to update non-existent credential without Force
    Write-Host "Attempting to update non-existent credential..."
    try {
        $result = Set-StoredCredential -Name "NonExistent" -UserName "test" -Password (ConvertTo-SecureString "test" -AsPlainText -Force) -ErrorAction Stop
        Write-Warning "This should have failed!"
    }
    catch {
        Write-Host "Correctly rejected update of non-existent credential: $($_.Exception.Message)"
    }
}
catch {
    Write-Error "Error handling example failed: $($_.Exception.Message)"
}

# Example 5: Module information
Write-Host "`n=== Example 5: Module Information ===" -ForegroundColor Green

try {
    $moduleInfo = Get-CredentialStoreInfo
    
    Write-Host "Module Information:"
    Write-Host "  Name: $($moduleInfo.ModuleName)"
    Write-Host "  Version: $($moduleInfo.Version)"
    Write-Host "  Status: $($moduleInfo.Status)"
    Write-Host "  Platform: $($moduleInfo.Platform)"
    Write-Host "  Is Windows: $($moduleInfo.IsWindows)"
    Write-Host "  Is macOS: $($moduleInfo.IsMacOS)"
    Write-Host "  Storage Type: $($moduleInfo.StorageType)"
    Write-Host "  Supported Operations: $($moduleInfo.SupportedOperations -join ', ')"
    
    if ($moduleInfo.Issues.Count -gt 0) {
        Write-Warning "Module issues detected:"
        foreach ($issue in $moduleInfo.Issues) {
            Write-Warning "  - $issue"
        }
    }
}
catch {
    Write-Error "Module info example failed: $($_.Exception.Message)"
}

# Example 6: List all stored credentials
Write-Host "`n=== Example 6: List All Credentials ===" -ForegroundColor Green

try {
    # Store a few test credentials first
    New-StoredCredential -Name "TestList1" -UserName "user1" -Password (ConvertTo-SecureString "pass1" -AsPlainText -Force) -Comment "Test credential 1" -Force
    New-StoredCredential -Name "TestList2" -UserName "user2" -Password (ConvertTo-SecureString "pass2" -AsPlainText -Force) -Comment "Test credential 2" -Force
    
    # List all credentials (no Name parameter)
    Write-Host "Listing all stored credentials..."
    $allCreds = Get-StoredCredential
    
    if ($allCreds) {
        Write-Host "Found $($allCreds.Count) stored credentials:"
        foreach ($cred in $allCreds) {
            Write-Host "  - Name: $($cred.Name), Username: $($cred.UserName)"
        }
    } else {
        Write-Host "No stored credentials found"
    }
    
    # Clean up
    Remove-StoredCredential -Name "TestList1", "TestList2" -Force
}
catch {
    Write-Error "List credentials example failed: $($_.Exception.Message)"
}

Write-Host "`n=== All Examples Complete ===" -ForegroundColor Green
