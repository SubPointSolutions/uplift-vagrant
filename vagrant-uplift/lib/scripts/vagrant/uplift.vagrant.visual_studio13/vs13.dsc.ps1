# fail on errors and include uplift helpers
$ErrorActionPreference = "Stop"

Import-Module Uplift.Core

Write-UpliftMessage "Installing Visual Studio..."
Write-UpliftEnv

$execPath = Get-UpliftEnvVariable "UPLF_VS_EXECUTABLE_PATH"
$productName = Get-UpliftEnvVariable "UPLF_VS_PRODUCT_NAME"
$deploymentFilePath = Get-UpliftEnvVariable "UPLF_VS_ADMIN_DEPLOYMENT_FILE_PATH"

$domainUserName = Get-UpliftEnvVariable "UPLF_VS_DOMAIN_USER_NAME"
$domainUserPassword = Get-UpliftEnvVariable "UPLF_VS_DOMAIN_USER_PASSWORD"

# check if $execPath exists
# the reason is that different VS editions have different EXE files:
# - vs_ultimate.exe
# - vs_enterprise.exe
# if not, them look for .exe file at the top folder in $execPath
$execPath = Find-UpliftFileInPath $execPath
Write-UpliftMessage "Using VS install file: $execPath"

Configuration Install_VS2013 {

    Import-DSCResource -Name MS_xVisualStudio  

    Node localhost {

        $securePassword = ConvertTo-SecureString $Node.DomainUserPassword -AsPlainText -Force
        $domainUserCreds = New-Object System.Management.Automation.PSCredential($Node.DomainUserName, $securePassword)

        MS_xVisualStudio VistualStudio
        {
            Ensure = "Present"    
            PsDscRunAsCredential = $domainUserCreds

            ExecutablePath = $Node.ExecutablePath 
            ProductName =  $Node.ProductName  
            AdminDeploymentFile =  $Node.AdminDeploymentFile  
        } 
    }
}

$config = @{
    AllNodes = @(
        @{
            NodeName = 'localhost'
            
            PSDscAllowDomainUser = $true
            PSDscAllowPlainTextPassword = $true

            RetryCount = 10           
            RetryIntervalSec = 30

            DomainUserName = $domainUserName
            DomainUserPassword = $domainUserPassword

            ExecutablePath = $execPath
            ProductName = $productName
            AdminDeploymentFile = $deploymentFilePath
        }
    )
}

$configuration = Get-Command Install_VS2013
Start-UpliftDSCConfiguration $configuration $config 

exit 0