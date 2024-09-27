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
    Write-Log "Will remove C:\SHIR\$MsiFileName"
    Remove-Item "C:\SHIR\$MsiFileName"
    Write-Log "Removed C:\SHIR\$MsiFileName"
}

function Install-MSFT-JDK() {
    Write-Log "Install the Microsoft OpenJDK in the Windows container"

    Write-Log "Downloading Microsoft OpenJDK 11 LTS msi"
    $JDKMsiFileName = 'microsoft-jdk-11-windows-x64.msi'

    # Temporarily disable progress updates to speed up the download process. (See https://stackoverflow.com/questions/69942663/invoke-webrequest-progress-becomes-irresponsive-paused-while-downloading-the-fil)
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri "https://aka.ms/download-jdk/$JDKMsiFileName" -OutFile "C:\SHIR\$JDKMsiFileName"
    $ProgressPreference = 'Continue'

    Write-Log "Installing Microsoft OpenJDK"
    # Arguments pulled from https://learn.microsoft.com/en-us/java/openjdk/install#install-via-msi
    Start-Process msiexec.exe -Wait -ArgumentList "/i C:\SHIR\$JDKMsiFileName ADDLOCAL=FeatureMain,FeatureEnvironment,FeatureJarFileRunWith,FeatureJavaHome INSTALLDIR=`"c:\Program Files\Microsoft\`" /quiet"
    if (!$?) {
        Write-Log "Microsoft OpenJDK MSI Install Failed"
    }
    Write-Log "Microsoft OpenJDK MSI Install Successfully"
    Write-Log "Will remove C:\SHIR\$JDKMsiFileName"
    Remove-Item "C:\SHIR\$JDKMsiFileName"
    Write-Log "Removed C:\SHIR\$JDKMsiFileName"
}

function Install-NetFramework() {
    Write-Log "Begin to install the NET Framework Visual C++ 2010 Redistributable"
    Invoke-WebRequest "https://download.microsoft.com/download/3/2/2/3224B87F-CFA0-4E70-BDA3-3DE650EFEBA5/vcredist_x64.exe" -OutFile "C:\SHIR\vcredist_x64.exe"
    Start-Process -Wait -FilePath "C:\SHIR\vcredist_x64.exe" -ArgumentList /install, /quiet, /norestart
    Write-Log "Vcc Redistributable installed successfully"
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

Install-SHIR

# #######################################################
# Add user to the monitoring groups
# the current user was fetched from a running pod using the below code
# $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
Add-Monitor-User "User Manager\ContainerAdministrator"  # This is the user that a user will enter as when logging into the container
Add-Monitor-User "NT SERVICE\DIAHostService"            # This is the user that runs the SHIR backend


if ([bool]::Parse($env:INSTALL_JDK)) {
    Install-MSFT-JDK
}

if ([bool]::Parse($env:INSTALL_NET_FRAMEWORK)) {
    Install-NetFramework
}

exit 0
