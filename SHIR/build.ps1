Import-Module $PSScriptRoot\library.ps1

$DmgcmdPath = "C:\Program Files\Microsoft Integration Runtime\5.0\Shared\dmgcmd.exe"
$MsiFileName = 'IntegrationRuntime.latest.msi'

function Get-Remote-SHIR() {
    Write-Log "Downloading latest version of SHIR MSI file"
  
    $MinimumVersion = [Version]'5.48.9106.2'
    if ($env:SHIR_FIX_VERSION -and $env:SHIR_FIX_VERSION.Trim() -ne '') { 
        $FixedVersion = $env:SHIR_FIX_VERSION.Trim()
        Write-Log "SHIR FIX VERSION set to: $FixedVersion"
        $DownloadURL = "https://download.microsoft.com/download/E/4/7/E4771905-1079-445B-8BF9-8A1A075D8A10/IntegrationRuntime_$FixedVersion.msi"
    } else { 
        $FixedVersionURL = "https://download.microsoft.com/download/E/4/7/E4771905-1079-445B-8BF9-8A1A075D8A10/IntegrationRuntime_$MinimumVersion.msi"
        $DownloadURL = 'https://go.microsoft.com/fwlink/?linkid=839822&clcid=0x409'
        try{
          $Response = Invoke-WebRequest -Uri $DownloadURL -Method Get -UseBasicParsing -MaximumRedirection 2
        } catch {
          Write-Log $_
        }
      
        $RedirectURL = [string]$Response.Headers['Location']
        Write-Log "Redirect URL: $RedirectURL"
        if ($RedirectURL -match 'IntegrationRuntime_(\d+\.\d+\.\d+\.\d+)') {
          if ($matches.Count -gt 1) {
            $ExtractedVersion = [Version]$matches[1]
            Write-Log "Dynamic download Version: $ExtractedVersion"
          }
        } else {
          Write-Log "Version number not found in the URL"
        }
        
        # Compare the versions
        if ($null -eq $ExtractedVersion -or $ExtractedVersion -lt $MinimumVersion) {
            Write-Log "The extracted version ($ExtractedVersion) is lower than $MinimumVersion. Using minimum version URL."
            $DownloadURL = $FixedVersionURL
        }
    }
    
    # Temporarily disable progress updates to speed up the download process. (See https://stackoverflow.com/questions/69942663/invoke-webrequest-progress-becomes-irresponsive-paused-while-downloading-the-fil)
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $DownloadURL -OutFile "C:\SHIR\$MsiFileName"
    $ProgressPreference = 'Continue'
}

function Install-SHIR() {
    Write-Log "Install the Self-hosted Integration Runtime in the Windows container"

    $MsiFiles = (Get-ChildItem -Path C:\SHIR | Where-Object { $_.Name -match [regex] "IntegrationRuntime.*.msi" })
    if ($MsiFiles) {
        $MsiFileName = $MsiFiles[0].Name
        Write-Log "Using SHIR MSI file: $MsiFileName"
    }
    else {
        Get-Remote-SHIR
    }

    Write-Log "Installing SHIR $MsiFileName"
    Start-Process msiexec.exe -Wait -ArgumentList "/i C:\SHIR\$MsiFileName  /L*V C:\SHIR\LogFile.log"
    
    if (!$?) {
        Write-Log "SHIR MSI Install Failed"
    }

    dir "C:\Program Files\Microsoft Integration Runtime"
    Write-Log "SHIR MSI Install Successfully"
}

# From https://github.com/Azure/Azure-Data-Factory-Integration-Runtime-in-Windows-Container/blob/main/SHIR/build.ps1
function Install-MSFT-JDK() {
    Write-Log "Install the Microsoft OpenJDK in the Windows container"
    Write-Log "Downloading Microsoft OpenJDK 21 LTS msi"
    $JDKMsiFileName = 'microsoft-jdk-21-windows-x64.msi'

    # Temporarily disable progress updates to speed up the download process. (See https://stackoverflow.com/questions/69942663/invoke-webrequest-progress-becomes-irresponsive-paused-while-downloading-the-fil)
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri "https://aka.ms/download-jdk/$JDKMsiFileName" -OutFile "C:\SHIR\$JDKMsiFileName"
    $ProgressPreference = 'Continue'

    Write-Log "Installing Microsoft OpenJDK"
    # Arguments pulled from https://learn.microsoft.com/en-us/java/openjdk/install#install-via-msi
    Start-Process msiexec.exe -Wait -ArgumentList "/i C:\SHIR\$JDKMsiFileName ADDLOCAL=FeatureMain,FeatureEnvironment,FeatureJarFileRunWith,FeatureJavaHome INSTALLDIR=`"c:\Program Files\Microsoft\`" /quiet"
    if (!$?) {
        Write-Log "Microsoft OpenJDK MSI Install Failed. Trying legacy Java installation."
        Install-Jre
    }
    Write-Log "Microsoft OpenJDK MSI Install Successfully"
    Write-Log "Will remove C:\SHIR\$JDKMsiFileName"
    Remove-Item "C:\SHIR\$JDKMsiFileName"
    Write-Log "Removed C:\SHIR\$JDKMsiFileName"
}

function SetupEnv() {
    Write-Log "Begin to Setup the SHIR Environment"
    Start-Process $DmgcmdPath -Wait -ArgumentList "-Stop -StopUpgradeService -TurnOffAutoUpdate"
    Write-Log "SHIR Environment Setup Successfully"
}

function Add-Monitor-User($theUser) {
    try {
        Add-LocalGroupMember -Group "Performance Monitor Users" -Member $theUser
    } catch {
        Write-Log "The user $theUser was already in the Performance Monitor Users group"
    }
    try {
        Add-LocalGroupMember -Group "Performance Log Users" -Member $theUser
    } catch {
        Write-Log "The user $theUser was already in the Performance Log Users group"
    }
    Write-Log "The user $theUser is now in groups Performance Monitor Users and Performance Log Users"
}

function Install-Certificate {
    $rootcert = (Get-ChildItem -Path C:\SHIR | Where-Object { $_.Name -match [regex] "root.*.cer" })
    $intermittent = (Get-ChildItem -Path C:\SHIR | Where-Object { $_.Name -match [regex] "intermittent.*.cer" })
    if($rootcert) {
        Write-Log "Installing Root Certificate"
        Import-Certificate -FilePath "C:\SHIR\$rootcert" -CertStoreLocation Cert:\LocalMachine\Root
        Write-Log "Will remove C:\SHIR\$rootcert"
        Remove-Item "C:\SHIR\$rootcert"

    }
    if($intermittent) {
        Write-Log "Installing Intermittent Certificate"
        Import-Certificate -FilePath "C:\SHIR\$intermittent" -CertStoreLocation Cert:\LocalMachine\CA
        Write-Log "Will remove C:\SHIR\$intermittent"
        Remove-Item "C:\SHIR\$intermittent"
    }
}

# Use Install-MSFT-JDK, try to fallback to this if failed to install.
function Install-Jre() {
    Write-Log "Begin to install the OpenJDK 17 runtime"
    Invoke-WebRequest "https://api.adoptium.net/v3/installer/latest/17/ga/windows/x64/jdk/hotspot/normal/eclipse?project=jdk" -OutFile "C:\SHIR\OpenJdk17.msi"
    Start-Process -Wait -FilePath msiexec -ArgumentList /i, "C:\SHIR\OpenJdk17.msi", "ADDLOCAL=FeatureMain,FeatureEnvironment,FeatureJarFileRunWith,FeatureJavaHome", 'INSTALLDIR="C:\Program Files\Java"', /quiet -Verb RunAs
    Write-Log "OpenJDK 17 installed successfully"
    [Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\Program Files\Java;C:\Program Files\Java\bin", "Machine")
    [Environment]::SetEnvironmentVariable("JAVA_TOOL_OPTIONS", "-Xms2024m -Xmx4048m", "Machine")
}

function Install-NetFramework() {
    Write-Log "Begin to install the NET Framework Visual C++ 2010 Redistributable"
    Invoke-WebRequest "https://download.microsoft.com/download/3/2/2/3224B87F-CFA0-4E70-BDA3-3DE650EFEBA5/vcredist_x64.exe" -OutFile "C:\SHIR\vcredist_x64.exe"
    Start-Process -Wait -FilePath "C:\SHIR\vcredist_x64.exe" -ArgumentList /install, /quiet, /norestart
    Write-Log "Vcc Redistributable installed successfully"
}

function Add-ToSystemPath([string]$Dir) {
    $current = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    if ($current -notlike "*$Dir*") {
        [System.Environment]::SetEnvironmentVariable(
            "Path", "$current;$Dir", "Machine"
        )
        Write-Log "Added to system PATH: $Dir"
    } else {
        Write-Log "Already in system PATH: $Dir"
    }
}

function Install-OracleInstantClient() {
    $ErrorActionPreference = "Stop"
    
    $Version     = "23.26.1.0.0"
    $InstallRoot = "C:\oracle"
    $VerParts    = $Version -split "\."
    $DirName     = "instantclient_$($VerParts[0])_$($VerParts[1])"
    $InstallDir  = Join-Path $InstallRoot $DirName
    $TempDir     = Join-Path $env:TEMP "oracle_ic_install"
    
    # Oracle CDN base URL uses ShortVer (major.minor.patch), dots removed for path segment
    $BaseUrl     = "https://download.oracle.com/otn_software/nt/instantclient/$($Version -replace '\.','')/"

    $Packages = @(
        "instantclient-basic-windows.x64-${Version}.zip",
        "instantclient-sqlplus-windows.x64-${Version}.zip",
        "instantclient-tools-windows.x64-${Version}.zip",
        "instantclient-odbc-windows.x64-${Version}.zip"
    )

    Write-Log "Preparing directories"
    foreach ($d in @($TempDir, $InstallRoot)) {
        if (-not (Test-Path $d)) {
            New-Item -ItemType Directory -Path $d -Force | Out-Null
            Write-Log "Created: $d"
        }
    }

    Write-Log "Downloading packages from Oracle CDN"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    
    $downloaded = @()
    foreach ($pkg in $Packages) {
        $url      = "$BaseUrl$pkg"
        $destFile = Join-Path $TempDir $pkg
    
        if (Test-Path $destFile) {
            Write-Log "Already cached: $pkg"
        } else {
            Write-Log "Downloading: $pkg"
            try {
                Invoke-WebRequest -Uri $url -OutFile $destFile -UseBasicParsing
            } catch {
                Write-Log "Failed to download $pkg from $url"
                throw
            }
        }
        $downloaded += $destFile
    }

    Write-Log "Extracting packages to $InstallRoot"
    foreach ($zip in $downloaded) {
        Write-Log "Extracting: $(Split-Path $zip -Leaf)"
        Expand-Archive -Path $zip -DestinationPath $InstallRoot -Force
    }

    if (-not (Test-Path $InstallDir)) {
        $found = Get-ChildItem $InstallRoot -Directory | Where-Object { $_.Name -like "instantclient_*" } | Select-Object -First 1
        if ($found) {
            $InstallDir = $found.FullName
            Write-Log "Detected install dir: $InstallDir"
        } else {
            throw "Could not find extracted Instant Client directory under $InstallRoot"
        }
    }
    
    Write-Log "Install directory: $InstallDir"
    Write-Log "Updating system PATH"
    Add-ToSystemPath $InstallDir

    Write-Log "Verifying installation"
    $sqlplusPath = Join-Path $InstallDir "sqlplus.exe"
    if (Test-Path $sqlplusPath) {
        $verOutput = & $sqlplusPath -V 2>&1 | Select-Object -First 2
        Write-Log ($verOutput -join "`n")
    } else {
        Write-Log "sqlplus.exe not found. SQL*Plus package may not have been included."
    }
}

try {
    if ([bool]::Parse($env:INSTALL_JDK)) {
        Install-MSFT-JDK
    }
    if ([bool]::Parse($env:INSTALL_LEGACY_JDK)) {
        Install-Jre
    }
    if ([bool]::Parse($env:INSTALL_NET_FRAMEWORK)) {
        Install-NetFramework
    }
    if ([bool]::Parse($env:INSTALL_CERT)) {
        Install-Certificate
    }
    if ([bool]::Parse($env:INSTALL_ORACLE)) {
        Install-OracleInstantClient
    }
    
    Install-SHIR
    
    if ([bool]::Parse($env:SETUP_ENV)) {
        SetupEnv
    }
    if ([bool]::Parse($env:ADD_MONITOR_USERS)) {
        Add-Monitor-User "User Manager\ContainerAdministrator"  # This is the user that a user will enter as when logging into the container
        Add-Monitor-User "NT SERVICE\DIAHostService"            # This is the user that runs the SHIR backend
    }

} catch {
    exit 1
}

exit 0
