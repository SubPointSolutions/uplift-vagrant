
function global:Import-UpAssembly {

    Param(
        [Parameter(Mandatory=$True)]
        [String]$assemblyName
    )

    $assembly = [System.Reflection.Assembly]::LoadWithPartialName($assemblyName)

    if ($null -eq $assembly) {
        $errorMessage = "Cannot load assembly by its name: $assemblyName"

        Write-UpliftMessage $errorMessage
        throw $errorMessage
    } else {
        $errorMessage = "Loaded assembly by name: $assemblyName"
    }
}

function global:Import-UpAssemblies {

    Param(
        [Parameter(Mandatory=$True)]
        [String[]]$assemblyNames
    )

    foreach($assemblyName in $assemblyNames) {
        Import-UpAssembly $assemblyName
    }
}

function global:Get-UpSPConfigDbDNS($majorVersion) {

    if($null -eq $majorVersion) {
        $majorVersion = "15"
    }

    $regPath = "HKLM:\SOFTWARE\Microsoft\Shared Tools\Web Server Extensions\$majorVersion.0\Secure\ConfigDB"
    $item = Get-ItemProperty  $regPath -ErrorAction SilentlyContinue

    if($null -eq $item) {
        return $null
    }

    return $item.dsn
}

function global:Invoke-UpSqlQuery($server, $query) {
    Write-UpliftMessage "Annoying SQL server [$server] with query [$query]"

    $connection = New-Object "System.Data.SqlClient.SqlConnection" `
                -ArgumentList  @("Server = $server; Database = master; Integrated Security = True;")


    $connection.Open()

    $sqlCommand = New-Object "System.Data.SqlClient.SqlCommand" -ArgumentList @($query, $connection);
    $sqlCommand.ExecuteNonQuery() | Out-Null

    $connection.Close()
}

function global:Invoke-UpSqlReaderQuery($server, $query) {
    Write-UpliftMessage "Annoying SQL server [$server] with query [$query]"

    $result = @()

    $connection = New-Object "System.Data.SqlClient.SqlConnection" `
                -ArgumentList  @("Server = $server; Database = master; Integrated Security = True;")


    #$sqlCommandText = $query;
    $connection.Open()

    $sqlCommand = New-Object "System.Data.SqlClient.SqlCommand" -ArgumentList @($query, $connection);
    $reader = $sqlCommand.ExecuteReader()

    while( $reader.Read() -eq $true) {
        $result += $reader.GetValue(0)
        #Write-UpliftMessage "Result: [$($reader.GetValue(0))]"
    }

    $connection.Close()

    return $result
}

function global:Remove-UpSqlDb($name) {
    $sqlCommandText = "DROP DATABASE $name";
    $sqlCommand = New-Object System.DateSqlCommand -arguments ($sqlCommandText, $connection);
    $sqlCommand.ExecuteNonQuery();
}

function global:Confirm-UpSPInstalled {
    # assuming SharePoint 2013 by default
    $configDbDns = Get-UpSPConfigDbDNS 15

    # checking if SharePoint 2016 is here
    if($null -eq $configDbDns) {
        $configDbDns = Get-UpSPConfigDbDNS 16
    }

    Write-UpliftMessage "Detected config Db DNS:[$configDbDns]"
    $isSharePointInstalled = ($null -ne $configDbDns)

    return $isSharePointInstalled
}

function global:Initialize-UpSPSqlServer {
    Param(
        [Parameter(Mandatory=$True)]
        [String]$spSqlServerName,

        [Parameter(Mandatory=$True)]
        [String]$spSqlDbPrefix
    )

    Write-UpliftMessage "Preparing SQL Server [$spSqlServerName] for SharePoint deployment. DBs prefix: $spSqlDbPrefix"

    # prepare SQL Server for SharePoint deployment
    $isSharePointInstalled = Confirm-UpSPInstalled

    if($isSharePointInstalled) {
        Write-UpliftMessage "Detected that SharePoint is already installed. No need to create Farm or Join to farm"
    } else {
        Remove-UpSPSqldatabases $spSqlServerName $spSqlDbPrefix
    }
}

function global:Remove-UpSPSqldatabases {

    Param(
        [Parameter(Mandatory=$True)]
        [String]$spSqlServerName,

        [Parameter(Mandatory=$True)]
        [String]$spSqlDbPrefix
    )

    Import-UpAssemblies @(
        "System.Data"
    )

    Write-UpliftMessage "`t - cleaning up SQL databases with prefix: $spSqlDbPrefix"

    $dbs = Invoke-UpSqlReaderQuery $spSqlServerName "select name from dbo.sysdatabases"

    foreach($dbName in $dbs) {
        if($dbName.ToLower().StartsWith($spSqlDbPrefix.ToLower()) -eq $true) {
            Invoke-UpSqlQuery $spSqlServerName "alter database [$dbName] set single_user with rollback immediate"
            Invoke-UpSqlQuery $spSqlServerName "drop database [$dbName]"
        }
    }
}