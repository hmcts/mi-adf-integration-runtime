Import-Module $PSScriptRoot\library.ps1
Import-Module $PSScriptRoot\oracle-connections.ps1
Import-Module $PSScriptRoot\secrets-setup.ps1

$DmgcmdPath = "C:\Program Files\Microsoft Integration Runtime\5.0\Shared\dmgcmd.exe"

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

    Write-Log "diahost.exe is not running"
    return $FALSE
}

function Get-Connection-Status() {
    $processStartInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processStartInfo.FileName = $DmgcmdPath
    $processStartInfo.RedirectStandardError = $true
    $processStartInfo.RedirectStandardOutput = $true
    $processStartInfo.UseShellExecute = $false
    $processStartInfo.Arguments = "-cgc"
    
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $processStartInfo
    $process.Start() | Out-Null
    $process.WaitForExit()
    
    $ConnectionResult = $process.StandardOutput.ReadToEnd() -replace "`t|`n|`r",""
    $ConnectionError = $process.StandardError.ReadToEnd()
    
    if ($ConnectionError) {
        Write-Log "Error raised: $($ConnectionError)"
    }
    
    return $ConnectionResult
}

function RegisterNewNode {
    Param(
        $AUTH_KEY,
        $NODE_NAME,
        $ENABLE_HA,
        $HA_PORT
    )

    Write-Log "Start registering a new SHIR node"

    if ($ENABLE_HA -eq "true") {
        Write-Log "Enable High Availability"
        $PORT = $HA_PORT
        if (!$HA_PORT) {
            $PORT = "8060"
        }
        Write-Log "Remote Access Port: $($PORT)"
        Start-Process $DmgcmdPath -Wait -ArgumentList "-EnableRemoteAccessInContainer", "$($PORT)" -RedirectStandardOutput "C:\SHIR\register-out.txt" -RedirectStandardError "C:\SHIR\register-error.txt"
        Start-Sleep -Seconds 15
    }

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

function Setup-SHIR() {
    if (Check-Is-Registered) {
        Write-Log "Restart the existing node"

        if ($ENABLE_HA -eq "true") {
            Write-Log "Enable High Availability"
            $PORT = $HA_PORT
            if (!$HA_PORT) {
                $PORT = "8060"
            }
            Write-Log "Remote Access Port: $($PORT)"
            Start-Process $DmgcmdPath -Wait -ArgumentList "-EnableRemoteAccessInContainer", "$($PORT)"
            Start-Sleep -Seconds 15
        }

        Start-Process $DmgcmdPath -Wait -ArgumentList "-Start"
    } elseif (Test-Path Env:AUTH_KEY) {
        Write-Log "Registering SHIR node with the node key: $($Env:AUTH_KEY)"
        Write-Log "Registering SHIR node with the node name: $($Env:NODE_NAME)"
        Write-Log "Registering SHIR node with the enable high availability flag: $($Env:ENABLE_HA)"
        Write-Log "Registering SHIR node with the tcp port: $($Env:HA_PORT)"

        Start-Process $DmgcmdPath -Wait -ArgumentList "-Start"

        RegisterNewNode $Env:AUTH_KEY $Env:NODE_NAME $Env:ENABLE_HA $Env:HA_PORT
    } else {
        Write-Log "Invalid AUTH_KEY Value"
        exit 1
    }
}


### Begin setup

# Setup tnsnames.ora file for any multi instance Oracle connections
Add-Tns-Secrets-To-Names-File

# Setup env from secrets
Set-Environment-Variables-From-Secrets

# Register SHIR with key from Env Variable: AUTH_KEY
Setup-SHIR

Write-Log "Waiting 60 seconds for connecting"
Start-Sleep -Seconds 60

try {
    $COUNT = 0
    $IS_REGISTERED = $FALSE
    while ($TRUE) {
        if(!$IS_REGISTERED) {
            if (Check-Is-Registered) {
                $IS_REGISTERED = $TRUE
                Write-Log "Self-hosted Integration Runtime is connected to the cloud service"
            }
        }

        $CONNECTION_RESULT = Get-Connection-Status
        if ((Check-Main-Process) -And ($CONNECTION_RESULT -Like "Connected")) {
            $COUNT = 0
        } else {
            Write-Log "Waiting for main process to start or registration to complete"
            $COUNT += 1
            if ($COUNT -gt 5) {
                throw "Diahost.exe is not running or not connected"  
            }
            
            if ($CONNECTION_RESULT -NotLike "Connecting") {
                Write-Log "Retrying setup"
                Setup-SHIR
            }
        }

        Start-Sleep -Seconds 60
    }
}
finally {
    Write-Log "Stop the node connection"
    Start-Process $DmgcmdPath -Wait -ArgumentList "-Stop"
    Write-Log "Stop the node connection successfully"
    exit 0
}

exit 1
