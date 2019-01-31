# fail on errors and include uplift helpers
$ErrorActionPreference = "Stop"

Import-Module Uplift.Core

Write-UpliftMessage "Testing SQL Server setup..."
Write-UpliftEnv

$instanceFeatures = Get-UpliftEnvVariable "UPLF_SQL_INSTANCE_FEATURES"

# such as SQLENGINE,SSMS,ADV_SSMS
$instanceFeaturesArray = $instanceFeatures.Split(',')

$checkSQLEngine = $instanceFeaturesArray.Contains("SQLENGINE") -eq $true
$checkSSMS      = $instanceFeaturesArray.Contains("SSMS") -eq $true

Describe 'SQL Server 2012 minimal configuration' {

    # always test SQL server itself
    Context "SQL Server" {

         It 'MSSQL service is running' {
            (get-service MSSQLSERVER).Status | Should BeLike "Running"
         }

         It 'MSSQL AGENT service is running' {
            (get-service SQLSERVERAGENT).Status | Should BeLike "Running"
        }

     }

    # only if
    Context "SQL Tools" {

        It 'ssms.exe is installed' {
            if($checkSSMS -eq $true)  {
                 get-command ssms | Should BeLike "*ssms.exe*"
            } else {
                Write-UpliftMessage "Skipping ssms.exe check"
            }
        }

    }

}
