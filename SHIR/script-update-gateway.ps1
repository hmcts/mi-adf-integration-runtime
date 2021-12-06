Import-Module $PSScriptRoot\library.ps1

# Copy of https://raw.githubusercontent.com/Azure/Azure-DataFactory/main/SamplesV2/SelfHostedIntegrationRuntime/AutomationScripts/script-update-gateway.ps1
# Refactored to library.ps1

# This script is used to udpate/ install + register latest Microsoft Integration Runtime.
# And the steps are like this:
# 1. check current Microsoft Integration Runtime version
# 2. Get auto-update version or specified version from argument
# 3. if there is newer version than current version  
#    3.1 download Microsoft Integration Runtime msi
#    3.2 upgrade it

## And here is the usage:
## 1. Download and install latest Microsoft Integration Runtime
## PS > .\script-update-gateway.ps1
## 2. Download and install Microsoft Integration Runtime of specified version
## PS > .\script-update-gateway.ps1 -version 2.11.6380.20

param(
    [Parameter(Mandatory=$false)]
    [string]
    $version
)

If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
    [Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    Write-Warning "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator!"
    Break
}

$currentVersion = Get-CurrentGatewayVersion
if ($currentVersion -eq $null)
{
    Write-Log "There is no Microsoft Integration Runtime found on your machine, exiting ..."
    break
}

$versionToInstall = $version
if ([string]::IsNullOrEmpty($versionToInstall))
{
    $versionToInstall = Get-LatestGatewayVersion
}

if ([System.Version]$currentVersion -ge [System.Version]$versionToInstall)
{
    Write-Log "Your Microsoft Integration Runtime is latest, no update need..."
}
else
{
    $msi = Download-GatewayInstaller-To-TempDirectory $versionToInstall
    Install-Gateway $msi
    Remove-Item -Path $msi -Force
}
