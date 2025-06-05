function Get-KeychainDump {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [string]$KeychainPath = "$($env:HOME)/Library/Keychains/login.keychain-db"
    )

    if (-not $script:IsMacOS) {
        Write-Error -Message "This module can only be used on macOS" -ErrorAction Stop
    }

    try {
        $keychainData = & security dump-keychain $KeychainPath 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error -Message "Failed to dump keychain: $keychainData" -ErrorAction Stop
        }
        
        $currentEntry = [System.Collections.Generic.List[string]]::new()
        
        foreach ($line in $keychainData) {
            # Check if this line starts a new keychain entry
            if ($line -match '^keychain:' -and $currentEntry.Count -gt 0) {
                # Output the completed entry
                Write-Output (, $currentEntry.ToArray())
                $currentEntry.Clear()
            }
            
            # Add the line to current entry
            $currentEntry.Add($line)
        }
        
        # Output the final entry if it exists
        if ($currentEntry.Count -gt 0) {
            Write-Output (, $currentEntry.ToArray())
        }
    }
    catch {
        Write-Error -Message "Error retrieving keychain data: $($_.Exception.Message)" -ErrorAction Stop
    }
}

function Get-KeychainEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        
        [Parameter(Mandatory)]
        [string]$Username,
        
        [Parameter()]
        [string]$KeychainPath = "$($env:HOME)/Library/Keychains/login.keychain-db"
    )
    
    if (-not $script:IsMacOS) {
        Write-Error -Message "This module can only be used on macOS" -ErrorAction Stop
    }
    
    $matchingEntries = Get-KeychainDump -KeychainPath $KeychainPath | Where-Object {
        $entry = $_
        $hasMatchingService = $entry | Where-Object { $_ -match '"svce"<blob>="' + [regex]::Escape($Name) + '"' }
        $hasMatchingAccount = $entry | Where-Object { $_ -match '"acct"<blob>="' + [regex]::Escape($Username) + '"' }
        return ($hasMatchingService -and $hasMatchingAccount)
    }
    
    if ($matchingEntries) {
        Write-Output (, $matchingEntries)
    }
}

function Set-KeychainEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Username,
        
        [Parameter(Mandatory)]
        [string]$Name,
        
        [Parameter()]
        [string]$Label,
        
        [Parameter()]
        [string]$Comment = "",
        
        [Parameter()]
        [string]$Description = "PoShCredential",
        
        [Parameter()]
        [string]$KeychainPath,
        
        [Parameter()]
        [securestring]$Password,
        
        [Parameter()]
        [switch]$Update
    )
    
    if (-not $script:IsMacOS) {
        Write-Error -Message "This module can only be used on macOS" -ErrorAction Stop
    }
    
    $plainPassword = $null
    
    try {
        # If updating, check for existing entry and remove it first
        if ($Update) {
            $existingAccount = Get-KeychainEntry -Name $Name -Username $Username
            if ($existingAccount) {
                Remove-KeychainEntry -Name $Name -Username $Username
            }
        }
        
        # Convert SecureString to plain text temporarily if provided
        if ($Password) {
            $plainPassword = $Password | ConvertFrom-SecureString -AsPlainText

        }
        
        # Build the arguments list
        $securityArgs = [System.Collections.ArrayList]@()
        $null = $securityArgs.Add('add-generic-password')
        $null = $securityArgs.Add('-s')
        $null = $securityArgs.Add($Name)
        $null = $securityArgs.Add('-a')
        $null = $securityArgs.Add($Username)
        
        # Add comment only if it's not empty
        if (-not [string]::IsNullOrWhiteSpace($Comment)) {
            $null = $securityArgs.Add('-j')
            $null = $securityArgs.Add($Comment)
        }
        
        # Optional parameters
        if ($Label) {
            $null = $securityArgs.Add('-l')
            $null = $securityArgs.Add($Label)
        }
        
        if ($Description) {
            $null = $securityArgs.Add('-D')
            $null = $securityArgs.Add($Description)
        }
        
        # Password parameter using -w flag
        if ($plainPassword) {
            $null = $securityArgs.Add('-w')
            $null = $securityArgs.Add($plainPassword)
        }
        
        # Update flag if specified
        if ($Update) {
            $null = $securityArgs.Add('-U')
        }
        
        # Keychain path if specified
        if ($KeychainPath) {
            $null = $securityArgs.Add($KeychainPath)
        }
        
        # Execute the security command
        $result = & security @securityArgs 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error -Message "Failed to set keychain entry: $result" -ErrorAction Stop
        }
        
    }
    catch {
        Write-Error -Message "Error setting keychain entry: $($_.Exception.Message)" -ErrorAction Stop
    }
    finally {
        # Secure cleanup of password from memory
        if ($plainPassword) {
            # Overwrite the string with zeros before setting to null
            try {
                $chars = $plainPassword.ToCharArray()
                for ($i = 0; $i -lt $chars.Length; $i++) {
                    $chars[$i] = [char]0
                }
                $plainPassword = $null
                [System.GC]::Collect()
                [System.GC]::WaitForPendingFinalizers()
            }
            catch {
                Write-Host "Set-KeychainEntry password cleanup"
            }
        }
    }
}

function Get-KeychainPassword {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        
        [Parameter()]
        [string]$Username,
        
        [Parameter()]
        [string]$KeychainPath = "$($env:HOME)/Library/Keychains/login.keychain-db"
    )
    
    $passwordPlain = $null
    
    try {
        # Build the security command arguments
        $securityArgs = @('find-generic-password')
        
        # Required service parameter
        $securityArgs += '-s', $Name
        
        # Optional Username parameter for specificity
        if ($Username) {
            $securityArgs += '-a', $Username
        }
        
        # Add password output flag
        $securityArgs += '-w'
        
        # Keychain path if specified
        if ($KeychainPath) {
            $securityArgs += $KeychainPath
        }
        
        # Execute the security command and capture output
        $passwordPlain = & security @securityArgs 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error -Message "Failed to retrieve keychain password: $passwordPlain" -ErrorAction Stop
        }
        
        # Ensure we have a string and trim any whitespace/newlines
        if ($passwordPlain -is [array]) {
            $passwordPlain = $passwordPlain -join ''
        }
        $passwordPlain = $passwordPlain.ToString().Trim()
        
        # Convert plain text password to SecureString
        if ([string]::IsNullOrEmpty($passwordPlain)) {
            Write-Error -Message "Retrieved password is empty or null" -ErrorAction Stop
        }
        
        $securePassword = ConvertTo-SecureString -String $passwordPlain -AsPlainText -Force
        Write-Output $securePassword
        
    }
    catch {
        Write-Error -Message "Error retrieving keychain password: $($_.Exception.Message)" -ErrorAction Stop
    }
    finally {
        # Secure cleanup of password from memory
        if ($passwordPlain -and $passwordPlain -is [string] -and $passwordPlain.Length -gt 0) {
            # Overwrite the string with zeros before setting to null
            $chars = $passwordPlain.ToCharArray()
            for ($i = 0; $i -lt $chars.Length; $i++) {
                $chars[$i] = [char]0
            }
            $passwordPlain = $null
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
        }
    }
}

function ConvertTo-KeychainObject {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]]$Entry
    )
    if (-not $script:IsMacOS) {
        Write-Error -Message "This module can only be used on macOS" -ErrorAction Stop
    }
    $entryObject = [PSCustomObject]@{
        Name             = $null
        Label            = $null
        Username         = $null
        CreationDate     = $null
        Creator          = $null
        CustomItem       = $null
        Kind             = $null
        GenericAttribute = $null
        Comment          = $null
        Invisible        = $null
        ModificationDate = $null
        Negative         = $null
        Protocol         = $null
        ScriptCode       = $null
        ServiceName      = $null
        Type             = $null
    }
    
    foreach ($line in $Entry) {
        # Extract label (0x00000007 attribute)
        if ($line -match '0x00000007 <blob>="([^"]*)"') {
            $entryObject.Label = $matches[1]
        }
        elseif ($line -match '0x00000007 <blob>=<NULL>') {
            $entryObject.Label = $null
        }
        # Extract Username name
        elseif ($line -match '"acct"<blob>="([^"]*)"') {
            $entryObject.Username = $matches[1]
        }
        # Extract creation date
        elseif ($line -match '"cdat"<timedate>=0x[0-9A-F]+\s+"([^"\\]+)') {
            $dateString = $matches[1] -replace '\\000$'
            try {
                $entryObject.CreationDate = [DateTime]::ParseExact($dateString, 'yyyyMMddHHmmssZ', $null)
            }
            catch {
                $entryObject.CreationDate = $dateString
            }
        }
        # Extract creator
        elseif ($line -match '"crtr"<uint32>="([^"]*)"') {
            $entryObject.Creator = $matches[1]
        }
        elseif ($line -match '"crtr"<uint32>=<NULL>') {
            $entryObject.Creator = $null
        }
        # Extract custom item
        elseif ($line -match '"cusi"<sint32>=<NULL>') {
            $entryObject.CustomItem = $null
        }
        elseif ($line -match '"cusi"<sint32>=([^<]+)') {
            $entryObject.CustomItem = $matches[1]
        }
        # Extract description
        elseif ($line -match '"desc"<blob>="([^"]*)"') {
            $entryObject.Kind = $matches[1]
        }
        elseif ($line -match '"desc"<blob>=<NULL>') {
            $entryObject.Kind = $null
        }
        # Extract generic attribute
        elseif ($line -match '"gena"<blob>="([^"]*)"') {
            $entryObject.GenericAttribute = $matches[1]
        }
        elseif ($line -match '"gena"<blob>=<NULL>') {
            $entryObject.GenericAttribute = $null
        }
        # Extract item comment
        elseif ($line -match '"icmt"<blob>="([^"]*)"') {
            $entryObject.Comment = $matches[1]
        }
        elseif ($line -match '"icmt"<blob>=<NULL>') {
            $entryObject.Comment = $null
        }
        # Extract invisible flag
        elseif ($line -match '"invi"<sint32>=<NULL>') {
            $entryObject.Invisible = $null
        }
        elseif ($line -match '"invi"<sint32>=0x([0-9A-F]+)') {
            $entryObject.Invisible = [Convert]::ToInt32($matches[1], 16)
        }
        # Extract modification date
        elseif ($line -match '"mdat"<timedate>=0x[0-9A-F]+\s+"([^"\\]+)') {
            $dateString = $matches[1] -replace '\\000$'
            try {
                $entryObject.ModificationDate = [DateTime]::ParseExact($dateString, 'yyyyMMddHHmmssZ', $null)
            }
            catch {
                $entryObject.ModificationDate = $dateString
            }
        }
        # Extract negative flag
        elseif ($line -match '"nega"<sint32>=<NULL>') {
            $entryObject.Negative = $null
        }
        elseif ($line -match '"nega"<sint32>=([^<]+)') {
            $entryObject.Negative = $matches[1]
        }
        # Extract protocol
        elseif ($line -match '"prot"<blob>="([^"]*)"') {
            $entryObject.Protocol = $matches[1]
        }
        elseif ($line -match '"prot"<blob>=<NULL>') {
            $entryObject.Protocol = $null
        }
        # Extract script code
        elseif ($line -match '"scrp"<sint32>=<NULL>') {
            $entryObject.ScriptCode = $null
        }
        elseif ($line -match '"scrp"<sint32>=0x([0-9A-F]+)') {
            $entryObject.ScriptCode = [Convert]::ToInt32($matches[1], 16)
        }
        elseif ($line -match '"scrp"<sint32>=([^<]+)') {
            $entryObject.ScriptCode = $matches[1]
        }
        # Extract service name
        elseif ($line -match '"svce"<blob>="([^"]*)"') {
            $entryObject.ServiceName = $matches[1]
            $entryObject.Name = $matches[1]  # Set Name to same value as ServiceName
        }
        elseif ($line -match '"svce"<blob>=<NULL>') {
            $entryObject.ServiceName = $null
            $entryObject.Name = $null
        }
        # Extract type
        elseif ($line -match '"type"<uint32>="([^"]*)"') {
            $entryObject.Type = $matches[1]
        }
        elseif ($line -match '"type"<uint32>=<NULL>') {
            $entryObject.Type = $null
        }
    }
    
    Write-Output $entryObject
}

function Get-KeychainObject {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        
        [Parameter(Mandatory)]
        [string]$Username,
        
        [Parameter()]
        [string]$KeychainPath = "$($env:HOME)/Library/Keychains/login.keychain-db"
    )
    
    if (-not $script:IsMacOS) {
        Write-Error -Message "This module can only be used on macOS" -ErrorAction Stop
    }
    
    try {
        # Get the raw keychain entry data
        $entryData = Get-KeychainEntry -Name $Name -Username $Username -KeychainPath $KeychainPath
        
        # Handle case where no entries are found
        if (-not $entryData) {
            Write-Verbose "No keychain entry found for Name: '$Name', Username: '$Username'"
            return
        }
        
        # Handle multiple entries - convert each one
        if ($entryData -is [System.Array] -and $entryData[0] -is [System.Array]) {
            # Multiple entries found - each is an array of strings
            Write-Verbose "Multiple keychain entries found for Name: '$Name', Username: '$Username'"
            foreach ($entry in $entryData) {
                $keychainObject = ConvertTo-KeychainObject -Entry $entry
                Write-Output $keychainObject
            }
        } else {
            # Single entry found - convert it to a PowerShell object
            $keychainObject = ConvertTo-KeychainObject -Entry $entryData
            Write-Output $keychainObject
        }
        
    }
    catch {
        Write-Error -Message "Error retrieving keychain object: $($_.Exception.Message)" -ErrorAction Stop
    }
}

function Get-AllKeychainObjects {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$KeychainPath = "$($env:HOME)/Library/Keychains/login.keychain-db"
    )
    
    try {
        # Get raw keychain data and convert each entry to PowerShell objects
        Get-KeychainDump -KeychainPath $KeychainPath | ForEach-Object {
            ConvertTo-KeychainObject -Entry $_
        }
    }
    catch {
        Write-Error -Message "Error retrieving all keychain entries: $($_.Exception.Message)" -ErrorAction Stop
    }
}

function Remove-KeychainEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        
        [Parameter(Mandatory)]
        [string]$Username,
        
        [Parameter()]
        [string]$KeychainPath = "$($env:HOME)/Library/Keychains/login.keychain-db"
    )
    
    if (-not $script:IsMacOS) {
        Write-Error -Message "This module can only be used on macOS" -ErrorAction Stop
    }
    
    try {
        # Build the security command arguments
        $securityArgs = @('delete-generic-password')
        
        # Required service parameter
        $securityArgs += '-s', $Name
        
        # Optional Username parameter for specificity
        if ($Username) {
            $securityArgs += '-a', $Username
        }
        
        # Keychain path if specified
        if ($KeychainPath) {
            $securityArgs += $KeychainPath
        }
        
        # Execute the security command
        $null = & security @securityArgs 2>&1
        
        if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 44) {
            # Exit code 44 means "item not found" which is acceptable for deletion
            $errorResult = & security @securityArgs 2>&1  
            Write-Error -Message "Failed to remove keychain entry: $errorResult" -ErrorAction Stop
        }
        
    }
    catch {
        Write-Error -Message "Error removing keychain entry: $($_.Exception.Message)" -ErrorAction Stop
    }
}


