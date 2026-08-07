Import-Module $PSScriptRoot\library.ps1

$SecretsList = @(
    ("cgi-tec-tns-descriptor"),
    ("cgi-libra-tns-descriptor")
)

function Add-Tns-Secrets-To-Names-File() {
    $LocalTnsFile = "C:\SHIR\tnsnames.ora"
    $InstantClientDir = (
        ($env:PATH -split ";" | Where-Object { $_ -like "*instantclient*" } | Select-Object -First 1),
        (Get-ChildItem "C:\oracle" -Filter "instantclient_*" -Directory -ErrorAction SilentlyContinue | Select-Object -First 1).FullName
    ) | Where-Object { $_ } | Select-Object -First 1

    $TnsAdminDir = $null
    if ($InstantClientDir) {
        $TnsAdminDir = Join-Path $InstantClientDir "network\admin"
        if (-not (Test-Path $TnsAdminDir)) {
            New-Item -ItemType Directory -Path $TnsAdminDir -Force | Out-Null
            Write-Log "Created Instant Client TNS admin directory: $TnsAdminDir"
        }
    } else {
        Write-Log "Could not locate Oracle Instant Client directory. Skipping tnsnames.ora copy."
    }

    if (Test-Path "Env:SECRETS_MOUNT_PATH") {
        foreach ($TnsSecret in $SecretsList) {
            $SecretFilePath = "${Env:SECRETS_MOUNT_PATH}" + "\" + "${TnsSecret}"
            if (Test-Path -Path "${SecretFilePath}" -PathType Leaf) {
                Write-Log "Adding value of ${TnsSecret} to tnsnames file."
                $TnsValue = Get-Content "${SecretFilePath}"
                Add-Content $LocalTnsFile "$([Environment]::NewLine)${TnsValue}"
            }
            else {
                Write-Log "TNS secret ${TnsSecret} not mounted."
            }
        }

        if ($TnsAdminDir) {
            try {
                Copy-Item -Path $LocalTnsFile -Destination $TnsAdminDir -Force
                Write-Log "Copied tnsnames.ora to: $TnsAdminDir"
            }
            catch {
                Write-Log "Failed to copy tnsnames.ora to ${TnsAdminDir}: $_"
            }
        }
    }
    else {
        Write-Log "No mounted secrets."
    }
}
