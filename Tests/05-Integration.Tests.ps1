# Integration Tests - Real World Scenarios
# Tests that verify the module works in realistic user scenarios without mocks

BeforeAll {
    $ModulePath = Split-Path -Parent $PSScriptRoot
    Import-Module "$ModulePath/PSCredentialStore.psd1" -Force
}

Describe "Integration Tests - Real World Scenarios" -Tag "Integration" {
    BeforeEach {
        $script:testId = "IntegrationTest_$(Get-Random)"
        $script:testUser = "integrationuser"
        $script:testPasswordText = "IntegrationPassword123!"
        $script:testPassword = ConvertTo-SecureString $script:testPasswordText -AsPlainText -Force
        $script:testCred = [PSCredential]::new($script:testUser, $script:testPassword)
        
        # Clean up any existing test data
        Remove-StoredCredential -Name $script:testId -Force -ErrorAction SilentlyContinue | Out-Null
    }

    AfterEach {
        # Clean up test credentials
        Remove-StoredCredential -Name $script:testId -Force -ErrorAction SilentlyContinue | Out-Null
        
        # Clean up any credentials that match our test pattern
        Get-StoredCredential | Where-Object { $_.Name -like "*IntegrationTest*" } | ForEach-Object {
            Remove-StoredCredential -Name $_.Name -Force -ErrorAction SilentlyContinue
        }
    }

    Context "End-to-End Workflows" {
        It "Complete workflow: Create -> Retrieve -> Update -> Remove" {
            # Create
            $createResult = New-StoredCredential -Name $script:testId -Credential $script:testCred
            $createResult | Should -Not -BeNullOrEmpty
            $createResult.Name | Should -Be $script:testId
            
            # Retrieve
            $getResult = Get-StoredCredential -Name $script:testId
            $getResult | Should -Not -BeNullOrEmpty
            $getResult.UserName | Should -Be $script:testUser
            
            # Update
            $newPassword = ConvertTo-SecureString "UpdatedPassword456!" -AsPlainText -Force
            $newCred = [PSCredential]::new("updateduser", $newPassword)
            $updateResult = Set-StoredCredential -Name $script:testId -Credential $newCred
            $updateResult.UserName | Should -Be "updateduser"
            
            # Remove
            $removeResult = Remove-StoredCredential -Name $script:testId -Force
            $removeResult | Should -Be $true
            Test-StoredCredential -Name $script:testId | Should -Be $false
        }

        It "Pipeline workflow: Create credential then get plain text" {
            # This tests the exact user scenario that was originally failing
            $createResult = New-StoredCredential -Name $script:testId -Credential $script:testCred
            $createResult | Should -Not -BeNullOrEmpty
            
            # Get plain text version (this was the failing operation)
            $plainResult = Get-StoredCredentialPlainText -Name $script:testId
            $plainResult | Should -Not -BeNullOrEmpty
            $plainResult.Username | Should -Be $script:testUser
            $plainResult.Password | Should -Be $script:testPasswordText
            $plainResult.Name | Should -Be $script:testId
        }

        It "Chained pipeline operations" {
            # Test multiple operations in sequence
            $result = $script:testCred | 
                      New-StoredCredential -Name $script:testId | 
                      ForEach-Object { Get-StoredCredentialPlainText -Name $_.Name }
            
            $result | Should -Not -BeNullOrEmpty
            $result.Username | Should -Be $script:testUser
            $result.Password | Should -Be $script:testPasswordText
        }
    }

    Context "Error Recovery Scenarios" {
        It "Should handle credential conflicts gracefully" {
            # Create initial credential
            New-StoredCredential -Name $script:testId -Credential $script:testCred | Out-Null
            
            # Try to create again (should update, not fail)
            $newCred = [PSCredential]::new("newuser", (ConvertTo-SecureString "NewPass!" -AsPlainText -Force))
            { New-StoredCredential -Name $script:testId -Credential $newCred } | Should -Not -Throw
            
            # Verify the credential was updated
            $result = Get-StoredCredential -Name $script:testId
            $result.UserName | Should -Be "newuser"
        }

        It "Should handle missing credentials gracefully" {
            $nonExistentId = "NonExistent_$(Get-Random)"
            
            $getResult = Get-StoredCredential -Name $nonExistentId
            $getResult | Should -BeNullOrEmpty
            
            $testResult = Test-StoredCredential -Name $nonExistentId
            $testResult | Should -Be $false
            
            $plainResult = Get-StoredCredentialPlainText -Name $nonExistentId
            $plainResult | Should -BeNullOrEmpty
        }

        It "Should handle system-level interruptions" {
            # Create credential
            New-StoredCredential -Name $script:testId -Credential $script:testCred | Out-Null
            
            # Verify it exists
            Test-StoredCredential -Name $script:testId | Should -Be $true
            
            # Multiple rapid operations (simulating concurrent access)
            for ($i = 0; $i -lt 5; $i++) {
                $result = Get-StoredCredential -Name $script:testId
                $result | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context "Data Integrity" {
        It "Should maintain credential data integrity across operations" {
            # Create with specific data
            New-StoredCredential -Name $script:testId -Credential $script:testCred | Out-Null
            
            # Retrieve multiple times and verify consistency
            for ($i = 0; $i -lt 3; $i++) {
                $result = Get-StoredCredential -Name $script:testId
                $result.UserName | Should -Be $script:testUser
                
                $plainResult = Get-StoredCredentialPlainText -Name $script:testId
                $plainResult.Username | Should -Be $script:testUser
                $plainResult.Password | Should -Be $script:testPasswordText
            }
        }

        It "Should handle special characters in all operations" {
            $specialUser = "user@domain.com"
            $specialPassword = ConvertTo-SecureString "P@ssw0rd!@#$%^&*()" -AsPlainText -Force
            $specialCred = [PSCredential]::new($specialUser, $specialPassword)
            
            # Full workflow with special characters
            New-StoredCredential -Name $script:testId -Credential $specialCred | Out-Null
            
            $getResult = Get-StoredCredential -Name $script:testId
            $getResult.UserName | Should -Be $specialUser
            
            $plainResult = Get-StoredCredentialPlainText -Name $script:testId
            $plainResult.Username | Should -Be $specialUser
            $plainResult.Password | Should -Be "P@ssw0rd!@#$%^&*()"
        }
    }

    Context "Performance and Reliability" {
        It "Should handle multiple credentials efficiently" {
            $credentialIds = @()
            
            try {
                # Create multiple credentials
                for ($i = 0; $i -lt 5; $i++) {
                    $id = "PerfTest_$i_$(Get-Random)"
                    $credentialIds += $id
                    $cred = [PSCredential]::new("user$i", (ConvertTo-SecureString "Pass$i!" -AsPlainText -Force))
                    New-StoredCredential -Name $id -Credential $cred | Out-Null
                }
                
                # Verify all can be retrieved
                foreach ($id in $credentialIds) {
                    $result = Get-StoredCredential -Name $id
                    $result | Should -Not -BeNullOrEmpty
                }
                
                # Verify plain text retrieval works for all
                foreach ($id in $credentialIds) {
                    $result = Get-StoredCredentialPlainText -Name $id
                    $result | Should -Not -BeNullOrEmpty
                }
            }
            finally {
                # Clean up all test credentials
                foreach ($id in $credentialIds) {
                    Remove-StoredCredential -Name $id -Force -ErrorAction SilentlyContinue | Out-Null
                }
            }
        }

        It "Should maintain performance under load" {
            New-StoredCredential -Name $script:testId -Credential $script:testCred | Out-Null
            
            # Rapid successive calls should all succeed
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            for ($i = 0; $i -lt 10; $i++) {
                $result = Get-StoredCredentialPlainText -Name $script:testId
                $result | Should -Not -BeNullOrEmpty
            }
            
            $stopwatch.Stop()
            # Should complete within reasonable time (less than 5 seconds for 10 operations)
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 5000
        }
    }
}
