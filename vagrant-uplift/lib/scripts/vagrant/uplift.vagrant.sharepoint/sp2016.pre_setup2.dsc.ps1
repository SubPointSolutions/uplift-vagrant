# fail on errors and include uplift helpers
$ErrorActionPreference = "Stop"

Import-Module Uplift.Core

# include shared helpers from uplift.vagrant.sharepoint handler
. "c:/windows/temp/uplift.vagrant.sharepoint/shared/sp.helpers.ps1"

Write-UpliftMessage "Running SharePoint pre-setup2 tuning..."
Write-UpliftEnv

Write-UpliftMessage "Running: Install-WindowsFeature Web-Server -IncludeAllSubFeature"
Install-WindowsFeature Web-Server -IncludeAllSubFeature

# Missed NET-WCF-HTTP-Activation45 in SharePoint 2016 images #55
# https://github.com/SubPointSolutions/uplift/issues/55
Write-UpliftMessage "Running: Install-WindowsFeature NET-WCF-HTTP-Activation45"
Install-WindowsFeature NET-WCF-HTTP-Activation45 | Out-Null

Configuration Install_SharePointFarmPreSetupTuning
{
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName SharePointDsc
    Import-DscResource -ModuleName xWebAdministration
    
    Node localhost {

        LocalConfigurationManager 
        {
            RebootNodeIfNeeded = $false
        }

        # ensuring that required services are up before running SharePoint farm creation
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

        WindowsFeature NETWCFHTTPActivation45
        {
            Ensure = "Present"
            Name   = "NET-WCF-HTTP-Activation45"
        }
     }
}

$config = @{
    AllNodes = @(
        @{
            NodeName = 'localhost'

            PSDscAllowDomainUser = $true
            PSDscAllowPlainTextPassword = $true
        }
    )
}

$configuration = Get-Command Install_SharePointFarmPreSetupTuning
Start-UpliftDSCConfiguration $configuration $config 

Write-UpliftMessage "Ensuring IIS services are up"
Invoke-UpliftIISReset

exit 0