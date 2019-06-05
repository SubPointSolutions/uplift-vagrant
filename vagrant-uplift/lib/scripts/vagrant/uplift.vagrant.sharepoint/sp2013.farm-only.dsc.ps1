# fail on errors and include uplift helpers
$ErrorActionPreference = "Stop"

Import-Module Uplift.Core

# include shared helpers from uplift.vagrant.sharepoint handler
. "c:/windows/temp/uplift.vagrant.sharepoint/shared/sp.helpers.ps1"

Write-UpliftMessage "Creating new SharePoint farm only"
Write-UpliftEnv

$spSqlServerName     = Get-UpliftEnvVariable "UPLF_SP_FARM_SQL_SERVER_HOST_NAME"
$spSqlDbPrefix       = Get-UpliftEnvVariable "UPLF_SP_FARM_SQL_DB_PREFIX"

$spPassPhrase        = Get-UpliftEnvVariable "UPLF_SP_FARM_PASSPHRASE"

$spSetupUserName     = Get-UpliftEnvVariable "UPLF_SP_SETUP_USER_NAME"
$spSetupUserPassword = Get-UpliftEnvVariable "UPLF_SP_SETUP_USER_PASSWORD"

function Get-SharePointLocalFarm() {

    $result = $null

    try {

        if ($null -eq (Get-PSSnapin -Name Microsoft.SharePoint.PowerShell -ErrorAction SilentlyContinue))
        {
            Add-PSSnapin Microsoft.SharePoint.PowerShell
        }

        $result = Get-SPFarm -ErrorAction SilentlyContinue
        Write-UpliftMessage "Local farm: $result"

    } catch {
        Write-UpliftMessage "Error while detecting local SharePoint install"
        Write-UpliftMessage $_

        $result = $null
    }

    return $result
}

Write-UpliftMessage "Detecting existing SharePoint farm install..."
$hasFarm = ($null -ne (Get-SharePointLocalFarm))

Write-UpliftMessage " - hasFarm: $hasFarm"

if($hasFarm -eq $False) {
    Write-UpliftMessage "No existing farm found, cleaning up SQL server dbs: $spSqlServerName $spSqlDbPrefix"
    # prepare SQL server for SharePoint deployment
    Initialize-UpSPSqlServer $spSqlServerName $spSqlDbPrefix

} else {
    Write-UpliftMessage "Detected local SharePoint farm. No SQL server clean up is needed"
}

# deploy SharePoint
Configuration Install_SharePointFarm
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName SharePointDsc -ModuleVersion "1.9.0.0"

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
            Ensure                   = "Present"
            
            #ServerRole               = "SingleServerFarm"
            
            DatabaseServer           = $spSqlServerName
            FarmConfigDatabaseName   = ($spSqlDbPrefix +  "_Config")
            Passphrase               = $passPhraseCreds
            FarmAccount              = $SPFarmAccount
            PsDscRunAsCredential     = $SPSetupAccount
            AdminContentDatabaseName = ($spSqlDbPrefix +  "_AdminContent")
            RunCentralAdmin          = $true
            
            DependsOn                = "[Service]IISADMIN"
        }

        # default accounts
        # SPManagedAccount ServicePoolManagedAccount
        # {
        #     AccountName          = $SPServicePoolManagedAccount.UserName
        #     Account              = $SPServicePoolManagedAccount
        #     PsDscRunAsCredential = $SPSetupAccount
        #     DependsOn            = "[SPFarm]CreateSPFarm"
        # }
        # SPManagedAccount WebPoolManagedAccount
        # {
        #     AccountName          = $SPWebPoolManagedAccount.UserName
        #     Account              = $SPWebPoolManagedAccount
        #     PsDscRunAsCredential = $SPSetupAccount
        #     DependsOn            = "[SPFarm]CreateSPFarm"
        # }

        # default services
        # SPUsageApplication UsageApplication
        # {
        #     Name                  = "Usage Service Application"
        #     DatabaseName          = ($spSqlDbPrefix + "_SP_Usage" )
        #     UsageLogCutTime       = 5
        #     UsageLogLocation      = "C:\UsageLogs"
        #     UsageLogMaxFileSizeKB = 1024
        #     PsDscRunAsCredential  = $SPSetupAccount
        #     DependsOn             = "[SPFarm]CreateSPFarm"
        # }

        # SPStateServiceApp StateServiceApp
        # {
        #     Name                 = "State Service Application"
        #     DatabaseName         = ($spSqlDbPrefix + "_SP_State")
        #     PsDscRunAsCredential = $SPSetupAccount
        #     DependsOn            = "[SPFarm]CreateSPFarm"
        # }

        # SPServiceInstance ClaimsToWindowsTokenServiceInstance
        # {
        #     Name                 = "Claims to Windows Token Service"
        #     Ensure               = "Present"
        #     PsDscRunAsCredential = $SPSetupAccount
        #     DependsOn            = "[SPFarm]CreateSPFarm"
        # }
    }
}

$config = @{
    AllNodes = @(
        @{
            NodeName = 'localhost'

            PSDscAllowDomainUser        = $true
            PSDscAllowPlainTextPassword = $true

            SetupUserName = $spSetupUserName
            SetupUserPassword = $spSetupUserPassword

            PassPhrase = $spPassPhrase
        }
    )
}

$configuration = Get-Command Install_SharePointFarm
Start-UpliftDSCConfiguration $configuration $config

exit 0
