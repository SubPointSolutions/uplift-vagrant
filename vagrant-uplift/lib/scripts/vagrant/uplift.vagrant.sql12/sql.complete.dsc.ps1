
Import-Module Uplift.Core

try {

    $exitCode = 0;

    do {
        Write-UpliftMessage "Executing CompleteImage action..."

        # SQL SERVER – How to Get List of SQL Server Instances Installed on a Machine?
        # https://blog.sqlauthority.com/2016/11/12/sql-server-get-list-sql-server-instances-installed-machine/
        $service = Get-Service | Where-Object{ $_.DisplayName -like "SQL Server (*" }
        $shoudComplete = ($null -eq $service)

        if($shoudComplete -eq $False) {
            Write-UpliftMessage "[+] server was clready completed!"
            break;
        } else {
            Write-UpliftMessage "[~] server needs completion"
        }

        $sqlDir = "C:\Program Files\Microsoft SQL Server\130\Setup Bootstrap\SQLServer2016\"

        $syAdmnUsers = """vagrant"""

        if((Get-CimInstance -Class Win32_ComputerSystem).PartOfDomain) {
            $domainName = [environment]::UserDomainName
            $syAdmnUsers += " ""$domainName\vagrant"""

            $dmName = (Get-CimInstance Win32_ComputerSystem).Domain.Split(".")[0]

            $syAdmnUsers += " ""$dmName\vagrant"""

            Write-UpliftMessage "[!] domain joined vm detected, WILL ADD $domainName\vagrant user as SQLSYSADMINACCOUNTS"
        } else {
            Write-UpliftMessage "[!] standalone vm detected, WILL NOT add domain vagrant user to SQLSYSADMINACCOUNTS"
        }

        Write-UpliftMessage "syAdmnUsers: $syAdmnUsers"

        $arguments = [string]::Join(" ", @(
            "/q",
            "/ACTION=CompleteImage",
            "/INSTANCENAME=MSSQLSERVER",
            "/INSTANCEID=MSSQLSERVER",
            "/SQLSVCACCOUNT=""vagrant"" ",
            "/SQLSVCPASSWORD=""vagrant"" ",
            "/SQLSYSADMINACCOUNTS=$syAdmnUsers ",
            "/AGTSVCACCOUNT=""NT AUTHORITY\Network Service"" ",
            "/IACCEPTSQLSERVERLICENSETERMS"
        ))

        Write-UpliftMessage "SQL DIR : $sqlDir"
        Write-UpliftMessage "SQL ARGS: $arguments"

        $pinfo = New-Object System.Diagnostics.ProcessStartInfo
        $pinfo.FileName = "$sqlDir/setup.exe"

        $pinfo.RedirectStandardError = $true
        $pinfo.RedirectStandardOutput = $true

        $pinfo.UseShellExecute = $false

        $pinfo.Arguments = $arguments

        $p = New-Object System.Diagnostics.Process

        $p.StartInfo = $pinfo

        Write-UpliftMessage "Started process....."
        $p.Start() | Out-Null

        Write-UpliftMessage "Waiting for exit..."
        $p.WaitForExit()

        Write-UpliftMessage "Finished running PrepareImage"

        #Write-UpliftMessage $p
        Write-UpliftMessage "Res ExitCode: $($p.ExitCode)"

        $res = $p.ExitCode
        $exitCode = $p.ExitCode

    } while($res -eq $null -or $res -eq -2068774911 )

    # completion
    # Res ExitCode: -2147467261
    # Parameter name: instanceName

    # -2061893563
    # The SQL Server service account login or password is not valid. Use SQL Server Configuration Manager to update the service account.
    # SQLSVCACCOUNT / SQLSVCPASSWORD are wrong

    # 2068774911
    # There was an error generating the XML document.
    # (01) 2018-12-29 14:55:25 Slp: Error: Action "Microsoft.SqlServer.Configuration.SetupExtension.FinalCalculateSettingsAction" threw an exception during execution.
    # (01) 2018-12-29 14:55:25 Slp: Microsoft.SqlServer.Setup.Chainer.Workflow.ActionExecutionException: There was an error generating the XML document. ---> Microsoft.SqlServer.Chainer.Infrastructure.ChainerInfrastructureException: There was an error generating the XML document. ---> System.InvalidOperationException: There was an error generating the XML document. ---> System.Security.Cryptography.CryptographicException: Access is denied.

    # mostlikely, we need to wait until TrustedInstaller process is done
    # post-sysprep or start action
    # then run complete action again

    # 2068774911 - !!! finally, tasks shuld be run in elevated mode!!!!

    # -2068643838
    # conflict of re-installing
    # mostlikely, we already run complete action

    # -2067919934
    # someting else is being installed! like, othe MIS/MSU or MSSQL installer
    # also, reboot might be requred
    # Microsoft.SqlServer.Setup.Chainer.Workflow.ActionExecutionException: A computer restart is required. You must restart this computer before installing SQL Server

    # -2067529717
    # ????


    # ---


    # Res ExitCode: 0 - all good

    # Res ExitCode: -2067529717 - process already running

    # Res ExitCode: -2022834173 - updates cannot connect to remote server
    # Setup encountered a failure while running job UpdateResult.
    # mostlikely, case we disabled them via registry

    # Error result: -2067921930
    # mostlikely, This computer does not have the Microsoft .NET Framework 3.5 Service Pack 1 installed.
    # If the operating system is Windows Server 2008, download and install Microsoft .NET Framework 3.5 SP1 from http://www.microsoft.com/download/en/details.aspx?displaylang=en&id=22
    # https://social.msdn.microsoft.com/Forums/en-US/8db6ff15-b5bc-4e3a-ab33-43e26ffab925/net-35-in-a-container-aiming-to-install-sql-server

    # logs under
    # C:\Program Files\Microsoft SQL Server\120\Setup Bootstrap\Log
    # https://www.buyplm.com/install-guide/pdxpert-plm-software-installation-advanced-server-sql-log-files.aspx

    # C:\Program Files\Microsoft SQL Server\130\Setup Bootstrap\Log

    # post setup
    if($exitCode -eq 0) {

        # start SQL server agent service
        Configuration SqlDSC
        {
            Import-DscResource -ModuleName PSDesiredStateConfiguration

            Node localhost {

                Service MSSQLSERVER {
                    Ensure = "Present"
                    Name = "MSSQLSERVER"
                    StartupType = "Automatic"
                    State = "Running"
                }

                Service SQLSERVERAGENT {
                    Ensure = "Present"
                    Name = "SQLSERVERAGENT"
                    StartupType = "Automatic"
                    State = "Running"
                }

            }
        }

        $configuration = Get-Command SqlDSC
        Start-UpliftDSCConfiguration $configuration -ExpectInDesiredState $True
    }

    # already installed
    # if ($p.ExitCode -eq -2068643838) {
    #     exit 0
    # }

    exit $exitCode
} catch {

    Write-UpliftMessage "ERROR!"
    Write-UpliftMessage $_

    exit 1
}

exit 1