
Describe 'PowerShell DCS' {

    Context "Modules" {

        It 'cChoco' {
            Get-Module -Name cChoco -ListAvailable | Should BeLike "cChoco"
        }

        It 'cFirewall' {
            Get-Module -Name cFirewall -ListAvailable | Should BeLike "cFirewall"
        }

        It 'SharePointDSC' {
            Get-Module -Name SharePointDSC -ListAvailable | Should BeLike "SharePointDSC"
        }

        It 'MS_xVisualStudio' {
            Get-Module -Name MS_xVisualStudio -ListAvailable | Should BeLike "MS_xVisualStudio"
        }

        It 'xActiveDirectory' {
            Get-Module -Name xActiveDirectory -ListAvailable | Should BeLike "xActiveDirectory"
        }

        It 'xSQLServer' {
            Get-Module -Name xSQLServer -ListAvailable | Should BeLike "xSQLServer"
        }

        It 'xDSCFirewall' {
            Get-Module -Name xDSCFirewall -ListAvailable | Should BeLike "xDSCFirewall"
        }

        It 'xNetworking' {
            Get-Module -Name xNetworking -ListAvailable | Should BeLike "xNetworking"
        }

        It 'xTimeZone' {
            Get-Module -Name xTimeZone -ListAvailable | Should BeLike "xTimeZone"
        }

        It 'xWebAdministration' {
            Get-Module -Name xWebAdministration -ListAvailable | Should BeLike "xWebAdministration"
        }

        It 'xPendingReboot' {
            Get-Module -Name xPendingReboot -ListAvailable | Should BeLike "xPendingReboot"
        }

        It 'xComputerManagement' {
            Get-Module -Name xComputerManagement -ListAvailable | Should BeLike "xComputerManagement"
        }

        It 'Pester' {
            Get-Module -Name Pester -ListAvailable | Should BeLike "Pester"
        }

        It 'xSystemSecurity' {
            Get-Module -Name xSystemSecurity -ListAvailable | Should BeLike "xSystemSecurity"
        }

        It 'DSCR_Shortcut' {
            Get-Module -Name DSCR_Shortcut -ListAvailable | Should BeLike "DSCR_Shortcut"
        }

        It 'PSWindowsUpdate' {
            Get-Module -Name PSWindowsUpdate -ListAvailable | Should BeLike "PSWindowsUpdate"
        }

    }
}