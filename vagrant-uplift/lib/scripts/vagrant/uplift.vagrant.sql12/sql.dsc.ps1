# fail on errors and include uplift helpers
$ErrorActionPreference = "Stop"

Import-Module Uplift.Core

Write-UpliftMessage "Installing SQL Server..."
Write-UpliftEnv

$binSourcePath       = Get-UpliftEnvVariable "UPLF_SQL_BIN_PATH"
$instanceName        = Get-UpliftEnvVariable "UPLF_SQL_INSTANCE_NAME"
$instanceFeatures    = Get-UpliftEnvVariable "UPLF_SQL_INSTANCE_FEATURES"
$sqlSysAdminAccounts = (Get-UpliftEnvVariable "UPLF_SQL_SYS_ADMIN_ACCOUNTS").Split(',')

Configuration Install_SQL
{
    Import-DscResource -ModuleName 'xSQLServer' -ModuleVersion "9.1.0.0" 
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'

    Node localhost {

        LocalConfigurationManager 
        {
            RebootNodeIfNeeded = $false
        }

        WindowsFeature "NET-Framework-Core" 
        {
            Ensure = "Present"
            Name   = "NET-Framework-Core"
        }

        xSqlServerSetup "SQL"
        {
            DependsOn           = "[WindowsFeature]NET-Framework-Core"
            SourcePath          = $Node.BinSourcePath
            InstanceName        = $Node.InstanceName
            Features            = $Node.InstanceFeatures
            SQLSysAdminAccounts = $Node.SqlSysAdminAccounts
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

            BinSourcePath       = $binSourcePath

            InstanceName        = $instanceName
            InstanceFeatures    = $instanceFeatures
            
            SqlSysAdminAccounts = $sqlSysAdminAccounts
        }
    )
}

$configuration = Get-Command Install_SQL
Start-UpliftDSCConfiguration $configuration $config 

exit 0