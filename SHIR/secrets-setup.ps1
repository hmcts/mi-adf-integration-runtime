Import-Module $PSScriptRoot\library.ps1

$AuthKeySecretNameEnv = "AUTH_KEY_SECRET_NAME"
$DefaultAuthKeySecretName = "mi-adf-auth-key"

$SecretsMap = @{}

function Set-Environment-Variables-From-Secrets() {
    if (Test-Path Env:SECRETS_MOUNT_PATH) {
        if (Test-Path Env:$AuthKeySecretNameEnv) {
            $AuthKeySecretName = (Get-Item Env:$AuthKeySecretNameEnv).Value
        } else {
            $AuthKeySecretName = $DefaultAuthKeySecretName
        }
        Write-Log "Setting AUTH_KEY from mounted secret $($AuthKeySecretName)"
        $SecretsMap[$AuthKeySecretName] = "AUTH_KEY"

        $SecretsMountPath = (Get-Item Env:SECRETS_MOUNT_PATH).Value
        Write-Log "Getting secrets from KeyVault Mount: $($SecretsMountPath)"

        $Files = Get-ChildItem -File "$($SecretsMountPath)"

        foreach ($File in $Files) {
            $EnvToSet = $File.Name.ToUpper().Replace('-', '_') # Dash Delimiter is invalid Environment Variable name
            if ($SecretsMap.ContainsKey($File.Name)) {
                $EnvToSet = $SecretsMap.Item($File.Name);
            }

            Write-Log "Using secret key: ${File.Name} to assign to env ${EnvToSet}"
            $ValueToSet = Get-Content "$($File.FullName)"
            New-Item -Force -Path "Env:$($EnvToSet)" -Value $ValueToSet
        }
    }
    else {
        Write-Log "No mounted secrets."
    }
}