# fail on errors and include uplift helpers
$ErrorActionPreference = "Stop"

Import-Module Uplift.Core

Write-UpliftMessage "Installing primary controller..."
Write-UpliftEnv

$domainName          =  Get-UpliftEnvVariable "UPLF_DC_DOMAIN_NAME"
$domainAdminName     =  Get-UpliftEnvVariable "UPLF_DC_DOMAIN_ADMIN_NAME"
$domainAdminPassword =  Get-UpliftEnvVariable "UPLF_DC_DOMAIN_ADMIN_PASSWORD"

$isPartOfDomain = (Get-CimInstance -Class Win32_ComputerSystem).PartOfDomain

if($isPartOfDomain -eq $True) {
    Write-UpliftMessage "This computer is already part of domain. No domain join or reboot is required"
    exit 0
}

Write-UpliftMessage "Fixing DC promo settings..."
Set-UpliftDCPromoSettings $domainAdminPassword

Configuration Install_DomainController {

    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
    Import-DscResource -ModuleName 'xActiveDirectory'
    Import-DscResource -ModuleName 'xNetworking'
    
    Node localhost
    {
        $domainName           = $Node.DomainName
        $domainAdminName      = $Node.DomainAdminName
        $domainAdminPassword  = $Node.DomainAdminPassword

        $securePassword   = ConvertTo-SecureString $domainAdminPassword -AsPlainText -Force
        $domainAdminCreds = New-Object System.Management.Automation.PSCredential(
            $domainAdminName, 
            $securePassword
        )

        $safeModeAdminCreds = $domainAdminCreds

        LocalConfigurationManager
        {
            ConfigurationMode = 'ApplyOnly'
            RebootNodeIfNeeded = $false
            RefreshMode = "Push"
        }

        WindowsFeature DNS
        {
            Ensure = "Present"
            Name   = "DNS"
        }

        xDnsServerAddress DnsServerAddress
        {
            Address        = '127.0.0.1'
            InterfaceAlias = 'Ethernet'
            AddressFamily  = 'IPv4'
            DependsOn      = "[WindowsFeature]DNS"
        }

        WindowsFeature ADDSInstall
        {
            Ensure = "Present"
            Name   = "AD-Domain-Services"
        }

        WindowsFeature ADDSRSAT
        {
            Ensure = "Present"
            Name   = "RSAT-ADDS-Tools"
        }

        WindowsFeature RSAT
        {
            Ensure = "Present"
            Name   = "RSAT"
        }

        xADDomain PrimaryDomainController
        {
            DomainName = $domainName

            # Windows 2016 fix
            # http://vcloud-lab.com/entries/active-directory/powershell-dsc-xactivedirectory-error-a-netbios-domain-name-must-be-specified-
            DomainNetBIOSName = $domainName.Split('.')[0]
            
            DomainAdministratorCredential = $domainAdminCreds
            SafemodeAdministratorPassword = $safeModeAdminCreds
            
            DatabasePath = "C:\NTDS"
            LogPath      = "C:\NTDS"
            SysvolPath   = "C:\SYSVOL"
            
            DependsOn = @(
                "[WindowsFeature]ADDSInstall", 
                "[WindowsFeature]RSAT", 
                "[WindowsFeature]ADDSRSAT", 
                "[xDnsServerAddress]DnsServerAddress"
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
            
            RetryCount       = 10           
            RetryIntervalSec = 30

            DomainName           = $domainName
            DomainAdminName      = $domainAdminName
            DomainAdminPassword  = $domainAdminPassword
        }
    )
}

$configuration = Get-Command Install_DomainController
Start-UpliftDSCConfiguration $configuration $config 

exit 0
