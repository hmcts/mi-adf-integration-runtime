Import-Module $PSScriptRoot\library.ps1

$DmgcmdPath = "C:\Program Files\Microsoft Integration Runtime\5.0\Shared\dmgcmd.exe"

function Check-Node-Connection() {
    $CONNECTION_RESULT = Get-Connection-Status
    if ((Check-Is-Registered) -And (Check-Main-Process) -And ($CONNECTION_RESULT -Like "Connected")) {
        return $TRUE
    }
    else {
        exit 1
    }
}

if (Check-Node-Connection) {   
    exit 0
}