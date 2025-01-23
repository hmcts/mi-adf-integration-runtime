Import-Module $PSScriptRoot\library.ps1

$DmgcmdPath = "C:\Program Files\Microsoft Integration Runtime\5.0\Shared\dmgcmd.exe"
$MsiFileName = 'IntegrationRuntime.latest.msi'

function Get-Remote-SHIR() {
  Write-Log "Downloading latest version of SHIR MSI file"

  $MinimunVersion = [Version]'5.48.9106.2'
  $FixedVersionURL = 'https://download.microsoft.com/download/E/4/7/E4771905-1079-445B-8BF9-8A1A075D8A10/IntegrationRuntime_5.48.9106.2.msi'
  $DownloadURL = 'https://go.microsoft.com/fwlink/?linkid=839822&clcid=0x409'
  try{
    $Response = Invoke-WebRequest -Uri $DownloadURL -Method Get -UseBasicParsing -MaximumRedirection 0
  } catch {
    #  ignore the error
  }

  $RedirectURL = [string]$Response.Headers['Location']
  Write-Output "Redirect URL: $RedirectURL"
  if ($RedirectURL -match 'IntegrationRuntime_(\d+\.\d+\.\d+\.\d+)') {
    if ($matches.Count -gt 1) {
      $ExtractedVersion = [Version]$matches[1]
      Write-Output "Dynamic download Version: $ExtractedVersion"
    }
  } else {
    Write-Output "Version number not found in the URL"
  }
  

  # Compare the versions
  if ($null -eq $ExtractedVersion -or $ExtractedVersion -lt $MinimunVersion) {
      Write-Output "The extracted version ($ExtractedVersion) is lower than $MinimunVersion. Using minimum version URL."
      $DownloadURL = $FixedVersionURL
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

function SetupEnv() {
    Write-Log "Begin to Setup the SHIR Environment"
    Start-Process $DmgcmdPath -Wait -ArgumentList "-Stop -StopUpgradeService -TurnOffAutoUpdate"
    Write-Log "SHIR Environment Setup Successfully"
}

function Install-Jre() {
    Write-Log "Begin to install the OpenJDK 17 runtime"
    Invoke-WebRequest "https://api.adoptium.net/v3/installer/latest/17/ga/windows/x64/jdk/hotspot/normal/eclipse?project=jdk" -OutFile "C:\SHIR\OpenJdk17.msi"
    Start-Process -Wait -FilePath msiexec -ArgumentList /i, "C:\SHIR\OpenJdk17.msi", "ADDLOCAL=FeatureMain,FeatureEnvironment,FeatureJarFileRunWith,FeatureJavaHome", 'INSTALLDIR="C:\Program Files\Java"', /quiet -Verb RunAs
    Write-Log "OpenJDK 17 installed successfully"
    [Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\Program Files\Java;C:\Program Files\Java\bin", "Machine")
    [Environment]::SetEnvironmentVariable("JAVA_TOOL_OPTIONS", "-Xms1024m -Xmx2048m", "Machine")
}

function Install-NetFramework() {
    Write-Log "Begin to install the NET Framework Visual C++ 2010 Redistributable"
    Invoke-WebRequest "https://download.microsoft.com/download/3/2/2/3224B87F-CFA0-4E70-BDA3-3DE650EFEBA5/vcredist_x64.exe" -OutFile "C:\SHIR\vcredist_x64.exe"
    Start-Process -Wait -FilePath "C:\SHIR\vcredist_x64.exe" -ArgumentList /install, /quiet, /norestart
    Write-Log "Vcc Redistributable installed successfully"
}

try {
    # Install-Jre
    # Install-NetFramework
    Install-SHIR

} catch {
    exit 1
}

exit 0
