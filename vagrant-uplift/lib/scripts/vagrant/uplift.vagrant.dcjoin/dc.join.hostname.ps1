# fail on errors and include uplift helpers
$ErrorActionPreference = "Stop"

Import-Module Uplift.Core

$fullComputerName = ( Get-CimInstance win32_computersystem ).DNSHostName `
                    + "." `
                    + (Get-CimInstance win32_computersystem).Domain

Write-UpliftMessage "`thost name: $(hostname)"
Write-UpliftMessage "`tfull name: $fullComputerName"

exit 0