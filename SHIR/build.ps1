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

Install-SHIR

exit 0
