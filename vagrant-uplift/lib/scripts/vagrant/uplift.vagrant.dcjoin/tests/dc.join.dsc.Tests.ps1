Describe 'Domain Controller' {

    Context "Domain membership" {

        It 'Should be part of domain' {
            (Get-CimInstance -Class Win32_ComputerSystem).PartOfDomain `
                | Should Be $true
        }

    }

}
