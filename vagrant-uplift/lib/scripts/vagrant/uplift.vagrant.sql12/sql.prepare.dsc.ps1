
# https://docs.microsoft.com/en-us/sql/database-engine/install-windows/considerations-for-installing-sql-server-using-sysprep?view=sql-server-2017
# https://docs.microsoft.com/en-us/sql/database-engine/install-windows/install-sql-server-using-sysprep?view=sql-server-2017
# Setup.exe /q /ACTION=PrepareImage l /FEATURES=SQLEngine /InstanceID =<MYINST> /IACCEPTSQLSERVERLICENSETERMS

# SqlSetup: Add support for sysprepped SQL Server. #2
# https://github.com/PowerShell/SqlServerDsc/issues/2#event-1399718765

# fail on errors and include uplift helpers
$ErrorActionPreference = "Stop"

Import-Module Uplift.Core

Write-UpliftMessage "Installing SQL Server..."
Write-UpliftEnv

$binSourcePath = Get-UpliftEnvVariable "UPLF_SQL_BIN_PATH"
$instanceName  = Get-UpliftEnvVariable "UPLF_SQL_INSTANCE_NAME"
$instanceFeatures = Get-UpliftEnvVariable "UPLF_SQL_INSTANCE_FEATURES"

Write-UpliftMessage "Executing prepare DSC..."
Configuration Prepare_SQL
{
    Import-DscResource -ModuleName xSQLServer -ModuleVersion "9.1.0.0" 

    Node localhost {

        LocalConfigurationManager
        {
            RebootNodeIfNeeded = $false
        }

        WindowsFeature "NET-Framework-Core"
        {
            Ensure="Present"
            Name = "NET-Framework-Core"
        }
    }
}

$configuration = Get-Command Prepare_SQL
Start-UpliftDSCConfiguration $configuration $config

# Setup.exe /q /ACTION=PrepareImage /FEATURES=SQLEngine /InstanceID =<MYINST> /IACCEPTSQLSERVERLICENSETERMS
$execPath       = "$binSourcePath/setup.exe"
$execArguments  = "/qs /ACTION=PrepareImage /FEATURES=$instanceFeatures /InstanceID=$instanceName /IACCEPTSQLSERVERLICENSETERMS"

Write-UpliftMessage "Executing prepare action..."
Write-UpliftMessage " - execPath:      $execPath"
Write-UpliftMessage " - execArguments: $execArguments"

$process = Start-Process -FilePath $execPath `
            -ArgumentList "$execArguments" `
            -Wait `
            -PassThru

$exitCode = $process.ExitCode;
Write-Host "Exit code was: $exitCode"

exit $exitCode