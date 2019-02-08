# fail on errors and include uplift helpers
$ErrorActionPreference = "Stop"

Import-Module Uplift.Core

# include shared helpers from uplift.vagrant.sharepoint handler
. "c:/windows/temp/uplift.vagrant.sharepoint/shared/sp.helpers.ps1"

Write-UpliftMessage "Provisioning SharePoint farm minimal services"
Write-UpliftEnv

$spSqlServerName     = Get-UpliftEnvVariable "UPLF_SP_FARM_SQL_SERVER_HOST_NAME" 
$spSqlDbPrefix       = Get-UpliftEnvVariable "UPLF_SP_FARM_SQL_DB_PREFIX" 

$spSetupUserName     = Get-UpliftEnvVariable "UPLF_SP_SETUP_USER_NAME" 
$spSetupUserPassword = Get-UpliftEnvVariable "UPLF_SP_SETUP_USER_PASSWORD"

Configuration Install_SharePointFarmAdmins {
    
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName SharePointDsc -ModuleVersion 3.1.0.0

    Node localhost {
        $setupUserName       = $Node.SetupUserName 
        $setupUserPassword   = $Node.SetupUserPassword 

        $secureSetupUserPassword = ConvertTo-SecureString $setupUserPassword -AsPlainText -Force
        $setupUserCreds          = New-Object System.Management.Automation.PSCredential($setupUserName, $secureSetupUserPassword)
        
        $SPSetupAccount          = $setupUserCreds

        # TODO
        $spFarmUsers = @(
            "uplift\sp_install"
            "uplift\sp_admin"
        )

        LocalConfigurationManager 
        {
            RebootNodeIfNeeded = $false
        }

        # account setup
        SPShellAdmins ShellAdmins
        {
            IsSingleInstance = "Yes"
            MembersToInclude = $spFarmUsers
            AllDatabases     = $true

            PsDscRunAsCredential  = $SPSetupAccount
        }

        SPFarmAdministrators LocalFarmAdmins
        {
            IsSingleInstance = "Yes"
            MembersToInclude = $spFarmUsers
            
            PsDscRunAsCredential = $SPSetupAccount
        }
    }
}

Configuration Install_SharePointFarmMinimalServices
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName SharePointDsc -ModuleVersion 3.1.0.0

    function GetCreds($name, $pass) {
        return New-Object System.Management.Automation.PSCredential(
            $name, 
            (ConvertTo-SecureString $pass -AsPlainText -Force)
        )
    }

    Node localhost {
        $setupUserName       = $Node.SetupUserName 
        $setupUserPassword   = $Node.SetupUserPassword 
    
        $secureSetupUserPassword = ConvertTo-SecureString $setupUserPassword -AsPlainText -Force
        $setupUserCreds          = New-Object System.Management.Automation.PSCredential($setupUserName, $secureSetupUserPassword)
        
        $SPSetupAccount              = $setupUserCreds
        $SPFarmAccount               = $setupUserCreds
    
        $SPServicePoolManagedAccount = $setupUserCreds
        $SPWebPoolManagedAccount     = $setupUserCreds

        $SPUserProfileServiceAccount  = GetCreds "sp_install" "uplift!QAZ"
        $SPServiceAppPoolName = "SharePoint Service Applications"

        LocalConfigurationManager 
        {
            RebootNodeIfNeeded = $false
        }

        # ensuring that required services are up before running SharePoint farm creation
        # that allows to fail eraly in case of spoiled images
        Service W3SVC
        {
            Name            = "W3SVC"
            StartupType     = "Automatic"
            State           = "Running"
        }  

        Service IISADMIN
        {
            DependsOn       = "[Service]W3SVC"

            Name            = "IISADMIN"
            StartupType     = "Automatic"
            State           = "Running"
        } 
        
        # accounts
        SPManagedAccount ServicePoolManagedAccount
        {
            AccountName          = $SPServicePoolManagedAccount.UserName
            Account              = $SPServicePoolManagedAccount
            PsDscRunAsCredential = $SPSetupAccount
        }
        SPManagedAccount WebPoolManagedAccount
        {
            AccountName          = $SPWebPoolManagedAccount.UserName
            Account              = $SPWebPoolManagedAccount
            PsDscRunAsCredential = $SPSetupAccount
        }

        # default apps
        SPUsageApplication UsageApplication 
        {
            Name                  = "Usage Service Application"
            DatabaseName          = ($spSqlDbPrefix + "_SP_Usage" ) 
            UsageLogCutTime       = 5
            UsageLogLocation      = "C:\UsageLogs"
            UsageLogMaxFileSizeKB = 1024
            PsDscRunAsCredential  = $SPSetupAccount
        }

        SPStateServiceApp StateServiceApp
        {
            Name                 = "State Service Application"
            DatabaseName         = ($spSqlDbPrefix + "_SP_State")
            PsDscRunAsCredential = $SPSetupAccount
        }

        SPDistributedCacheService EnableDistributedCache
        {
            Name                 = "AppFabricCachingService"
            Ensure               = "Present"
            CacheSizeInMB        = 1024
            ServiceAccount       = $SPServicePoolManagedAccount.UserName
            PsDscRunAsCredential = $SPSetupAccount
            CreateFirewallRules  = $true
            DependsOn            = @('[SPManagedAccount]ServicePoolManagedAccount')
        }

        # default services
        SPServiceInstance ClaimsToWindowsTokenServiceInstance
        {  
            Name                 = "Claims to Windows Token Service"
            Ensure               = "Present"
            PsDscRunAsCredential = $SPSetupAccount
        }   

        SPServiceInstance SecureStoreServiceInstance
        {  
            Name                 = "Secure Store Service"
            Ensure               = "Present"
            PsDscRunAsCredential = $SPSetupAccount
        }
        
        SPServiceInstance ManagedMetadataServiceInstance
        {  
            Name                 = "Managed Metadata Web Service"
            Ensure               = "Present"
            PsDscRunAsCredential = $SPSetupAccount
        }

        SPServiceInstance SearchServiceInstance
        {  
            Name                 = "SharePoint Server Search"
            Ensure               = "Present"
            PsDscRunAsCredential = $SPSetupAccount
        }

        # service applications
        SPServiceAppPool MainServiceAppPool
        {
            Name                 = $SPServiceAppPoolName
            ServiceAccount       = $SPServicePoolManagedAccount.UserName
            PsDscRunAsCredential = $SPSetupAccount
        }

        SPSecureStoreServiceApp SecureStoreServiceApp
        {
            Name                  = "Secure Store Service Application"
            ApplicationPool       = $SPServiceAppPoolName
            AuditingEnabled       = $true
            AuditlogMaxSize       = 30
            DatabaseName          = ($spSqlDbPrefix + "_SP_SecureStore")
            PsDscRunAsCredential  = $SPSetupAccount
            DependsOn             = "[SPServiceAppPool]MainServiceAppPool"
        }
        
        SPManagedMetaDataServiceApp ManagedMetadataServiceApp
        {  
            Name                 = "Managed Metadata Service Application"
            PsDscRunAsCredential = $SPSetupAccount
            ApplicationPool      = $SPServiceAppPoolName
            DatabaseName         = ($spSqlDbPrefix + "_SP_MMS")
            DependsOn            = "[SPServiceAppPool]MainServiceAppPool"
        }

        SPSearchServiceApp SearchServiceApp
        {  
            Name                  = "Search Service Application"
            DatabaseName          = ($spSqlDbPrefix + "_SP_Search")
            ApplicationPool       = $SPServiceAppPoolName
            PsDscRunAsCredential  = $SPSetupAccount
            DependsOn             = "[SPServiceAppPool]MainServiceAppPool"
        }

        SPUserProfileServiceApp UserProfileServiceApp
        {
            Name                 = "User Profile Service Application"

            ApplicationPool      =  $SPServiceAppPoolName
            
            #MySiteHostLocation   = ("http://my.cntoso.local")
            #MySiteManagedPath    = "personal"

            ProfileDBName        = ($spSqlDbPrefix + "SP_UserProfiles")
            ProfileDBServer      = "$spSqlServerName"
            
            SocialDBName         = ($spSqlDbPrefix + "SP_Social")
            SocialDBServer       = "$spSqlServerName"
            
            SyncDBName           = ($spSqlDbPrefix + "SP_ProfileSync")
            SyncDBServer         = "$spSqlServerName"
            
            EnableNetBIOS        = $false
            
            #FarmAccount          = $SPSetupAccount
            #InstallAccount       = $SPSetupAccount

            PsDscRunAsCredential = $SPUserProfileServiceAccount

            DependsOn             = @(
                "[SPServiceAppPool]MainServiceAppPool"
            )
        }
     }
}

$config = @{
    AllNodes = @(
        @{
            NodeName = 'localhost'

            PSDscAllowDomainUser        = $true
            PSDscAllowPlainTextPassword = $true
       
            SetupUserName     = $spSetupUserName
            SetupUserPassword = $spSetupUserPassword   
        }
    )
}

$shellAdminConfig = Get-Command Install_SharePointFarmAdmins
Start-UpliftDSCConfiguration $shellAdminConfig $config 

$servicesConfig = Get-Command Install_SharePointFarmMinimalServices
Start-UpliftDSCConfiguration $servicesConfig $config 

# re-ensure farm admins
$shellAdminConfig = Get-Command Install_SharePointFarmAdmins
Start-UpliftDSCConfiguration $shellAdminConfig $config 

exit 0