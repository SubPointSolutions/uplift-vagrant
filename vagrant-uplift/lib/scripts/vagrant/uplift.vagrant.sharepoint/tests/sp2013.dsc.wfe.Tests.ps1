Describe 'SharePoint 2013' {

    function Is-Service-Running($serviceName)
    {
        (get-service $serviceName).Status | Should BeLike "Running"
    }

    Context "General Services" {

        It 'World Wide Web Publishing Service' {
            Is-Service-Running "World Wide Web Publishing Service"
         }

    }

    Context "SharePoint Services" {

         It 'SharePoint Administration' {
            Is-Service-Running "SharePoint Administration"
         }

         It 'SharePoint Search Host Controller' {
            Is-Service-Running "SharePoint Search Host Controller"
         }

         It 'SharePoint Server Search 15' {
            Is-Service-Running "SharePoint Server Search 15"
         }

         It 'SharePoint Timer Service' {
            Is-Service-Running "SharePoint Timer Service"
         }

         It 'SharePoint Tracing Service' {
            Is-Service-Running "SharePoint Tracing Service"
         }

         It 'SharePoint User Code Host' {
            Is-Service-Running "SharePoint User Code Host"
         }

     }

     function IIS-AppPool-Running($appPoolName) {
        Import-Module WebAdministration
        (
            (get-CHildItem "IIS:\\AppPools") `
                | Where-Object { $_.Name -eq $appPoolName }
        ).State | Should BeLike "Started"
     }

     Context "SharePoint IIS App Pools" {

        It 'SharePoint Web Services Root' {
            IIS-AppPool-Running "SharePoint Web Services Root"
        }

        It 'SharePoint Central Administration v4' {
            IIS-AppPool-Running "SharePoint Central Administration v4"
        }

        It 'SecurityTokenServiceApplicationPool' {
            IIS-AppPool-Running "SecurityTokenServiceApplicationPool"
        }

     }

}
