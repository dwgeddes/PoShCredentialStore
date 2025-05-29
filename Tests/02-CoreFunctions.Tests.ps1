# Core Functionality Tests
# Tests for basic CRUD operations: New, Get, Set, Remove, Test

BeforeAll {
    $ModulePath = Split-Path -Parent $PSScriptRoot
    Import-Module "$ModulePath/PSCredentialStore.psd1" -Force
}

Describe "Core CRUD Operations" -Tag "Unit" {
    BeforeEach {
        # Generate unique test credentials for each test
        $script:testId = "CoreTest_$(Get-Random)"
        $script:testUser = "testuser"
        $script:testPassword = ConvertTo-SecureString "TestPassword123!" -AsPlainText -Force
        $script:testCred = [PSCredential]::new($script:testUser, $script:testPassword)
        
        # Ensure clean state
        Remove-StoredCredential -Name $script:testId -Force -ErrorAction SilentlyContinue | Out-Null
    }

    AfterEach {
        # Clean up test credentials
        Remove-StoredCredential -Name $script:testId -Force -ErrorAction SilentlyContinue | Out-Null
    }

    Context "New-StoredCredential" {
        It "Should create a new credential successfully" {
            $result = New-StoredCredential -Name $script:testId -Credential $script:testCred
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $script:testId
            $result.UserName | Should -Be $script:testUser
        }

        It "Should handle pipeline input" {
            $result = $script:testCred | New-StoredCredential -Name $script:testId
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $script:testId
        }

        It "Should fail with invalid name" {
            { New-StoredCredential -Name "" -Credential $script:testCred } | Should -Throw
        }
    }

    Context "Get-StoredCredential" {
        It "Should retrieve existing credential" {
            New-StoredCredential -Name $script:testId -Credential $script:testCred | Out-Null
            
            $result = Get-StoredCredential -Name $script:testId
            $result | Should -Not -BeNullOrEmpty
            $result.UserName | Should -Be $script:testUser
            $result.Credential | Should -BeOfType [PSCredential]
        }

        It "Should throw error for non-existent credential" {
            $testName = "NonExistent_$(Get-Random)"
            { Get-StoredCredential -Name $testName } | Should -Throw "*was not found in the credential store*"
        }

        It "Should handle pipeline input" {
            New-StoredCredential -Name $script:testId -Credential $script:testCred | Out-Null
            
            $result = $script:testId | Get-StoredCredential
            $result | Should -Not -BeNullOrEmpty
            $result.UserName | Should -Be $script:testUser
        }
    }

    Context "Test-StoredCredential" {
        It "Should return true for existing credential" {
            New-StoredCredential -Name $script:testId -Credential $script:testCred | Out-Null
            
            $result = Test-StoredCredential -Name $script:testId
            $result | Should -Be $true
        }

        It "Should return false for non-existent credential" {
            $result = Test-StoredCredential -Name "NonExistent_$(Get-Random)"
            $result | Should -Be $false
        }
    }

    Context "Remove-StoredCredential" {
        It "Should remove existing credential" {
            New-StoredCredential -Name $script:testId -Credential $script:testCred | Out-Null
            
            $result = Remove-StoredCredential -Name $script:testId -Force
            $result | Should -Not -BeNullOrEmpty
            $result.Result | Should -Be "Removed"
            
            Test-StoredCredential -Name $script:testId | Should -Be $false
        }

        It "Should handle non-existent credential gracefully" {
            $testName = "NonExistent_$(Get-Random)"
            $result = Remove-StoredCredential -Name $testName -Force
            $result | Should -Not -BeNullOrEmpty
            $result.Result | Should -Be "Skipped"
            $result.Message | Should -Be "Credential does not exist"
        }
    }

    Context "Set-StoredCredential" {
        It "Should update existing credential" {
            New-StoredCredential -Name $script:testId -Credential $script:testCred | Out-Null
            
            $newPassword = ConvertTo-SecureString "NewPassword456!" -AsPlainText -Force
            $newCred = [PSCredential]::new("newuser", $newPassword)
            
            $result = Set-StoredCredential -Name $script:testId -Credential $newCred
            $result | Should -Not -BeNullOrEmpty
            $result.UserName | Should -Be "newuser"
        }

        It "Should create credential if it doesn't exist" {
            $result = Set-StoredCredential -Name $script:testId -Credential $script:testCred
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be $script:testId
        }
    }
}
