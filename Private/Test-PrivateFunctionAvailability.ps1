function Test-PrivateFunctionAvailability {
    <#
    .SYNOPSIS
    Tests whether all required private functions are available in the module scope.
    
    .DESCRIPTION
    Validates that all private functions referenced by public functions are properly loaded
    and accessible in the module scope.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()
    
    $requiredFunctions = @(
        'Get-CredentialStorePath',
        'ConvertTo-SecureCredential', 
        'ConvertFrom-SecureCredential',
        'Get-WindowsCredential',
        'Set-WindowsCredential',
        'Remove-WindowsCredential'
    )
    
    $results = @{
        AllAvailable = $true
        MissingFunctions = @()
        AvailableFunctions = @()
        TestResults = @{}
    }
    
    foreach ($functionName in $requiredFunctions) {
        try {
            $command = Get-Command $functionName -ErrorAction Stop
            $results.AvailableFunctions += $functionName
            $results.TestResults[$functionName] = @{
                Available = $true
                CommandType = $command.CommandType
                Source = $command.Source
            }
        }
        catch {
            $results.AllAvailable = $false
            $results.MissingFunctions += $functionName
            $results.TestResults[$functionName] = @{
                Available = $false
                Error = $_.Exception.Message
            }
        }
    }
    
    return $results
}
