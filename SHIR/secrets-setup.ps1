Import-Module $PSScriptRoot\library.ps1

$SecretsMap = @{
    "mi-adf-auth-key" = "AUTH_KEY"
}

function Set-Environment-Varibles-From-Secrets() {
    if (Test-Path Env:SECRETS_MOUNT_PATH) {
        $SecretsMountPath = (Get-Item Env:SECRETS_MOUNT_PATH).Value
        Write-Log "Getting secrets from KeyVault Mount: $($SecretsMountPath)"

        foreach ($SecretKey in $SecretsMap.Keys) {
            $EnvToSet = $SecretsMap.Item($SecretKey);
            Write-Log "Using secret key: ${SecretKey} to assign to env ${EnvToSet}"
            $ValueToSet = Get-Content "$($SecretsMountPath)\$($SecretKey)"
            New-Item -Path "Env:$($EnvToSet.Name)" -Value $ValueToSet
        }    
    }
}