# fail on errors and include uplift helpers
$ErrorActionPreference = "Stop"

Import-Module Uplift.Core

# include shared helpers from uplift.vagrant.sharepoint handler
. "c:/windows/temp/uplift.vagrant.sharepoint/shared/sp.helpers.ps1"

Write-UpliftMessage "Creating new SharePoint Web Application..."
Write-UpliftEnv

$spSetupUserName     = Get-UpliftEnvVariable "UPLF_SP_SETUP_USER_NAME"
$spSetupUserPassword = Get-UpliftEnvVariable "UPLF_SP_SETUP_USER_PASSWORD"

$webAppPort =  Get-UpliftEnvVariable "UPLF_SP_WEB_APP_PORT"

# deploy SharePoint Web App
Configuration Install_SharePointWebApp
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName SharePointDsc -ModuleVersion "1.9.0.0"

    Node localhost {

        $ensureWebApp = 'Present'
        
        $setupUserName       = $Node.SetupUserName
        $setupUserPassword   = $Node.SetupUserPassword

        $secureSetupUserPassword = ConvertTo-SecureString $setupUserPassword -AsPlainText -Force
        $setupUserCreds          = New-Object System.Management.Automation.PSCredential($setupUserName, $secureSetupUserPassword)

        $SPSetupAccount              = $setupUserCreds
        $SPFarmAccount               = $setupUserCreds

        $SPServicePoolManagedAccount = $setupUserCreds
        $SPWebPoolManagedAccount     = $setupUserCreds

        # web app settings
        $deleteWebApp  = $Node.WebAppDelete
        if($deleteWebApp -eq $true) { $ensureWebApp = 'Absent' }

        $webAppUrl     = "http://" + $Node.MachineName

        $webAppPort    = $Node.WebAppPort
        if($null -eq $webAppPort) { $webAppPort = 80; }
    
        # minimal config to create web app
        SPManagedAccount WebAppPoolManagedAccount  
        {
            Ensure = 'Present'

            AccountName          = $setupUserCreds.UserName
            Account              = $setupUserCreds
            PsDscRunAsCredential = $setupUserCreds
        }

        # web app config
        SPWebApplication WebApp
        {
            Ensure = $ensureWebApp

            Name                   = "Intranet - $webAppPort"
            ApplicationPool        = "Intranet Web App"
            ApplicationPoolAccount = $setupUserCreds.UserName
            AllowAnonymous         = $false

            # https://github.com/PowerShell/SharePointDsc/issues/707
            AuthenticationMethod   = "NTLM"
            DatabaseName           = "Intraner_Content_$webAppPort"
            Url                    = $webAppUrl
            Port                   = $webAppPort
            PsDscRunAsCredential   = $setupUserCreds

            DependsOn              = "[SPManagedAccount]WebAppPoolManagedAccount"
        }

        # root site collection config
        if($ensureWebApp -eq 'Present') {
            # create root site collection if Present is set for the web app
            SPSite RootSite
            {
                Url                      = $webAppUrl + ":" + $webAppPort
                OwnerAlias               = ($setupUserCreds.UserName)
                Name                     = "Intranet Root Site"
                Template                 = "STS#0"
                PsDscRunAsCredential     = $setupUserCreds
                DependsOn                = "[SPWebApplication]WebApp"
            }
        }   
    }
}

$config = @{
    AllNodes = @(
        @{
            NodeName = 'localhost'
            PSDscAllowPlainTextPassword = $true

            RetryCount = 10           
            RetryIntervalSec = 30

            WebAppPort   = $webAppPort
            WebAppDelete = ($env:UPLF_SP_WEB_APP_DELETE -ne $null)

            MachineName = ($env:COMPUTERNAME)

            SetupUserName     = $spSetupUserName
            SetupUserPassword = $spSetupUserPassword   
        }
    )
}

$configuration = Get-Command Install_SharePointWebApp
Start-UpliftDSCConfiguration $configuration $config

exit 0
