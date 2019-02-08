# fail on errors and include uplift helpers
$ErrorActionPreference = "Stop"

Import-Module Uplift.Core

Write-UpliftMessage "Optimizing SQL Server..."
Write-UpliftEnv

Configuration Optimize_SQL
{
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'

    Import-DscResource -ModuleName 'SqlServerDsc' -ModuleVersion "12.2.0.0" 

    Node localhost {

        SqlServerMemory SQLServerMaxMemory
        {
            ServerName      = $Node.ServerName
            InstanceName    = $Node.InstanceName

            DynamicAlloc    = $false

            MinMemory       = $Node.MinMemory
            MaxMemory       = $Node.MaxMemory
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

            ServerName    = Get-UpliftEnvVariable "UPLF_SQL_SERVER_NAME" "" (hostname)
            InstanceName  = Get-UpliftEnvVariable "UPLF_SQL_INSTANCE_NAME" "" "MSSQLSERVER"

            MinMemory    = Get-UpliftEnvVariable "UPLF_SQL_MIN_MEMORY" "" 1024
            MaxMemory    = Get-UpliftEnvVariable "UPLF_SQL_MAX_MEMORY" "" 4096
        }
    )
}

$configuration = Get-Command Optimize_SQL
Start-UpliftDSCConfiguration $configuration $config 

exit 0