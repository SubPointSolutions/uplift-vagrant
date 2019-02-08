cls

Add-PSSnapin "Microsoft.SharePoint.PowerShell" 
$apps = Get-SPServiceApplication 

Describe 'SharePoint Minimal Services Config' {

    function Check-ServiceApp($name) {
        $app     =  Get-SPServiceApplication -Name $name

        It 'exists' {
           $app | Should Not Be $null
        }

         It 'online' {
           $app.Status | Should Not Be $null
        }
    }

    Context "Usage Application" {
        Check-ServiceApp("Usage Service Application")
    }

    Context "State Service App" {
        Check-ServiceApp("State Service Application")
    }

    Context "Managed Metadata Service App" {
        Check-ServiceApp("Managed Metadata Service Application")
    }

    Context "Secure Store Service App" {
        Check-ServiceApp("Secure Store Service Application")
    }

    Context "Search Service App" {
        Check-ServiceApp("Search Service Application")
    }

    Context "User Profile Service App" {
        Check-ServiceApp("User Profile Service Application")
    }

    Context "Security Token Service Application" {
        Check-ServiceApp("SecurityTokenServiceApplication")
    }
}
