<# ULTIMATE ORACLE CLIENT DEINSTALLER ==================================================================================
Script written by Payton Flint
See https://paytonflint.com/powershell-ultimate-oracle-client-deinstaller/
Deinstalls 11g, 12c, 19c Oracle clients
#>

# Clear variables for repeatability
Get-Variable -Exclude PWD,*Preference | Remove-Variable -EA 0

# Specify target directory
$TargetDrive = 'C:\'

# Directories to exclude
$ExcludeDirs = @("")

# Temporary Directory Path
$TempDir = "C:\Ultimate_OCD"

#=======================================================================================================================
  
# Uninstall-Oracle Function
Function Uninstall-Oracle {
    param (
        $TargetDrive,
        $ExcludeDirs,
        $TempDir
    )
    # Exclude system directories
    $ExcludeDirs += @("PerfLogs", "Program Files", "Program Files (x86)", "Users", "Windows")
    # Create IncludeDirs array
    $IncludeDirs = @()
    # Get directories w/o exclusions
    $IncludeDirs += Get-ChildItem -Path $TargetDrive -Directory | Where-Object { $_.Name -notin $ExcludeDirs}
    # Append TargetDrive
    For ($i = 0; $i -lt $IncludeDirs.Count; $i++) {
        $IncludeDirs[$i] = Join-Path $TargetDrive $IncludeDirs[$i]
    }
    If ($IncludeDirs -ne $null) {
        # Get each instance of "product" directory from included directories
        $ProductPath = Get-ChildItem -Path $IncludeDirs -Recurse -Directory `
        | Where-Object { $_.Name -eq 'product' } `
        | Select -ExpandProperty "FullName"
        If ($ProductPath -ne $null) {
            # Create VersionPath array
            $VersionPath = @()
            # Get each instance of "x.x.x" version subdirectory from each ProductPath
            $ProductPath | ForEach-Object {
                $VersionPath += Get-ChildItem -Path $_ -Recurse -Directory `
                | Where-Object { $_.Name -match '\d+(\.\d+)*' } `
                | Select -ExpandProperty "FullName" -First 1
            }
            If ($VersionPath -ne $null) {
                # Create DeinstallPath array
                $DeinstallPath = @()
                # Get each instance of "deinstall" subdirectory from each VersionPath
                $VersionPath | ForEach-Object {
                    $DeinstallPath += Get-ChildItem -Path $_ -Recurse -Directory `
                    | Where-Object { $_.Name -eq 'deinstall' -and $_.FullName -notlike "*\inventory\*"} `
                    | Select -ExpandProperty "FullName" -First 1
                }
                If ($DeinstallPath -ne $null) {
                    # Create DeinstallBatch array
                    $DeinstallBatch = @()
                    # Get each instance of "deinstall.bat" file from each DeinstallPath
                    $DeinstallPath | ForEach-Object {
                        $DeinstallBatch += Get-ChildItem -Path $_ -File `
                        | Where-Object { $_.Name -eq 'deinstall.bat'} `
                        | Select -ExpandProperty "FullName" -First 1
                     }
                     If ($DeinstallBatch -ne $null) {
                         # Create temporary directory
                         If (!(Test-Path $TempDir)) {
                             New-Item -Path "$TempDir" -ItemType Directory -Force
                         }
                         $DeinstallBatch | ForEach-Object {
                             # Create array for parent-most directories (for later removal)
                             $DriveLetter = Split-Path -Path $_ -Qualifier
                             $ParentDir = (Split-Path -Path $_ -Parent).Split('\', [System.StringSplitOptions]::RemoveEmptyEntries)[1]
                             $ParentDirs = @()
                             $ParentDirs += Join-Path $DriveLetter $ParentDir
                             # Get version number from file path
                             $VersionNumber = [regex]::Match($_, "\\(\d+(\.\d+)+)\\").Groups[1].Value
                             # Append version number to TempDir for appropriate naming of subdirectory
                             $TempSubDir = Join-Path $TempDir $VersionNumber
                             # Create temporary subdirectory
                             If (!(Test-Path $TempSubDir)) {
                                 New-Item -Path "$TempSubDir" -ItemType Directory -Force
                             }
                             # Create .RSP file in subdirectory using deinstall.bat
                             Start-Process -FilePath "$_" -Wait -NoNewWindow -ArgumentList "-silent -checkonly -o $TempSubDir"
                             # Execute deinstall.bat using .RSP file
                             $RSP = Join-Path $TempSubDir '\deinstall*.rsp'
                             Start-Process -FilePath "$_" -Wait -NoNewWindow -ArgumentList "-silent -paramfile $RSP"
                        }
                    }
                }
            }
        }
        # Remove parent-most directories for all Oracle instances
        If ($ParentDirs -ne $null) {
            Remove-Item -Path $ParentDirs -Force -Recurse -ErrorAction SilentlyContinue
        }
        # Remove temporary directory
        If (Test-Path $TempDir) {
            Remove-Item -Path $TempDir -Force -Recurse -ErrorAction SilentlyContinue
        }
        # Remove Program Files
        $ProgFiles    = "$env:SystemDrive\Program Files\Oracle"
        $ProgFilesx86 = "$env:SystemDrive\Program Files (x86)\Oracle"
        If (Test-Path $ProgFiles) {
            Remove-Item -Path $ProgFiles -Force -Recurse -ErrorAction SilentlyContinue
        } Elseif (Test-Path $ProgFilesx86) {
            Remove-Item -Path $ProgFilesx86 -Force -Recurse -ErrorAction SilentlyContinue
        }
    }
} # End of Uninstall-Oracle Function

# Set-EnvironmentVariable Function
Function Set-EnvironmentVariable {
    param (
        $Name,
        $Value
    )
    [System.Environment]::SetEnvironmentVariable($Name,$Value,[System.EnvironmentVariableTarget]::Machine)
    [System.Environment]::SetEnvironmentVariable($Name,$Value,[System.EnvironmentVariableTarget]::User)
    [System.Environment]::SetEnvironmentVariable($Name,$Value,[System.EnvironmentVariableTarget]::Process)
} # End of Set-EnvironmentVariable Function

# Update-EnvironmentVariables Function
Function Update-EnvironmentVariables {
    # Clear nullified environment variables
    $machineValues = [Environment]::GetEnvironmentVariables('Machine')
    $userValues    = [Environment]::GetEnvironmentVariables('User')
    $processValues = [Environment]::GetEnvironmentVariables('Process')
    # Identify the entire list of environment variable names first
    $envVarNames = ($machineValues.Keys + $userValues.Keys + 'PSModulePath') | Sort-Object | Select-Object -Unique
    # Lastly remove the environment variables that no longer exist
    ForEach ($envVarName in $processValues.Keys | Where-Object {$envVarNames -like $null}) {
    Remove-Item -LiteralPath "env:${envVarName}" -Force
    }
    # Update variables
    foreach($level in "Machine","User","Process") {
    [Environment]::GetEnvironmentVariables($level)
    }
} # End of Update-EnvironmentVariables Function
 
# Remove-RegistryKey Function
Function Remove-RegistryKey {
    param (
        $Key
    )
    Remove-Item -Path "Registry::$Key" -Force -Recurse
} # End of Remove-RegistryKey Function
 
# Call Uninstall-Oracle function
Uninstall-Oracle -TargetDrive $TargetDrive -ExcludeDirs $ExcludeDirs -TempDir $TempDir
 
# Nullify environment variables
Set-EnvironmentVariable -Name "TNS_Admin"     -Value "$null"
Set-EnvironmentVariable -Name "_JAVA_OPTIONS" -Value "$null"
Set-EnvironmentVariable -Name "ORACLE_HOME"   -Value "$null"
 
# Refresh environment variables
Update-EnvironmentVariables
 
# Remove Registry Keys
Remove-RegistryKey -Key "HKEY_LOCAL_MACHINE\SOFTWARE\Oracle*"
Remove-RegistryKey -Key "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Oracle*"
Remove-RegistryKey -Key "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Oracle*"
