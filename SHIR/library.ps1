function Write-Log($Message) {
    function TS { Get-Date -Format 'MM/dd/yyyy hh:mm:ss' }
    Write-Host "[$(TS)] $Message"
}

function Download-GatewayInstaller
{
    Param (
        [Parameter(Mandatory=$true)]
        [String]$version
    )

    Write-Log "Start to download MSI"
    $uri = Populate-Url $version
    $output = "$PSScriptRoot\IntegrationRuntime_$version.msi"
    Write-Log "Downloading from: $uri"
    (New-Object System.Net.WebClient).DownloadFile($uri, $output)

    $exist = Test-Path($output)
    if ( $exist -eq $false)
    {
        throw "Cannot download specified MSI"
    }

    $msg = "New gateway MSI has been downloaded to " + $output
    Write-Log $msg
    return $output
}

function Download-GatewayInstaller-To-TempDirectory
{
    Param (
        [Parameter(Mandatory=$true)]
        [String]$version
    )

    Write-Log "Start to download MSI"
    $uri = Populate-Url $version
    $folder = New-TempDirectory
    $output = Join-Path $folder "IntegrationRuntime.msi"
    (New-Object System.Net.WebClient).DownloadFile($uri, $output)

    $exist = Test-Path($output)
    if ( $exist -eq $false)
    {
        throw "Cannot download specified MSI"
    }

    $msg = "New Microsoft Integration Runtime MSI has been downloaded to " + $output
    Write-Log $msg
    return $output
}

function Get-CmdFilePath()
{
    $filePath = Get-ItemPropertyValue "hklm:\Software\Microsoft\DataTransfer\DataManagementGateway\ConfigurationManager" "DiacmdPath"
    if ([string]::IsNullOrEmpty($filePath))
    {
        throw "Get-InstalledFilePath: Cannot find installed File Path"
    }

    # dmgcmd performs the same functions but has return error messages and exit codes and is the preferred cmd to use.
    $filePath = $filePath -replace "diacmd","dmgcmd"
    return $filePath
}

function Get-CurrentGatewayVersion()
{
    $registryKeyValue = Get-RegistryKeyValue "Software\Microsoft\DataTransfer\DataManagementGateway\ConfigurationManager"

    $baseFolderPath = [System.IO.Path]::GetDirectoryName($registryKeyValue.GetValue("DiacmdPath"))
    $filePath = [System.IO.Path]::Combine($baseFolderPath, "Microsoft.DataTransfer.GatewayManagement.dll")

    $version = $null
    if (Test-Path $filePath)
    {
        $version = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($filePath).FileVersion
        $msg = "Current version: " + $version
        Write-Log $msg
    }

    return $version
}

function Get-LatestGatewayVersion()
{
    $latestGateway = Get-RedirectedUrl "https://go.microsoft.com/fwlink/?linkid=839822"
    $item = $latestGateway.split("/") | Select-Object -Last 1
    if ($item -eq $null -or $item -notlike "IntegrationRuntime*")
    {
        throw "Can't get latest Microsoft Integration Runtime info"
    }

    $regexp = '^IntegrationRuntime_(\d+\.\d+\.\d+\.\d+)\s*\.msi$'

    $version = [regex]::Match($item, $regexp).Groups[1].Value
    if ($version -eq $null)
    {
        throw "Can't get version from Microsoft Integration Runtime download uri"
    }

    $msg = "Auto-update version: " + $version
    Write-Log $msg
    return $version
}

function Get-RedirectedUrl
{
    # Latest version link
    $URL = "https://go.microsoft.com/fwlink/?linkid=839822"

    $request = [System.Net.WebRequest]::Create($url)
    $request.AllowAutoRedirect=$false
    $response=$request.GetResponse()

    If ($response.StatusCode -eq "Found")
    {
        $response.GetResponseHeader("Location")
    }
}

function Get-RegistryKeyValue
{
     param($registryPath)

     $is64Bits = Is-64BitSystem
     if($is64Bits)
     {
          $baseKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Registry64)
          return $baseKey.OpenSubKey($registryPath)
     }
     else
     {
          $baseKey = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Registry32)
          return $baseKey.OpenSubKey($registryPath)
     }
}

function Install-Gateway
{
    Param (
        [Parameter(Mandatory=$true)]
        [String]$msi
    )

    $exist = Test-Path($msi)
    if ( $exist -eq $false)
    {
        throw 'there is no MSI found: $msi'
    }


    Write-Log "Start to install Microsoft Integration Runtime ..."

    $arg = "/i " + $msi + " /quiet /norestart"
    Start-Process -FilePath "msiexec.exe" -ArgumentList $arg -Wait -Passthru -NoNewWindow

    Write-Log "Microsoft Integration Runtime has been successfully updated!"
}

function Is-64BitSystem
{
     $computerName = $env:COMPUTERNAME
     $osBit = (get-wmiobject win32_processor -computername $computerName).AddressWidth
     return $osBit -eq '64'
}

function New-TempDirectory {
    $parent = [System.IO.Path]::GetTempPath()
    [string] $name = [System.Guid]::NewGuid()
    New-Item -ItemType Directory -Path (Join-Path $parent $name)
}

function Populate-Url
{
    Param (
        [Parameter(Mandatory=$true)]
        [String]$version
    )

    $uri = Get-RedirectedUrl
    $uri = $uri.Substring(0, $uri.LastIndexOf('/') + 1)
    $uri += "IntegrationRuntime_$version"
    $uri += ".msi"

    return $uri
}
