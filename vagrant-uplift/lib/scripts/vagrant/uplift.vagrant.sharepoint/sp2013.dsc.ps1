# fail on errors and include uplift helpers
$ErrorActionPreference = "Stop"

Import-Module Uplift.Core

# include shared helpers from uplift.vagrant.sharepoint handler
. "c:/windows/temp/uplift.vagrant.sharepoint/shared/sp.helpers.ps1"

Write-UpliftMessage "Creating new SharePoint farm..."
Write-UpliftEnv

$spSqlServerName = Get-UpliftEnvVariable "UPLF_SP_FARM_SQL_SERVER_HOST_NAME"
$spSqlDbPrefix   = Get-UpliftEnvVariable "UPLF_SP_FARM_SQL_DB_PREFIX"

$spPassPhrase    =  Get-UpliftEnvVariable "UPLF_SP_FARM_PASSPHRASE"

$spSetupUserName     = Get-UpliftEnvVariable "UPLF_SP_SETUP_USER_NAME"
$spSetupUserPassword = Get-UpliftEnvVariable "UPLF_SP_SETUP_USER_PASSWORD"

# prepare SQL server for SharePoint deployment
Initialize-UpSPSqlServer $spSqlServerName $spSqlDbPrefix 

# deploy SharePoint
Configuration Install_SharePointFarm
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName SharePointDsc

    Node localhost {

        $setupUserName       = $Node.SetupUserName 
        $setupUserPassword   = $Node.SetupUserPassword 
        $spPassPhrase        = $Node.PassPhrase 
    
        $secureSetupUserPassword = ConvertTo-SecureString $setupUserPassword -AsPlainText -Force
        $setupUserCreds          = New-Object System.Management.Automation.PSCredential($setupUserName, $secureSetupUserPassword)
        
        $securePassPhrase = ConvertTo-SecureString $spPassPhrase -AsPlainText -Force
        $passPhraseCreds  = New-Object System.Management.Automation.PSCredential($setupUserName, $securePassPhrase)
    
        $SPSetupAccount              = $setupUserCreds
        $SPFarmAccount               = $setupUserCreds
    
        $SPServicePoolManagedAccount = $setupUserCreds
        $SPWebPoolManagedAccount     = $setupUserCreds

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

        # initial farm creation
        SPFarm CreateSPFarm
        {
            DependsOn                = "[Service]IISADMIN"

            Ensure                   = "Present"
            DatabaseServer           = $spSqlServerName
            FarmConfigDatabaseName   = ($spSqlDbPrefix +  "_Config")
            Passphrase               = $passPhraseCreds
            FarmAccount              = $SPFarmAccount
            PsDscRunAsCredential     = $SPSetupAccount
            AdminContentDatabaseName = ($spSqlDbPrefix +  "_AdminContent")
            RunCentralAdmin          = $true
            #DependsOn                = "[SPInstall]InstallSharePoint"
        }

        # accounts
        SPManagedAccount ServicePoolManagedAccount
        {
            AccountName          = $SPServicePoolManagedAccount.UserName
            Account              = $SPServicePoolManagedAccount
            PsDscRunAsCredential = $SPSetupAccount
            DependsOn            = "[SPFarm]CreateSPFarm"
        }
        SPManagedAccount WebPoolManagedAccount
        {
            AccountName          = $SPWebPoolManagedAccount.UserName
            Account              = $SPWebPoolManagedAccount
            PsDscRunAsCredential = $SPSetupAccount
            DependsOn            = "[SPFarm]CreateSPFarm"
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
            DependsOn             = "[SPFarm]CreateSPFarm"
        }

        SPStateServiceApp StateServiceApp
        {
            Name                 = "State Service Application"
            DatabaseName         = ($spSqlDbPrefix + "_SP_State")
            PsDscRunAsCredential = $SPSetupAccount
            DependsOn            = "[SPFarm]CreateSPFarm"
        }

        SPDistributedCacheService EnableDistributedCache
        {
            Name                 = "AppFabricCachingService"
            Ensure               = "Present"
            CacheSizeInMB        = 1024
            ServiceAccount       = $SPServicePoolManagedAccount.UserName
            PsDscRunAsCredential = $SPSetupAccount
            CreateFirewallRules  = $true
            DependsOn            = @('[SPFarm]CreateSPFarm','[SPManagedAccount]ServicePoolManagedAccount')
        }

        # default services
        SPServiceInstance ClaimsToWindowsTokenServiceInstance
        {  
            Name                 = "Claims to Windows Token Service"
            Ensure               = "Present"
            PsDscRunAsCredential = $SPSetupAccount
            DependsOn            = "[SPFarm]CreateSPFarm"
        }   

        SPServiceInstance SecureStoreServiceInstance
        {  
            Name                 = "Secure Store Service"
            Ensure               = "Present"
            PsDscRunAsCredential = $SPSetupAccount
            DependsOn            = "[SPFarm]CreateSPFarm"
        }
        
        SPServiceInstance ManagedMetadataServiceInstance
        {  
            Name                 = "Managed Metadata Web Service"
            Ensure               = "Present"
            PsDscRunAsCredential = $SPSetupAccount
            DependsOn            = "[SPFarm]CreateSPFarm"
        }

        SPServiceInstance BCSServiceInstance
        {  
            Name                 = "Business Data Connectivity Service"
            Ensure               = "Present"
            PsDscRunAsCredential = $SPSetupAccount
            DependsOn            = "[SPFarm]CreateSPFarm"
        }
        
        SPServiceInstance SearchServiceInstance
        {  
            Name                 = "SharePoint Server Search"
            Ensure               = "Present"
            PsDscRunAsCredential = $SPSetupAccount
            DependsOn            = "[SPFarm]CreateSPFarm"
        }

        # service applications
        SPServiceAppPool MainServiceAppPool
        {
            Name                 = $SPServiceAppPoolName
            ServiceAccount       = $SPServicePoolManagedAccount.UserName
            PsDscRunAsCredential = $SPSetupAccount
            DependsOn            = "[SPFarm]CreateSPFarm"
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

        SPBCSServiceApp BCSServiceApp
        {
            Name                  = "BCS Service Application"
            DatabaseServer        = $spSqlServerName
            ApplicationPool       = $SPServiceAppPoolName
            DatabaseName          = ($spSqlDbPrefix + "_SP_BCS")
            PsDscRunAsCredential  = $SPSetupAccount
            DependsOn             = @('[SPServiceAppPool]MainServiceAppPool', '[SPSecureStoreServiceApp]SecureStoreServiceApp')
        }

        SPSearchServiceApp SearchServiceApp
        {  
            Name                  = "Search Service Application"
            DatabaseName          = ($spSqlDbPrefix + "_SP_Search")
            ApplicationPool       = $SPServiceAppPoolName
            PsDscRunAsCredential  = $SPSetupAccount
            DependsOn             = "[SPServiceAppPool]MainServiceAppPool"
        }
     }
}

$config = @{
    AllNodes = @(
        @{
            NodeName = 'localhost'

            PSDscAllowDomainUser        = $true
            PSDscAllowPlainTextPassword = $true
            
            RetryCount       = 10           
            RetryIntervalSec = 30

            SetupUserName     = $spSetupUserName
            SetupUserPassword = $spSetupUserPassword
            
            PassPhrase = $spPassPhrase
        }
    )
}

$configuration = Get-Command Install_SharePointFarm
Start-UpliftDSCConfiguration $configuration $config 

exit 0
