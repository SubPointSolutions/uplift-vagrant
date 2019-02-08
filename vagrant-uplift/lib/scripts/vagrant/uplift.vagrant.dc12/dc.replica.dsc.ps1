# fail on errors and include uplift helpers
$ErrorActionPreference = "Stop"

Import-Module Uplift.Core

Write-UpliftMessage "Installing replica domain controller..."
Write-UpliftEnv

$domainName =           Get-UpliftEnvVariable "UPLF_DC_DOMAIN_NAME"
$domainAdminName =      Get-UpliftEnvVariable "UPLF_DC_DOMAIN_ADMIN_NAME"
$domainAdminPassword =  Get-UpliftEnvVariable "UPLF_DC_DOMAIN_ADMIN_PASSWORD"

Write-UpliftMessage "Fixing DC promo settings..."
Set-UpliftDCPromoSettings $domainAdminPassword

# disable IP6 to ensure replica controller can be promoted
Write-UpliftMessage "Disabling IP6 interfaces..."
Disable-UpliftIP6Interface

Configuration Install_ReplicaDomainController {

    Import-DscResource -ModuleName xActiveDirectory -ModuleVersion 2.17.0.0
    Import-DscResource -ModuleName xNetworking -ModuleVersion 5.5.0.0
    
    Node localhost
    {
        $domainName = $Node.DomainName
        $domainAdminName = $Node.DomainAdminName
        $domainAdminPassword = $Node.DomainAdminPassword

        $securePassword = ConvertTo-SecureString $domainAdminPassword -AsPlainText -Force
        
        $domainAdminCreds = New-Object System.Management.Automation.PSCredential($domainAdminName, $securePassword)
        $safeModeAdminCreds = $domainAdminCreds
        $dnsDelegationCreds = $domainAdminCreds

        LocalConfigurationManager
        {
            ConfigurationMode = 'ApplyOnly'
            RebootNodeIfNeeded = $false
            RefreshMode = "Push"
        }

        # WindowsFeature DNS
        # {
        #     Ensure = "Present"
        #     Name   = "DNS"
        # }

        # xDnsServerAddress DnsServerAddress
        # {
        #     Address        = '127.0.0.1'
        #     InterfaceAlias = 'Ethernet'
        #     AddressFamily  = 'IPv4'
        #     DependsOn      = "[WindowsFeature]DNS"
        # }

        WindowsFeature ADDSInstall
        {
            Ensure = "Present"
            Name   = "AD-Domain-Services"
        }

        # WindowsFeature ADDSRSAT
        # {
        #     Ensure = "Present"
        #     Name   = "RSAT-ADDS-Tools"
        # }

        # WindowsFeature RSAT
        # {
        #     Ensure = "Present"
        #     Name   = "RSAT"
        # }

        xADDomainController ReplicaDomainController
        {
            DomainName = $domainName
            # win16 fix
            # http://vcloud-lab.com/entries/active-directory/powershell-dsc-xactivedirectory-error-a-netbios-domain-name-must-be-specified-
            # DomainNetBIOSName = $domainName.Split('.')[0]
            
            DomainAdministratorCredential = $domainAdminCreds
            SafemodeAdministratorPassword = $safeModeAdminCreds
            
            DependsOn = @(
                "[WindowsFeature]ADDSInstall" 
                # "[WindowsFeature]RSAT", 
                # "[WindowsFeature]ADDSRSAT",
                #"[xDnsServerAddress]DnsServerAddress"
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

$configuration = Get-Command Install_ReplicaDomainController
Start-UpliftDSCConfiguration $configuration $config 

exit 0
