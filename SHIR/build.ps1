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
        Write-Log "SHIR MSI Install Failed"
    }

    Write-Log "SHIR MSI Install Successfully"
}

function SetupEnv() {
    Write-Log "Begin to Setup the SHIR Environment"
    $DmgcmdPath = Get-CmdFilePath
    Start-Process $DmgcmdPath -Wait -ArgumentList "-Stop -StopUpgradeService -TurnOffAutoUpdate"
    Write-Log "SHIR Environment Setup Successfully"
}

function InstallJre() {
    Invoke-WebRequest "https://api.adoptopenjdk.net/v3/installer/latest/11/ga/windows/x64/jdk/hotspot/normal/adoptopenjdk?project=jdk" -OutFile "C:\SHIR\OpenJdk11.msi"
    Start-Process -Wait -FilePath msiexec -ArgumentList /i, "C:\SHIR\OpenJdk11.msi", "ADDLOCAL=FeatureMain,FeatureEnvironment,FeatureJarFileRunWith,FeatureJavaHome", 'INSTALLDIR="C:\Program Files\Java"', /quiet -Verb RunAs
}

function InstallNetFramework() {
    Invoke-WebRequest "https://download.microsoft.com/download/3/2/2/3224B87F-CFA0-4E70-BDA3-3DE650EFEBA5/vcredist_x64.exe" -OutFile "C:\SHIR\vcredist_x64.exe"
    Start-Process -Wait FilePath "C:\SHIR\vcredist_x64.exe" -ArgumentList /install, /quiet, /norestart
}

InstallJre
InstallNetFramework
Install-SHIR

exit 0