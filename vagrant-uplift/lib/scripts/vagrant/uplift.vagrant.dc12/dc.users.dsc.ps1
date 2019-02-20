# fail on errors and include uplift helpers
$ErrorActionPreference = "Stop"

Import-Module Uplift.Core

Write-UpliftMessage "Installing new domain controller..."
Write-UpliftEnv

function WaitForAdServices($tries) {
    
    # Somehow Win2016 might stuck at "Applying computer settings"
    # that happens for several minutes, them all comes back
    # could be a feature setup after DC/Defender removal, could be DNS thing

    # so waiting for 5 minutes, and then fail
    $user = "vagrant"  

    # 10 sec timout
    $timeOut = 30000

    # 10 minutes (6 * 10 sec => 10 times)
    if($null -eq $tries) {
        $tries = 6 * 10
    }

    $current = 0;
    $hasError = $false

    do {

        try {
            Write-UpliftMessage "[$current/$tries] waiting for AD services to come online, resolving user: [$user]"
            $user = Get-ADUser "vagrant"  
            
            $hasError = $false

            Write-UpliftMessage "[$current/$tries] No error! Nice!"
        } catch {

            Write-UpliftMessage "Failed with $_"
            Write-UpliftMessage "Sleeping [$timeOut] milliseconds..."

            $current++;
            Start-Sleep -Milliseconds $timeOut
            $hasError = $true
        }

        if($hasError -eq $false) {
            break;
        }

        if($current -gt $tries) {
            break;
        }
    }
    while($hasError -eq $true)
}

$domainName =           Get-UpliftEnvVariable "UPLF_DC_DOMAIN_NAME"
$vagrantUserName =      Get-UpliftEnvVariable "UPLF_VAGRANT_USER_NAME"
$vagrantUserPassword =  Get-UpliftEnvVariable "UPLF_VAGRANT_USER_PASSWORD"
$domainUserName =       Get-UpliftEnvVariable "UPLF_DC_DOMAIN_ADMIN_NAME"
$domainUserPassword =   Get-UpliftEnvVariable "UPLF_DC_DOMAIN_ADMIN_PASSWORD"

# ensuring AD services are up and running
Write-UpliftMessage "Starting NTDS service..."
start-service NTDS 

Write-UpliftMessage "Starting ADWS service..."
start-service ADWS 

# wait until AD comes up after reboot and applying setting
Write-UpliftMessage "Waiting for host to apply setting and make AD available...";
WaitForAdServices

$securePassword     = ConvertTo-SecureString $domainUserPassword -AsPlainText -Force

$domainAdminCreds   = New-Object System.Management.Automation.PSCredential(
    $domainUserName, 
    $securePassword
)
$safeModeAdminCreds = $domainAdminCreds

$vagrantSecurePassword = ConvertTo-SecureString $vagrantUserPassword -AsPlainText -Force
$vagrantCreds          = New-Object System.Management.Automation.PSCredential(
    $vagrantUserName, 
    $vagrantSecurePassword
)

Configuration Configure_DomainUsers {

    Import-DscResource -ModuleName xActiveDirectory -ModuleVersion 2.17.0.0
    Import-DscResource -ModuleName xNetworking -ModuleVersion 5.5.0.0
    
    Node localhost
    {
        LocalConfigurationManager
        {
            ConfigurationMode = 'ApplyOnly'
            RebootNodeIfNeeded = $false
            RefreshMode = "Push"
        }

        xADUser DomainAdmin
        {
            DomainName = $Node.DomainName 
            DomainAdministratorCredential = $vagrantCreds 
            UserName = $domainUserName
            Password = $domainAdminCreds
            Ensure = "Present"
        }
    }
}

$config = @{
    AllNodes = @(
        @{
            NodeName = 'localhost'
            PSDscAllowPlainTextPassword = $true
            PSDscAllowDomainUser = $true
            RetryCount = 10           
            RetryIntervalSec = 30

            DomainName = $domainName.Split('.')[0]
        }
    )
}

$configuration = Get-Command Configure_DomainUsers
Start-UpliftDSCConfiguration $configuration $config 

# ensuring group memebership
Write-UpliftMessage "Ensuring group memberships..."
try {
    Write-UpliftMessage "[1/2] Ensuring group memberships..."

    Add-ADGroupMember 'Domain Admins' 'vagrant',' admin'
} catch {
    Write-UpliftMessage "[2/2] Ensuring group memberships..."
    
    # try twice to ensure the following random issue
    # Attempting to perform the InitializeDefaultDrives operation on the 'ActiveDirectory' provider failed

    Add-ADGroupMember 'Domain Admins' 'vagrant',' admin'
}

exit 0