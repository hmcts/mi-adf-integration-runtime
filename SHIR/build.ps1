Import-Module $PSScriptRoot\library.ps1

$DmgcmdPath = "C:\Program Files\Microsoft Integration Runtime\5.0\Shared\dmgcmd.exe"

function Install-SHIR() {
    Write-Log "Install the Self-hosted Integration Runtime in the Windows container"

    $MsiFiles = (Get-ChildItem -Path C:\SHIR | Where-Object { $_.Name -match [regex] "IntegrationRuntime.*.msi" })
    if ($MsiFiles) {
        $MsiFileName = $MsiFiles[0].Name
        Write-Log "Using SHIR MSI file: $MsiFileName"
    }
    else {
        Write-Log "Downloading latest version of SHIR MSI file"
        $MsiFileName = 'IntegrationRuntime.latest.msi'

        # Temporarily disable progress updates to speed up the download process. (See https://stackoverflow.com/questions/69942663/invoke-webrequest-progress-becomes-irresponsive-paused-while-downloading-the-fil)
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri 'https://go.microsoft.com/fwlink/?linkid=839822&clcid=0x409' -OutFile "C:\SHIR\$MsiFileName"
        $ProgressPreference = 'Continue'
    }

    Write-Log "Installing SHIR"
    Start-Process msiexec.exe -Wait -ArgumentList "/i C:\SHIR\$MsiFileName /qn"
    if (!$?) {
        Write-Log "SHIR MSI Install Failed"
    }

    Write-Log "SHIR MSI Install Successfully"

    Write-Log "Setting up SHIR configuration"

    $DiaWpConfigPath = Get-DiaWpConfigFilePath
    $diaWpConfig = [System.Xml.XmlDocument](Get-Content $DiaWpConfigPath);
    $runtimeNode = $diawpConfig.selectSingleNode("configuration/runtime")
    $allowLargeObjectsNode = $runtimeNode.AppendChild($diaWpConfig.createElement("gcAllowVeryLargeObjects"))
    $allowLargeObjectsNode.SetAttribute("enabled", "true")
    $diaWpConfig.save($DiaWpConfigPath)

    Write-Log "Finished setup of SHIR configuration"
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
    Install-Jre
    Install-NetFramework
    Install-SHIR
} catch {
    exit 1
}

exit 0
