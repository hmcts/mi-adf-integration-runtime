Import-Module $PSScriptRoot\library.ps1

$SecretsList = @(
    ("cgi-tec-tns-descriptor")
)

function Add-Tns-Secrets-To-Names-File() {
    if (Test-Path Env:SECRETS_MOUNT_PATH) {
        foreach ($TnsSecret in $SecretsList) {
            $SecretFilePath = ${Env:SECRETS_MOUNT_PATH} + "\" + ${TnsSecret}
            if (Test-Path -Path "${SecretFilePath}" -PathType Leaf) {
                Write-Log "Adding value of ${TnsSecret} to tnsnames file."
                $TnsValue = Get-Content ${SecretFilePath}
                Add-Content "C:\SHIR\tnsnames.ora" "$([Environment]::NewLine)${TnsValue}"
            }
            else {
                Write-Log "TNS secret ${TnsSecret} not mounted."
            }
        }
    }
    else {
        Write-Log "No mounted secrets."
    }
}