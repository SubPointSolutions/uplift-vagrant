# fail on errors and include uplift helpers
$ErrorActionPreference = "Stop"

Import-Module Uplift.Core

Write-UpliftMessage "Validating Visual Studio install..."
Write-UpliftEnv

$productName            = Get-UpliftEnvVariable "UPLF_VS_TEST_PRODUCT_NAME"
$officeToolsPackageName = Get-UpliftEnvVariable "UPLF_VS_TEST_OFFICETOOLS_PACKAGE_NAME"

Describe 'Visual Studio Install' {

    function Get-AppPackage($appName) {

        $result = @()

        $x32 = Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* `
            | Select-Object DisplayName, Name, DisplayVersion, Publisher, InstallDate  `
            | Sort-Object "DisplayName" `
            | Where-Object { ($null -ne $_.DisplayName) -and $_.DisplayName.Contains($appName) } `

        $x64 = Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* `
            | Select-Object DisplayName, Name, DisplayVersion, Publisher, InstallDate  `
            | Sort-Object "DisplayName" `
            | Where-Object { ($null -ne $_.DisplayName) -and $_.DisplayName.Contains($appName) } `

        $result += $x32
        $result += $x64

        return $result
    }

    function Confirm-AppPackageInstall($appName) {
        $app = Get-AppPackage $appName

        if($app.Count -gt 1) {
            # TODO, very nasty :)
            $app = $app[0]
        }

        $app.DisplayName | Should BeLike "*$appName*"
    }

    Context "Visual Studio App" {

        It "$productName" {
            Confirm-AppPackageInstall($productName)
        }

    }

    Context "Visual Studio Plugins" {

        It "$officeToolsPackageName" {
            Confirm-AppPackageInstall("$officeToolsPackageName")
        }

     }

}
