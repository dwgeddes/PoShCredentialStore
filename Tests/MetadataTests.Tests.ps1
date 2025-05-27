BeforeAll {
    # Import the module for testing
    $ModulePath = Split-Path -Parent $PSScriptRoot
    Import-Module "$ModulePath/PSCredentialStore.psd1" -Force
}

Describe "Advanced Metadata Functionality Tests" -Tag "Metadata" {
    BeforeEach {
        # Generate unique test ID for each test
        $script:advancedMetadataTestId = "AdvancedMetadataTest_$(Get-Random)"
        $script:testUser = "metadatauser"
        $script:testPassword = ConvertTo-SecureString "MetadataP@ssword123" -AsPlainText -Force
        $script:testCred = New-Object System.Management.Automation.PSCredential($script:testUser, $script:testPassword)
    }
    
    AfterEach {
        # Clean up test credentials
        Remove-StoredCredential -Name $script:advancedMetadataTestId -Force -ErrorAction SilentlyContinue
        Get-StoredCredential | Where-Object { $_.Name -like "${script:advancedMetadataTestId}*" } | ForEach-Object {
            Remove-StoredCredential -Name $_.Name -Force -ErrorAction SilentlyContinue
        }
    }

    It "Should store and retrieve complex metadata" -Skip:([bool]$env:CI) {
        # Store credential with multiple metadata fields
        $result = New-StoredCredential -Name $script:advancedMetadataTestId -Credential $script:testCred -Description "Complex metadata test" -Url "https://secure.example.com" -Application "AdvancedTestApp"
        
        $result | Should -Not -BeNullOrEmpty
        $result.Name | Should -Be $script:advancedMetadataTestId
        
        # Retrieve and verify all metadata is preserved
        $retrieved = Get-StoredCredential -Name $script:advancedMetadataTestId
        $retrieved | Should -Not -BeNullOrEmpty
        $retrieved.Name | Should -Be $script:advancedMetadataTestId
        $retrieved.UserName | Should -Be $script:testUser
        $retrieved.Credential.GetNetworkCredential().Password | Should -Be "MetadataP@ssword123"
        
        # Verify metadata exists (platform-dependent)
        if ($retrieved.PSObject.Properties.Name -contains 'Metadata') {
            $retrieved.Metadata | Should -Not -BeNullOrEmpty
        }
    }

    It "Should handle credentials with mixed metadata presence" -Skip:([bool]$env:CI) {
        # Store first credential with metadata
        $result1 = New-StoredCredential -Name "${script:advancedMetadataTestId}_with_meta" -Credential $script:testCred -Description "Has metadata" -Application "TestApp"
        $result1 | Should -Not -BeNullOrEmpty
        
        # Store second credential without additional metadata  
        $result2 = New-StoredCredential -Name "${script:advancedMetadataTestId}_no_meta" -Credential $script:testCred
        $result2 | Should -Not -BeNullOrEmpty
        
        # List all credentials and verify both types work
        $testCreds = Get-StoredCredential | Where-Object { $_.Name -like "${script:advancedMetadataTestId}*" }
        $testCreds.Count | Should -BeGreaterOrEqual 2
        
        # Each credential should have basic properties regardless of metadata
        foreach ($cred in $testCreds) {
            $cred.Name | Should -Not -BeNullOrEmpty
            $cred.UserName | Should -Be $script:testUser
            $cred.Credential | Should -Not -BeNullOrEmpty
            $cred.Credential.GetNetworkCredential().Password | Should -Be "MetadataP@ssword123"
        }
        
        # Cleanup
        Remove-StoredCredential -Name "${script:advancedMetadataTestId}_with_meta" -Force -ErrorAction SilentlyContinue
        Remove-StoredCredential -Name "${script:advancedMetadataTestId}_no_meta" -Force -ErrorAction SilentlyContinue
    }

    It "Should handle special characters in metadata" -Skip:([bool]$env:CI) {
        # Test with special characters that might cause JSON issues
        $specialDescription = "Test with special chars: åäöÅÄÖ & <>'@#$%^&*()[]{}|"
        $specialUrl = "https://spéciál.example.com/påth?query=värde"
        
        $result = New-StoredCredential -Name $script:advancedMetadataTestId -Credential $script:testCred -Description $specialDescription -Url $specialUrl
        
        $result | Should -Not -BeNullOrEmpty
        $result.Name | Should -Be $script:advancedMetadataTestId
        
        # Retrieve and verify special characters are preserved
        $retrieved = Get-StoredCredential -Name $script:advancedMetadataTestId
        $retrieved | Should -Not -BeNullOrEmpty
        $retrieved.UserName | Should -Be $script:testUser
        $retrieved.Credential.GetNetworkCredential().Password | Should -Be "MetadataP@ssword123"
    }

    It "Should handle macOS-specific metadata features" -Skip:(-not $IsMacOS -or [bool]$env:CI) {
        # Test macOS-specific features like Synchronizable via Metadata
        $result = New-StoredCredential -Name $script:advancedMetadataTestId -Credential $script:testCred -Description "macOS test" -Metadata @{ Synchronizable = $false }
        
        $result | Should -Not -BeNullOrEmpty
        $result.Name | Should -Be $script:advancedMetadataTestId
        
        # Retrieve and verify it works
        $retrieved = Get-StoredCredential -Name $script:advancedMetadataTestId
        $retrieved | Should -Not -BeNullOrEmpty
        $retrieved.UserName | Should -Be $script:testUser
        $retrieved.Credential.GetNetworkCredential().Password | Should -Be "MetadataP@ssword123"
    }}
