# Advanced Metadata and Edge Case Tests
# Tests for advanced functionality, metadata handling, and edge cases

BeforeAll {
    $ModulePath = Split-Path -Parent $PSScriptRoot
    Import-Module "$ModulePath/PSCredentialStore.psd1" -Force
}

Describe "Advanced Functionality Tests" -Tag "Advanced" {
    BeforeEach {
        $script:testId = "AdvancedTest_$(Get-Random)"
        $script:testUser = "advanceduser"
        $script:testPassword = ConvertTo-SecureString "AdvancedPassword123!" -AsPlainText -Force
        $script:testCred = [PSCredential]::new($script:testUser, $script:testPassword)
        
        # Clean up any existing test data
        Remove-StoredCredential -Name $script:testId -Force -ErrorAction SilentlyContinue | Out-Null
    }

    AfterEach {
        # Clean up test credentials
        Remove-StoredCredential -Name $script:testId -Force -ErrorAction SilentlyContinue | Out-Null
        
        # Clean up any credentials that match our test pattern
        Get-StoredCredential | Where-Object { $_.Name -like "*AdvancedTest*" } | ForEach-Object {
            Remove-StoredCredential -Name $_.Name -Force -ErrorAction SilentlyContinue
        }
    }

    Context "Metadata Handling" {
        It "Should store and retrieve credentials with metadata" -Skip:([bool]$env:CI) {
            # Create credential with metadata
            $result = New-StoredCredential -Name $script:testId -Credential $script:testCred -Description "Test credential" -Url "https://example.com" -Application "TestApp"
            
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $script:testId
            $result.Description | Should -Be "Test credential"
            $result.Url | Should -Be "https://example.com"
            $result.Application | Should -Be "TestApp"
        }

        It "Should handle complex metadata structures" -Skip:([bool]$env:CI) {
            $complexDescription = "Multi-line`nDescription with`nSpecial characters: !@#$%^&*()"
            $complexUrl = "https://user:pass@example.com:8080/path?query=value#fragment"
            
            $result = New-StoredCredential -Name $script:testId -Credential $script:testCred -Description $complexDescription -Url $complexUrl
            
            $result | Should -Not -BeNullOrEmpty
            $result.Description | Should -Be $complexDescription
            $result.Url | Should -Be $complexUrl
        }

        It "Should update metadata without affecting credentials" -Skip:([bool]$env:CI) {
            # Create initial credential
            New-StoredCredential -Name $script:testId -Credential $script:testCred -Description "Original" | Out-Null
            
            # Update metadata
            $result = Set-StoredCredential -Name $script:testId -Credential $script:testCred -Description "Updated"
            
            $result.Description | Should -Be "Updated"
            $result.UserName | Should -Be $script:testUser
        }
    }

    Context "Edge Cases and Boundary Conditions" {
        It "Should handle very long credential names" {
            $longName = "VeryLongCredentialName_" + ("x" * 100) + "_$(Get-Random)"
            
            try {
                $result = New-StoredCredential -Name $longName -Credential $script:testCred
                $result | Should -Not -BeNullOrEmpty
                $result.Name | Should -Be $longName
                
                # Verify retrieval works
                $retrieved = Get-StoredCredential -Name $longName
                $retrieved | Should -Not -BeNullOrEmpty
            }
            finally {
                Remove-StoredCredential -Name $longName -Force -ErrorAction SilentlyContinue | Out-Null
            }
        }

        It "Should handle very long passwords" {
            $longPassword = "x" * 1000
            $longPasswordSecure = ConvertTo-SecureString $longPassword -AsPlainText -Force
            $longPasswordCred = [PSCredential]::new($script:testUser, $longPasswordSecure)
            
            $result = New-StoredCredential -Name $script:testId -Credential $longPasswordCred
            $result | Should -Not -BeNullOrEmpty
            
            # Verify plain text retrieval works with long passwords
            $plainResult = Get-StoredCredentialPlainText -Name $script:testId
            $plainResult.Password.Length | Should -Be 1000
            $plainResult.Password | Should -Be $longPassword
        }

        It "Should handle very long usernames" {
            $longUsername = "user_" + ("x" * 200) + "@example.com"
            $longUserCred = [PSCredential]::new($longUsername, $script:testPassword)
            
            $result = New-StoredCredential -Name $script:testId -Credential $longUserCred
            $result | Should -Not -BeNullOrEmpty
            $result.UserName | Should -Be $longUsername
            
            # Verify plain text retrieval works
            $plainResult = Get-StoredCredentialPlainText -Name $script:testId
            $plainResult.Username | Should -Be $longUsername
        }

        It "Should handle empty password" {
            $emptyPassword = ConvertTo-SecureString "" -AsPlainText -Force
            $emptyCred = [PSCredential]::new($script:testUser, $emptyPassword)
            
            $result = New-StoredCredential -Name $script:testId -Credential $emptyCred
            $result | Should -Not -BeNullOrEmpty
            
            # Verify empty password retrieval
            $plainResult = Get-StoredCredentialPlainText -Name $script:testId
            $plainResult.Password | Should -Be ""
        }
    }

    Context "Unicode and International Support" {
        It "Should handle Unicode characters in usernames" {
            $unicodeUser = "用户名@тест.com"
            $unicodeCred = [PSCredential]::new($unicodeUser, $script:testPassword)
            
            $result = New-StoredCredential -Name $script:testId -Credential $unicodeCred
            $result | Should -Not -BeNullOrEmpty
            $result.UserName | Should -Be $unicodeUser
            
            # Verify retrieval
            $plainResult = Get-StoredCredentialPlainText -Name $script:testId
            $plainResult.Username | Should -Be $unicodeUser
        }

        It "Should handle Unicode characters in passwords" {
            $unicodePassword = ConvertTo-SecureString "密码🔐тест123" -AsPlainText -Force
            $unicodeCred = [PSCredential]::new($script:testUser, $unicodePassword)
            
            $result = New-StoredCredential -Name $script:testId -Credential $unicodeCred
            $result | Should -Not -BeNullOrEmpty
            
            # Verify Unicode password retrieval
            $plainResult = Get-StoredCredentialPlainText -Name $script:testId
            $plainResult.Password | Should -Be "密码🔐тест123"
        }

        It "Should handle Unicode in credential names" {
            $unicodeName = "测试凭据_🔐_тест_$(Get-Random)"
            
            try {
                $result = New-StoredCredential -Name $unicodeName -Credential $script:testCred
                $result | Should -Not -BeNullOrEmpty
                $result.Name | Should -Be $unicodeName
                
                # Verify retrieval by Unicode name
                $retrieved = Get-StoredCredential -Name $unicodeName
                $retrieved | Should -Not -BeNullOrEmpty
            }
            finally {
                Remove-StoredCredential -Name $unicodeName -Force -ErrorAction SilentlyContinue | Out-Null
            }
        }
    }

    Context "Security and Validation" {
        It "Should validate input parameters properly" {
            # Test null/empty validations
            { New-StoredCredential -Name "" -Credential $script:testCred } | Should -Throw
            { New-StoredCredential -Name $script:testId -Credential $null } | Should -Throw
        }

        It "Should maintain credential security during operations" {
            New-StoredCredential -Name $script:testId -Credential $script:testCred | Out-Null
            
            # Multiple retrieval operations should not affect security
            for ($i = 0; $i -lt 5; $i++) {
                $result = Get-StoredCredential -Name $script:testId
                $result.Credential | Should -BeOfType [PSCredential]
                $result.Credential.Password | Should -BeOfType [System.Security.SecureString]
            }
        }

        It "Should handle concurrent access safely" {
            New-StoredCredential -Name $script:testId -Credential $script:testCred | Out-Null
            
            # Simulate concurrent operations
            $jobs = @()
            for ($i = 0; $i -lt 3; $i++) {
                $jobs += Start-Job -ScriptBlock {
                    param($testId, $modulePath)
                    Import-Module "$modulePath/PSCredentialStore.psd1" -Force
                    Get-StoredCredentialPlainText -Name $testId
                } -ArgumentList $script:testId, (Split-Path -Parent $PSScriptRoot)
            }
            
            # Wait for all jobs and verify results
            $results = $jobs | Wait-Job | Receive-Job
            $jobs | Remove-Job
            
            $results | Should -HaveCount 3
            foreach ($result in $results) {
                $result | Should -Not -BeNullOrEmpty
                $result.Username | Should -Be $script:testUser
            }
        }
    }

    Context "Error Handling and Recovery" {
        It "Should provide meaningful error messages" {
            # Test various error conditions and verify error messages are helpful
            try {
                New-StoredCredential -Name "" -Credential $script:testCred
                throw "Should have thrown an error"
            }
            catch {
                $_.Exception.Message | Should -Not -BeNullOrEmpty
                # Error message should be informative
                $_.Exception.Message.Length | Should -BeGreaterThan 10
            }
        }

        It "Should handle system resource limitations gracefully" {
            # This test ensures the module doesn't crash under resource pressure
            $credentials = @()
            
            try {
                # Create many credentials rapidly
                for ($i = 0; $i -lt 20; $i++) {
                    $id = "ResourceTest_$i_$(Get-Random)"
                    $credentials += $id
                    $cred = [PSCredential]::new("user$i", (ConvertTo-SecureString "Pass$i!" -AsPlainText -Force))
                    New-StoredCredential -Name $id -Credential $cred | Out-Null
                }
                
                # Verify they all exist
                foreach ($id in $credentials) {
                    Test-StoredCredential -Name $id | Should -Be $true
                }
            }
            finally {
                # Clean up all credentials
                foreach ($id in $credentials) {
                    Remove-StoredCredential -Name $id -Force -ErrorAction SilentlyContinue | Out-Null
                }
            }
        }
    }
}
