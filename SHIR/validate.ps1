Import-Module $PSScriptRoot\library.ps1

# These commands shows syntax errors on any Powershell script
# Add additional scripts here that need validation

try {
    Write-Log "Validating powershell scripts in SHIR."

    Get-Command -syntax "$PSScriptRoot\library.ps1"
    Get-Command -syntax "$PSScriptRoot\build.ps1"
    Get-Command -syntax "$PSScriptRoot\health-check.ps1"
    Get-Command -syntax "$PSScriptRoot\secrets-setup.ps1"
    Get-Command -syntax "$PSScriptRoot\setup.ps1"
} catch {
    Write-Log "Error in powershell syntax. Please check logs."
    throw "Error in syntax"
}