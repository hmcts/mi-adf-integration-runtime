Import-Module $PSScriptRoot\library.ps1
Import-Module $PSScriptRoot\secrets-setup.ps1

$DmgcmdPath = Get-CmdFilePath

function Check-Is-Registered() {
    $result = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\DataTransfer\DataManagementGateway\ConfigurationManager' -Name HaveRun -ErrorAction SilentlyContinue
    if (($result -ne $null) -and ($result.HaveRun -eq 'Mdw')) {
        return $TRUE
    }
    return $FALSE
}

function Check-Main-Process() {
    $ProcessResult = Get-WmiObject Win32_Process -Filter "name = 'diahost.exe'"
    
    if ($ProcessResult) {
        return $TRUE
    }
    else {
        Write-Log "Main Process not found"
        throw "Main Process not found"   
    }
}

function Check-Node-Connection() {
    Start-Process $DmgcmdPath -Wait -ArgumentList "-cgc" -RedirectStandardOutput "C:\SHIR\status-check.txt"
    $ConnectionResult = Get-Content "C:\SHIR\status-check.txt"
    Remove-Item -Force "C:\SHIR\status-check.txt"

    if ($ConnectionResult -like "Connected") {
        return $TRUE
    }
    else {
        Write-Log "Node is offline"
        throw "Node is offline"    
    }
}

function RegisterNewNode {
    Param(
        $AUTH_KEY,
        $NODE_NAME,
        $ENABLE_HA,
        $HA_PORT
    )

    Start-Process $DmgcmdPath -Wait -ArgumentList "-LogLevel", "All"
    Start-Process $DmgcmdPath -Wait -ArgumentList "-EventLogVerboseSetting", "On"

    if ($ENABLE_HA -eq "true") {
        $PORT = $HA_PORT -or "8060"
        Write-Log "Enable High Availability"
        Start-Process $DmgcmdPath -Wait -ArgumentList "-EnableRemoteAccess", "$($PORT)"
        Write-Log "Enable High Availability For Container"
        Start-Process $DmgcmdPath -Wait -ArgumentList "-EnableRemoteAccessInContainer", "$($PORT)"

        Write-Log "Waiting 30 seconds before registration"
        Start-Sleep -s 30
    }

    Write-Log "Start registering the new SHIR node"

    if (!$NODE_NAME) {
        Start-Process $DmgcmdPath -Wait -ArgumentList "-RegisterNewNode", "$($AUTH_KEY)" -RedirectStandardOutput "C:\SHIR\register-out.txt" -RedirectStandardError "C:\SHIR\register-error.txt"
    } else {
        Start-Process $DmgcmdPath -Wait -ArgumentList "-RegisterNewNode", "$($AUTH_KEY)", "$($NODE_NAME)" -RedirectStandardOutput "C:\SHIR\register-out.txt" -RedirectStandardError "C:\SHIR\register-error.txt"
    }

    $StdOutResult = Get-Content "C:\SHIR\register-out.txt"
    $StdErrResult = Get-Content "C:\SHIR\register-error.txt"


    if ($StdOutResult)
    {
        Write-Log "Registration output:"
        $StdOutResult | ForEach-Object { Write-Log $_ }
    }

    if ($StdErrResult)
    {
        Write-Log "Registration errors:"
        $StdErrResult | ForEach-Object { Write-Log $_ }
    }
}

# Setup env from secrets
Set-Environment-Varibles-From-Secrets

# Register SHIR with key from Env Variable: AUTH_KEY
if (Check-Is-Registered) {
    Write-Log "Restart the existing node"
    Start-Process $DmgcmdPath -Wait -ArgumentList "-Start"
} elseif (Test-Path Env:AUTH_KEY) {
    $IRAuthKey = (Get-Item Env:AUTH_KEY).Value
    $IRNodeName = (Get-Item Env:NODE_NAME).Value
    $IREnableHA = (Get-Item Env:ENABLE_HA).Value
    $IRHAPort = (Get-Item Env:HA_PORT).Value

    Write-Log "Registering SHIR with the node key: $($IRAuthKey)"
    Write-Log "Registering SHIR with the node name: $($IRNodeName)"
    Write-Log "Registering SHIR with the enable high availability flag: $($IREnableHA)"
    Write-Log "Registering SHIR with the tcp port: $($IRHAPort)"
    Start-Process $DmgcmdPath -Wait -ArgumentList "-Start"
    RegisterNewNode $IRAuthKey $IRNodeName $IREnableHA $IRHAPort
} else {
    Write-Log "Invalid AUTH_KEY Value"
    exit 1
}

Write-Log "Waiting 30 seconds waiting for connecting"
Start-Sleep -Seconds 30

try {
    while ($TRUE) {
        if ((Check-Main-Process) -and (Check-Node-Connection)) {   
            Write-Log "Node Health Check Pass"
            Start-Sleep -Seconds 60
            continue
        }
    }
}
finally {
    Write-Log "Stop the node connection"
    Start-Process $DmgcmdPath -Wait -ArgumentList "-Stop"
    Write-Log "Stop the node connection successfully"
    exit 0
}

exit 1