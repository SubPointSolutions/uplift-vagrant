Describe 'SQL Server 2016 minimal configuration' {

    Context "SQL Server" {

        It 'MSSQL service is running' {
            (get-service MSSQLSERVER).Status | Should BeLike "Running"
        }

        It 'MSSQL AGENT service is running' {
            (get-service SQLSERVERAGENT).Status | Should BeLike "Running"
        }

    }

    Context "SQL Tools" {

        It 'ssms.exe is installed' {
            get-command ssms | Should BeLike "*ssms.exe*"
        }

    }
}
