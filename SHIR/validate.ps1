Import-Module $PSScriptRoot\library.ps1

# These commands shows syntax errors on any Powershell script
# Add additional scripts here that need validation

function Test-ScriptSyntax([string]$Path) {
    $errors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile(
        (Resolve-Path $Path).Path,
        [ref]$null,
        [ref]$errors
    )
    if ($errors.Count -eq 0) {
        Write-Log "OK: $Path"
        return $true
    }
    foreach ($err in $errors) {
        Write-Log "ERROR [$Path] Line $($err.Extent.StartLineNumber),$($err.Extent.StartColumnNumber): $($err.Message)"
    }
    return $false
}

try {
    Write-Log "Validating powershell scripts in SHIR."

    Test-ScriptSyntax "$PSScriptRoot\library.ps1"
    Test-ScriptSyntax "$PSScriptRoot\build.ps1"
    Test-ScriptSyntax "$PSScriptRoot\health-check.ps1"
    Test-ScriptSyntax "$PSScriptRoot\oracle-connections.ps1"
    Test-ScriptSyntax "$PSScriptRoot\secrets-setup.ps1"
    Test-ScriptSyntax "$PSScriptRoot\setup.ps1"
} catch {
    Write-Log "Error in powershell syntax. Please check logs."
    Write-Log $_
    throw "Error in syntax"
}
