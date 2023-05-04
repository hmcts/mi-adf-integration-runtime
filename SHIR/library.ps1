function Write-Log($Message) {
    function TS { Get-Date -Format 'MM/dd/yyyy hh:mm:ss' }
    Write-Host "[$(TS)] $Message"
}

function Write-Log-Error($Message) {
    function TS { Get-Date -Format 'MM/dd/yyyy hh:mm:ss' }
    Write-Error "[$(TS)] $Message"
}
