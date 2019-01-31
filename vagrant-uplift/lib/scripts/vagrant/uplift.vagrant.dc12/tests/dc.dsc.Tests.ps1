# avoiding: Attempting to perform the InitializeDefaultDrives operation on the ‘ActiveDirectory’ provider failed.
# https://mikefrobbins.com/2011/02/17/managed-service-accounts/

try {
    Import-Module ActiveDirectory -ErrorAction SilentlyContinue

} catch {
    try {
        Import-Module ActiveDirectory
    } catch {

    }
}


Describe 'Domain Controller' {

    Context "Network" {

        It 'ipconfig like "192.168.*.*"' {
             ((Get-NetIpAddress) `
                | where-object { $_.IPAddress -like "192.168.*.*" })   `
                | Should Not Be $null
        }

    }

    Context "Features" {
        It 'AD-Domain-Services' {
            (Get-WindowsFeature AD-Domain-Services).InstallState | Should BeLike "Installed"
        }

        It 'DNS' {
            (Get-WindowsFeature DNS).InstallState | Should BeLike "Installed"
        }

    }

    Context "Services" {

        It 'DNS Server' {
            (Get-Service "DNS Server").Status | Should BeLike "Running"
        }

        It 'Active Directory Domain Services' {
            (Get-Service "Active Directory Domain Services").Status | Should BeLike "Running"
        }

        It 'Active Directory Web Services' {
            (Get-Service "Active Directory Web Services").Status | Should BeLike "Running"
        }

    }

    Context "AD Module warm up" {

        # warning up AD
        # looks like it would always fails for the first run
        # https://social.msdn.microsoft.com/Forums/en-US/60fed6d1-e5ab-4a0f-8c45-c08eccf29cb7/custom-script-extension-importmodule-attempting-to-perform-the-initializedefaultdrives-operation?forum=azurescripting
        BeforeAll {
            try {
                Import-Module ActiveDirectory

            } catch {

            }

            try {
                props = get-ADComputer $env:computername -properties *

            } catch {

            }

            try {
                $user = Get-ADUser "vagrant"

            } catch {

            }

        }

        It 'AD module warn up' {

            try {
                Import-Module ActiveDirectory

            } catch {

            }

            try {
                props = get-ADComputer $env:computername -properties *

            } catch {

            }

            try {
                $user = Get-ADUser "vagrant"

            } catch {

            }
        }

    }


    Context "Users" {

        # warning up AD
        # looks like it would always fails for the first run
        # https://social.msdn.microsoft.com/Forums/en-US/60fed6d1-e5ab-4a0f-8c45-c08eccf29cb7/custom-script-extension-importmodule-attempting-to-perform-the-initializedefaultdrives-operation?forum=azurescripting
        BeforeAll {
            try {
                Import-Module ActiveDirectory

            } catch {

            }

            try {
                props = get-ADComputer $env:computername -properties *

            } catch {

            }

            try {
                $user = Get-ADUser "vagrant"

            } catch {

            }

        }
    }

    Context "Domain Controller" {

        # It 'PrimaryGroupID: 516' {

        #     Import-Module ActiveDirectory
        #     $props = get-ADComputer $env:computername -properties *
        #     $id =  $props.PrimaryGroupID

        #     $id | Should Be 516
        # }

        It 'domain: *.local' {

            $env:USERDNSDOMAIN | Should BeLike "*.local"
        }

        It 'vm name: *.local' {
            $name = (Get-WmiObject win32_computersystem).DNSHostName+"."+(Get-WmiObject win32_computersystem).Domain

            $name | Should BeLike "*.local"
        }

    }

}
