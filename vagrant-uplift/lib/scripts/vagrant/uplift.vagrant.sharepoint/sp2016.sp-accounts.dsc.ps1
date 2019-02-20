# fail on errors and include uplift helpers
$ErrorActionPreference = "Stop"

Import-Module Uplift.Core

Write-UpliftMessage "Configring SharePoint accounts..."
Write-UpliftEnv

Configuration Configure_SharePointUsers {

    Import-DscResource -ModuleName PSDesiredStateConfiguration

    Import-DscResource -ModuleName xActiveDirectory -ModuleVersion 2.17.0.0

    Node localhost
    {
            $dependsOnString = @()

             $domainAdminCreds = New-Object System.Management.Automation.PSCredential(
                    "uplift\vagrant", 
                     (ConvertTo-SecureString "vagrant" -AsPlainText -Force)
                )

            foreach($user in $Node.Users) {
               
                $userCreds = New-Object System.Management.Automation.PSCredential(
                    $user,
                    (ConvertTo-SecureString "uplift!QAZ" -AsPlainText -Force)
                )

                $dependsOnString += ("[xADUser]User_$user")

                xADUser "User_$user"
                {
                    DomainName = "uplift"
                    DomainAdministratorCredential = $domainAdminCreds 
                    UserName = $user
                    Password = $userCreds
                    Ensure = "Present"
                }
            }

            xADGroup DomainAdmins
            {
                GroupName           = "Domain Admins"
                MembersToInclude    = $Node.DomainAdminUsers
                DependsOn           = $dependsOnString

                Credential = $domainAdminCreds 
            }
    }

}

# SharePoint 2016 Service Accounts
# https://absolute-sharepoint.com/2017/03/sharepoint-2016-service-accounts-recommendations.html
$config = @{
    AllNodes = @(
        @{
            NodeName = 'localhost'
            PSDscAllowPlainTextPassword = $true
            PSDscAllowDomainUser = $true
            
            RetryCount = 10           
            RetryIntervalSec = 30

            Users = @(
                "sp_install"

                "sp_admin"
                "sp_farm"
                "sp_services"
                "sp_pool"

                "sp_crawl"
                "sp_sync"
                "sp_c2wts"

                "sp_su"
                "sp_sr",

                "uplift_user1",
                "uplift_user2",
                "uplift_user3"
            )

            DomainAdminUsers = @(
                "sp_install"
                "sp_admin"
            )
        }
    )
}

$configuration = Get-Command Configure_SharePointUsers
Start-UpliftDSCConfiguration $configuration $config 

exit 0