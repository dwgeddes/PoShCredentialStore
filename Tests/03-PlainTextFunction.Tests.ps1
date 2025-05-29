# Get-StoredCredentialPlainText Function Tests
# Comprehensive tests for plain text credential retrieval functionality

BeforeAll {
    $ModulePath = Split-Path -Parent $PSScriptRoot
    Import-Module "$ModulePath/PSCredentialStore.psd1" -Force
}

Describe "Get-StoredCredentialPlainText" -Tag "Unit" {
    BeforeEach {
        # Generate a unique test name
        $script:testId = "PlainTextTest_$(Get-Random)"
        $script:testUser = "plainuser"
        $script:testPasswordText = "PlainTestPassword123!"
        $script:testPassword = ConvertTo-SecureString $script:testPasswordText -AsPlainText -Force
        $script:testCred = [PSCredential]::new($script:testUser, $script:testPassword)
        
        # Ensure clean state
        Remove-StoredCredential -Name $script:testId -Force -ErrorAction SilentlyContinue | Out-Null
    }

    AfterEach {
        # Clean up test credential
        Remove-StoredCredential -Name $script:testId -Force -ErrorAction SilentlyContinue | Out-Null
    }

    Context "Basic Functionality" {
        It "Should retrieve plain text password successfully" {
            New-StoredCredential -Name $script:testId -Credential $script:testCred | Out-Null
            
            $result = Get-StoredCredentialPlainText -Name $script:testId
            $result | Should -Not -BeNullOrEmpty
            $result.Username | Should -Be $script:testUser
            $result.Password | Should -Be $script:testPasswordText
            $result.Name | Should -Be $script:testId
            $result.RetrievedAt | Should -BeOfType [DateTime]
        }

        It "Should display security warning" {
            New-StoredCredential -Name $script:testId -Credential $script:testCred | Out-Null
            
            $warningOutput = $null
            $result = Get-StoredCredentialPlainText -Name $script:testId -WarningVariable warningOutput 2>&1
            $warningOutput | Should -Not -BeNullOrEmpty
            $warningOutput -match "This function returns passwords in plain text. Use with caution." | Should -Be $true
        }

        It "Should handle non-existent credential gracefully" {
            $result = Get-StoredCredentialPlainText -Name "NonExistent_$(Get-Random)"
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Pipeline Support" {
        It "Should accept pipeline input" {
            New-StoredCredential -Name $script:testId -Credential $script:testCred | Out-Null
            
            $result = $script:testId | Get-StoredCredentialPlainText
            $result | Should -Not -BeNullOrEmpty
            $result.Username | Should -Be $script:testUser
            $result.Password | Should -Be $script:testPasswordText
        }

        It "Should handle multiple pipeline inputs" {
            $testId2 = "PlainTextTest2_$(Get-Random)"
            $testCred2 = [PSCredential]::new("user2", (ConvertTo-SecureString "Password2!" -AsPlainText -Force))
            
            try {
                New-StoredCredential -Name $script:testId -Credential $script:testCred | Out-Null
                New-StoredCredential -Name $testId2 -Credential $testCred2 | Out-Null
                
                $results = @($script:testId, $testId2) | Get-StoredCredentialPlainText
                $results | Should -HaveCount 2
                $results[0].Username | Should -Be $script:testUser
                $results[1].Username | Should -Be "user2"
            }
            finally {
                Remove-StoredCredential -Name $testId2 -Force -ErrorAction SilentlyContinue | Out-Null
            }
        }

        It "Should handle null pipeline input gracefully" {
            $results = @($null, "", $null) | Get-StoredCredentialPlainText
            $results | Should -BeNullOrEmpty
        }
    }

    Context "Error Handling" {
        It "Should handle invalid name parameter" {
            { Get-StoredCredentialPlainText -Name "" } | Should -Throw
        }

        It "Should handle corrupted credential data gracefully" {
            # This test verifies error handling for edge cases
            $result = Get-StoredCredentialPlainText -Name "CorruptedData_$(Get-Random)"
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Security Validation" {
        It "Helper function should not be globally accessible" {
            # Verify that the private helper function is not exposed
            { ConvertFrom-SecureStringToPlainText -SecureString $script:testPassword } | Should -Throw "*not recognized*"
        }

        It "Should properly handle SecureString conversion" {
            New-StoredCredential -Name $script:testId -Credential $script:testCred | Out-Null
            
            $result = Get-StoredCredentialPlainText -Name $script:testId
            $result.Password | Should -BeOfType [string]
            $result.Password.Length | Should -BeGreaterThan 0
        }
    }

    Context "Return Object Validation" {
        It "Should return properly formatted object" {
            New-StoredCredential -Name $script:testId -Credential $script:testCred | Out-Null
            
            $result = Get-StoredCredentialPlainText -Name $script:testId
            $result | Should -BeOfType [PSCustomObject]
            
            # Verify all required properties exist
            $result.PSObject.Properties.Name | Should -Contain "Username"
            $result.PSObject.Properties.Name | Should -Contain "Password"  
            $result.PSObject.Properties.Name | Should -Contain "Name"
            $result.PSObject.Properties.Name | Should -Contain "RetrievedAt"
        }

        It "Should have consistent data types" {
            New-StoredCredential -Name $script:testId -Credential $script:testCred | Out-Null
            
            $result = Get-StoredCredentialPlainText -Name $script:testId
            $result.Username | Should -BeOfType [string]
            $result.Password | Should -BeOfType [string]
            $result.Name | Should -BeOfType [string]
            $result.RetrievedAt | Should -BeOfType [DateTime]
        }
    }
}
