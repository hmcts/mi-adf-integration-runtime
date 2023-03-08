function Write-Log($Message) {
    function TS { Get-Date -Format 'MM/dd/yyyy hh:mm:ss' }
    Write-Host "[$(TS)] $Message"
}

function Is-64BitSystem
{
     $computerName = $env:COMPUTERNAME
     $osBit = (get-wmiobject win32_processor -computername $computerName).AddressWidth
     return $osBit -eq '64'
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

function Get-CmdFilePath()
{
    return "C:\Program Files\Microsoft Integration Runtime\5.0\Shared\dmgcmd.exe"
}

function Get-DiaWpConfigFilePath()
{
    return "C:\Program Files\Microsoft Integration Runtime\5.0\Shared\diawp.exe.config"
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

function Get-LatestGatewayVersion()
{
    $latestGateway = Get-RedirectedUrl "https://go.microsoft.com/fwlink/?linkid=839822"
    $item = $latestGateway.split("/") | Select-Object -Last 1
    if ($null -eq $item -or $item -notlike "IntegrationRuntime*")
    {
        throw "Can't get latest gateway info"
    }

    $regexp = '^IntegrationRuntime_(\d+\.\d+\.\d+\.\d+)\.msi$'

    $version = [regex]::Match($item, $regexp).Groups[1].Value
    if (!$version)
    {
        throw "Can't get version from gateway download uri"
    }

    $msg = "Latest gateway version is: " + $version
    Write-Log $msg
    $additionalMsg = "However using fixed version: 5.25.8404.1"
    Write-Log $additionalMsg
    return "5.25.8404.1"
}
