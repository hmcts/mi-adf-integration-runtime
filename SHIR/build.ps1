Import-Module $PSScriptRoot\library.ps1

function Install-SHIR() {
    Write-Log "Install the Self-hosted Integration Runtime in the Windows container"

    $VersionToInstall = Get-LatestGatewayVersion
    $IntegrationRuntimeFiles = (Get-ChildItem -Path "$PSScriptRoot" | Sort-Object LastWriteTime -Descending | Where-Object { $_.Name -match [regex] "IntegrationRuntime_$VersionToInstall.*.msi" })

    if (-Not $IntegrationRuntimeFiles)
    {
        Download-GatewayInstaller $VersionToInstall
    }
    
    $MsiFileName = (Get-ChildItem -Path "$PSScriptRoot" | Sort-Object LastWriteTime -Descending | Where-Object { $_.Name -match [regex] "IntegrationRuntime_$VersionToInstall.*.msi" })[0].Name
    Start-Process msiexec.exe -Wait -ArgumentList "/i $PSScriptRoot\$MsiFileName /qn"
    if (!$?) {
        Write-Log "SHIR MSI install failed"
    }

    Write-Log "SHIR MSI installed successfully"
}

function SetupEnv() {
    Write-Log "Begin to setup the SHIR environment"
    $DmgcmdPath = Get-CmdFilePath
    Start-Process $DmgcmdPath -Wait -ArgumentList "-Stop -StopUpgradeService -TurnOffAutoUpdate"
    Write-Log "SHIR environment setup successfully"
}

function InstallJre() {
    Write-Log "Begin to install the OpenJDK 11 runtime"
    Invoke-WebRequest "https://api.adoptopenjdk.net/v3/installer/latest/11/ga/windows/x64/jdk/hotspot/normal/adoptopenjdk?project=jdk" -OutFile "C:\SHIR\OpenJdk11.msi"
    Start-Process -Wait -FilePath msiexec -ArgumentList /i, "C:\SHIR\OpenJdk11.msi", "ADDLOCAL=FeatureMain,FeatureEnvironment,FeatureJarFileRunWith,FeatureJavaHome", 'INSTALLDIR="C:\Program Files\Java"', /quiet -Verb RunAs
    Write-Log "OpenJDK 11 installed successfully"
    [Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\Program Files\Java", "Machine")
}

function InstallNetFramework() {
    Write-Log "Begin to install the NET Framework Visual C++ 2010 Redistributable"
    Invoke-WebRequest "https://download.microsoft.com/download/3/2/2/3224B87F-CFA0-4E70-BDA3-3DE650EFEBA5/vcredist_x64.exe" -OutFile "C:\SHIR\vcredist_x64.exe"
    Start-Process -Wait -FilePath "C:\SHIR\vcredist_x64.exe" -ArgumentList /install, /quiet, /norestart
    Write-Log "Vcc Redistributable installed successfully"
}

try {
    InstallJre
    InstallNetFramework
    Install-SHIR
} catch {
    exit 1
}

exit 0