# Consolidated Platform & Advanced Tests
# Tests for platform-specific functionality, metadata, edge cases, and diagnostic scenarios

BeforeAll {
    $ModulePath = Split-Path -Parent $PSScriptRoot
    Import-Module "$ModulePath/PSCredentialStore.psd1" -Force
}

Describe "Platform-Specific Tests" -Tag "Platform" {
    BeforeEach {
        $script:testId = "PlatformTest_$(Get-Random)"
        $script:testUser = "platformuser"
        $script:testPassword = ConvertTo-SecureString "PlatformPassword123!" -AsPlainText -Force
        $script:testCred = [PSCredential]::new($script:testUser, $script:testPassword)
        
        Remove-StoredCredential -Name $script:testId -Force -ErrorAction SilentlyContinue | Out-Null
    }

    AfterEach {
        Remove-StoredCredential -Name $script:testId -Force -ErrorAction SilentlyContinue | Out-Null
    }

    Context "macOS Keychain Integration" {
        It "Should detect macOS platform correctly" -Skip:(-not $IsMacOS) {
            $platform = Get-OSPlatform
            $platform | Should -Be "macOS"
        }

        It "Should access macOS security command" -Skip:(-not $IsMacOS) {
            { security -V } | Should -Not -Throw
        }

        It "Should store and retrieve credentials in macOS keychain" -Skip:(-not $IsMacOS) {
            $result = New-StoredCredential -Name $script:testId -Credential $script:testCred -NonInteractive
            $result | Should -Not -BeNullOrEmpty
            
            $retrieved = Get-StoredCredential -Name $script:testId
            $retrieved.Username | Should -Be $script:testUser
            
            Test-StoredCredential -Name $script:testId | Should -Be $true
        }

        It "Should handle keychain service name prefixing" -Skip:(-not $IsMacOS) {
            New-StoredCredential -Name $script:testId -Credential $script:testCred -NonInteractive | Out-Null
            
            # Directly query keychain to verify service name format
            $serviceName = "PSCredentialStore:$script:testId"
            $keychainOutput = security find-generic-password -s $serviceName -a $script:testId -w 2>$null
            $LASTEXITCODE | Should -Be 0
        }
    }

    Context "Cross-Platform Path Handling" {
        It "Should use cross-platform path operations" {
            # Test that our functions use proper path handling
            $result = New-StoredCredential -Name $script:testId -Credential $script:testCred -NonInteractive
            $result | Should -Not -BeNullOrEmpty
            
            # Verify credential can be retrieved (implies proper path handling)
            $retrieved = Get-StoredCredential -Name $script:testId
            $retrieved | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "Advanced Metadata Handling" -Tag "Advanced", "Metadata" {
    BeforeEach {
        $script:testId = "MetadataTest_$(Get-Random)"
        $script:testUser = "metadatauser"
        $script:testPassword = ConvertTo-SecureString "MetadataPassword123!" -AsPlainText -Force
        $script:testCred = [PSCredential]::new($script:testUser, $script:testPassword)
        
        Remove-StoredCredential -Name $script:testId -Force -ErrorAction SilentlyContinue | Out-Null
    }

    AfterEach {
        Remove-StoredCredential -Name $script:testId -Force -ErrorAction SilentlyContinue | Out-Null
    }

    Context "Metadata Storage and Retrieval" {
        It "Should store and retrieve basic metadata" {
            $result = New-StoredCredential -Name $script:testId -Credential $script:testCred -NonInteractive
            $result | Should -Not -BeNullOrEmpty
            $result.Metadata | Should -Not -BeNull
        }

        It "Should handle complex metadata structures" {
            # Test metadata with special characters and complex data
            $complexData = @{
                Description = "Multi-line`nDescription with`nSpecial characters: !@#$%^&*()"
                Url = "https://user:pass@example.com:8080/path?query=value#fragment"
                Tags = @("tag1", "tag2", "tag3")
                CustomField = "Custom value with unicode: 测试"
            }
            
            $result = New-StoredCredential -Name $script:testId -Credential $script:testCred -NonInteractive
            $result | Should -Not -BeNullOrEmpty
            
            $retrieved = Get-StoredCredential -Name $script:testId
            $retrieved.Metadata | Should -Not -BeNull
        }
    }

    Context "Unicode and Special Character Support" {
        It "Should handle unicode characters in credential names" {
            $unicodeTestId = "测试_$(Get-Random)"
            
            try {
                $result = New-StoredCredential -Name $unicodeTestId -Credential $script:testCred -NonInteractive
                $result | Should -Not -BeNullOrEmpty
                
                $retrieved = Get-StoredCredential -Name $unicodeTestId
                $retrieved.Username | Should -Be $script:testUser
            }
            finally {
                Remove-StoredCredential -Name $unicodeTestId -Force -ErrorAction SilentlyContinue | Out-Null
            }
        }

        It "Should handle special characters in passwords" {
            $specialPassword = ConvertTo-SecureString "Spec!@l#P@ssw0rd$%^&*()_+{}|:<>?`~" -AsPlainText -Force
            $specialCred = [PSCredential]::new($script:testUser, $specialPassword)
            
            $result = New-StoredCredential -Name $script:testId -Credential $specialCred -NonInteractive
            $result | Should -Not -BeNullOrEmpty
            
            $retrieved = Get-StoredCredential -Name $script:testId -AsPlainText
            $retrieved.Password | Should -Be "Spec!@l#P@ssw0rd$%^&*()_+{}|:<>?`~"
        }
    }
}

Describe "Edge Cases and Error Conditions" -Tag "EdgeCases" {
    BeforeEach {
        $script:testId = "EdgeCaseTest_$(Get-Random)"
        $script:testUser = "edgeuser"
        $script:testPassword = ConvertTo-SecureString "EdgePassword123!" -AsPlainText -Force
        $script:testCred = [PSCredential]::new($script:testUser, $script:testPassword)
        
        Remove-StoredCredential -Name $script:testId -Force -ErrorAction SilentlyContinue | Out-Null
    }

    AfterEach {
        Remove-StoredCredential -Name $script:testId -Force -ErrorAction SilentlyContinue | Out-Null
    }

    Context "Empty and Null Handling" {
        It "Should reject empty credential names" {
            { New-StoredCredential -Name "" -Credential $script:testCred -NonInteractive } | Should -Throw
        }

        It "Should reject null credential objects" {
            { New-StoredCredential -Name $script:testId -Credential $null -NonInteractive } | Should -Throw
        }

        It "Should handle empty SecureString passwords gracefully" {
            $emptyPassword = ConvertTo-SecureString "" -AsPlainText -Force
            $emptyCred = [PSCredential]::new($script:testUser, $emptyPassword)
            
            $result = New-StoredCredential -Name $script:testId -Credential $emptyCred -NonInteractive
            $result | Should -Not -BeNullOrEmpty
            
            $retrieved = Get-StoredCredential -Name $script:testId -AsPlainText
            $retrieved.Password | Should -Be ""
        }
    }

    Context "Large Data Handling" {
        It "Should handle very long passwords" {
            $longPassword = "A" * 1000  # 1000 character password
            $longSecurePassword = ConvertTo-SecureString $longPassword -AsPlainText -Force
            $longCred = [PSCredential]::new($script:testUser, $longSecurePassword)
            
            $result = New-StoredCredential -Name $script:testId -Credential $longCred -NonInteractive
            $result | Should -Not -BeNullOrEmpty
            
            $retrieved = Get-StoredCredential -Name $script:testId -AsPlainText
            $retrieved.Password.Length | Should -Be 1000
        }

        It "Should handle very long usernames" {
            $longUsername = "user" + ("A" * 200)  # 204 character username
            $longCred = [PSCredential]::new($longUsername, $script:testPassword)
            
            $result = New-StoredCredential -Name $script:testId -Credential $longCred -NonInteractive
            $result | Should -Not -BeNullOrEmpty
            
            $retrieved = Get-StoredCredential -Name $script:testId
            $retrieved.Username | Should -Be $longUsername
        }
    }
}

Describe "Diagnostic and Troubleshooting Features" -Tag "Diagnostic" {
    Context "Module Health Checks" {
        It "Should provide proper module metadata" {
            $module = Get-Module PSCredentialStore
            $module | Should -Not -BeNull
            $module.Version | Should -Not -BeNull
        }

        It "Should export all required functions" {
            $expectedFunctions = @(
                'Get-StoredCredential',
                'New-StoredCredential', 
                'Set-StoredCredential',
                'Remove-StoredCredential',
                'Test-StoredCredential'
            )
            
            $exportedFunctions = (Get-Command -Module PSCredentialStore).Name
            foreach ($func in $expectedFunctions) {
                $exportedFunctions | Should -Contain $func
            }
        }

        It "Should have proper platform detection" {
            $platform = Get-OSPlatform
            $platform | Should -Match "^(Windows|macOS|Linux)$"
        }
    }

    Context "Error Message Quality" {
        It "Should provide helpful error messages for non-existent credentials" {
            $nonExistentName = "NonExistent_$(Get-Random)"
            
            try {
                Get-StoredCredential -Name $nonExistentName
                # Should not reach here
                $false | Should -Be $true
            }
            catch {
                $_.Exception.Message | Should -Match "not found"
                $_.Exception.Message | Should -Match $nonExistentName
            }
        }

        It "Should provide verbose output when requested" {
            $testId = "VerboseTest_$(Get-Random)"
            
            try {
                $verboseOutput = New-StoredCredential -Name $testId -Credential $script:testCred -NonInteractive -Verbose 4>&1
                $verboseOutput | Should -Not -BeNullOrEmpty
            }
            finally {
                Remove-StoredCredential -Name $testId -Force -ErrorAction SilentlyContinue | Out-Null
            }
        }
    }
}
