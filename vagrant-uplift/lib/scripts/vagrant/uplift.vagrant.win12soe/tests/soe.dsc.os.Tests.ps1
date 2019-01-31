Describe 'OS' {

    Context "Settings" {
        # timezone is set to AU
        It 'AUS Eastern Standard Time' {
            ([System.TimeZone]::CurrentTimeZone).StandardName | Should BeLike "AUS Eastern Standard Time"
        }

        # auto-update settings
        It 'NoAutoUpdate = 1' {

            $regKey = "HKLM:SOFTWARE\\Policies\\Microsoft\\Windows\\WindowsUpdate\\AU"

            (Get-Item $regKey).GetValue('NoAutoUpdate') | Should Be 1
        }

        It 'AUOptions = 1' {
            $regKey = "HKLM:SOFTWARE\\Policies\\Microsoft\\Windows\\WindowsUpdate\\AU"

            (Get-Item $regKey).GetValue('AUOptions') | Should Be 2
        }
    }

    Context "Features" {
        It 'AD-Domain-Services' {
            (Get-WindowsFeature AD-Domain-Services).InstallState | Should BeLike "Installed"
        }

        It 'RSAT-ADDS-Tools' {
            (Get-WindowsFeature RSAT-ADDS-Tools).InstallState | Should BeLike "Installed"
        }

        It 'RSAT' {
            (Get-WindowsFeature RSAT).InstallState | Should BeLike "Installed"
        }
    }

    Context "Firewall" {
        It 'domain is OFF' {
            $FWProfile = "DomainProfile"
            $Actual = Invoke-Command -ScriptBlock { (Get-ItemProperty "HKLM:\System\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\$FWProfile" -Name EnableFirewall).EnableFirewall }

            $Actual | Should Be 0

        }

        It 'public is OFF' {
            $FWProfile = "PublicProfile"
            $Actual = Invoke-Command -ScriptBlock { (Get-ItemProperty "HKLM:\System\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\$FWProfile" -Name EnableFirewall).EnableFirewall }

            $Actual | Should Be 0
        }

        It 'private is OFF' {
            $FWProfile = "StandardProfile"
            $Actual = Invoke-Command -ScriptBlock { (Get-ItemProperty "HKLM:\System\CurrentControlSet\Services\SharedAccess\Parameters\FirewallPolicy\$FWProfile" -Name EnableFirewall).EnableFirewall }

            $Actual | Should Be 0
        }
    }

    Context "Tools" {

        It 'choco is installed' {
            get-command choco | Should BeLike "*choco.exe*"
        }

        It '7zip is installed' {
            get-command 7z | Should BeLike "*7z.exe*"
        }

        It 'git is installed' {
            get-command git.exe | Should BeLike "*git.exe*"
        }

        It 'curl is installed' {
            get-command curl.exe | Should BeLike "*curl.exe*"
        }

        It 'wget is installed' {
            get-command wget.exe | Should BeLike "*wget.exe*"
        }

        It 'pwsh is installed' {
            get-command pwsh.exe | Should BeLike "*pwsh.exe*"
        }
    }

}
