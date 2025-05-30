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
    $result = Set-PoShCredential -Name "Example1" -Credential $testCredential -Force
    Write-Host "Store result: $result"
    
    # Retrieve the credential
    Write-Host "Retrieving credential 'Example1'..."
    $retrievedCred = Get-PoShCredential -Name "Example1"
    
    if ($retrievedCred) {
        Write-Host "Retrieved username: $($retrievedCred.UserName)"
        Write-Host "Password length: $($retrievedCred.GetNetworkCredential().Password.Length)"
    } else {
        Write-Warning "Failed to retrieve credential"
    }
    
    # Clean up
    Write-Host "Removing credential 'Example1'..."
    $removeResult = Remove-PoShCredential -Name "Example1" -Force
    Write-Host "Remove result: $removeResult"
}
catch {
    Write-Error "Example 1 failed: $($_.Exception.Message)"
}

# Example 2: Machine scope credentials
Write-Host "`n=== Example 2: Machine Scope ===" -ForegroundColor Green

try {
    # Note: Machine scope may require elevated privileges
    $machineTestCred = New-Object PSCredential("MachineUser", (ConvertTo-SecureString "MachinePass123!" -AsPlainText -Force))
    
    Write-Host "Attempting to store machine-scoped credential..."
    $machineResult = Set-PoShCredential -Name "MachineExample" -Credential $machineTestCred -Scope Machine -Force
    
    if ($machineResult) {
        Write-Host "Machine credential stored successfully"
        
        # Retrieve it
        $machineRetrieved = Get-PoShCredential -Name "MachineExample" -Scope Machine
        if ($machineRetrieved) {
            Write-Host "Machine credential retrieved: $($machineRetrieved.UserName)"
        }
        
        # Clean up
        Remove-PoShCredential -Name "MachineExample" -Scope Machine -Force | Out-Null
    } else {
        Write-Warning "Failed to store machine-scoped credential (may need elevated privileges)"
    }
}
catch {
    Write-Warning "Machine scope example failed: $($_.Exception.Message)"
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
        Set-PoShCredential -Name $cred.Name -Credential $cred.Credential -Force | Out-Null
    }
    
    # Retrieve using pipeline
    Write-Host "Retrieving credentials using pipeline..."
    $retrievedCreds = $testCredentials.Name | Get-PoShCredential
    
    Write-Host "Retrieved $($retrievedCreds.Count) credentials:"
    foreach ($cred in $retrievedCreds) {
        if ($cred) {
            Write-Host "  - $($cred.UserName)"
        }
    }
    
    # Clean up using pipeline
    Write-Host "Cleaning up credentials..."
    $testCredentials.Name | ForEach-Object { Remove-PoShCredential -Name $_ -Force } | Out-Null
}
catch {
    Write-Error "Pipeline example failed: $($_.Exception.Message)"
}

# Example 4: Error handling
Write-Host "`n=== Example 4: Error Handling ===" -ForegroundColor Green

try {
    # Try to get a non-existent credential
    Write-Host "Attempting to retrieve non-existent credential..."
    $nonExistent = Get-PoShCredential -Name "DoesNotExist" -ErrorAction SilentlyContinue
    
    if ($null -eq $nonExistent) {
        Write-Host "Correctly returned null for non-existent credential"
    }
    
    # Try to store credential with empty name (should fail)
    Write-Host "Attempting to store credential with invalid name..."
    try {
        Set-PoShCredential -Name "" -Credential $testCredential -ErrorAction Stop
        Write-Warning "This should have failed!"
    }
    catch {
        Write-Host "Correctly rejected empty credential name: $($_.Exception.Message)"
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

Write-Host "`n=== All Examples Complete ===" -ForegroundColor Green
