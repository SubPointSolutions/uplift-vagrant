# fail on errors and include uplift helpers
$ErrorActionPreference = "Stop"

Import-Module Uplift.Core

Write-UpliftMessage "Running windows SOE config..."
Write-UpliftEnv

$computerName = $env:computername

$domainName =               Get-UpliftEnvVariable "UPLF_DC_DOMAIN_NAME"
$domainJoinUserName =       Get-UpliftEnvVariable "UPLF_DC_JOIN_USER_NAME"
$domainJoinUserPassword =   Get-UpliftEnvVariable "UPLF_DC_JOIN_USER_PASSWORD"
$domainIpAddr =             Get-UpliftEnvVariable "UPLF_DC_DOMAIN_HOST_IP"

Write-UpliftMessage "Joining computer [$computerName] to domain [$domainName] under user [$domainJoinUserName]"
Write-UpliftMessage "Running as :[$($env:UserDomain)/$($env:UserName)] on $($env:ComputerName)"

$securePassword = ConvertTo-SecureString $domainJoinUserPassword -AsPlainText -Force
$domainJoinUserCreds = New-Object System.Management.Automation.PSCredential($domainJoinUserName, $securePassword)

# helpers
Write-UpliftMessage "Importing ActiveDirectory module..."

Function Install-ADModule {
    [CmdletBinding()]
    Param(
        [switch]$Test = $false
    )
    
    If ((Get-CimInstance Win32_OperatingSystem).Caption -like "*Server*") {
        Write-UpliftMessage 'This system is running Windows Server'

    }else{
        If ((Get-CimInstance Win32_OperatingSystem).Caption -like "*Windows 10*") {
            Write-UpliftMessage 'This system is running Windows 10'
        } Else {
            Write-UpliftMessage 'This system is not running Windows 10 nor Server'
            Write-UpliftMessage 'Trying to install RSAT using choco'
            choco install -y rsat.featurepack --limit-output --acceptlicense --no-progress;
            Confirm-UpliftExitCode $LASTEXITCODE "Cannot install rsat.featurepack"
        }
    }
    

    If ((Get-HotFix -Id KB2693643 -ErrorAction SilentlyContinue) -or ([System.Environment]::OsVersion.Version.Build -ge 18362)) {

        Write-UpliftMessage 'RSAT for Windows 10 is already installed'

    } Else {

        Write-UpliftMessage 'Downloading RSAT for Windows 10'

        If ((Get-CimInstance Win32_ComputerSystem).SystemType -like "x64*") {
            $dl = 'WindowsTH-KB2693643-x64.msu'
        } Else {
            $dl = 'WindowsTH-KB2693643-x86.msu'
        }
        Write-UpliftMessage "Hotfix file is $dl"

        Write-UpliftMessage "$(Get-Date)"
        #Download file sample
        #https://gallery.technet.microsoft.com/scriptcenter/files-from-websites-4a181ff3
        $BaseURL = 'https://download.microsoft.com/download/1/D/8/1D8B5022-5477-4B9A-8104-6A71FF9D98AB/'
        $URL = $BaseURL + $dl
        $Destination = Join-Path -Path $HOME -ChildPath "Downloads\$dl"
        $WebClient = New-Object System.Net.WebClient
        $WebClient.DownloadFile($URL,$Destination)
        $WebClient.Dispose()

        Write-UpliftMessage 'Installing RSAT for Windows 10'
        Write-UpliftMessage "$(Get-Date)"
        # http://stackoverflow.com/questions/21112244/apply-service-packs-msu-file-update-using-powershell-scripts-on-local-server
        wusa.exe $Destination /quiet /norestart /log:$home\Documents\RSAT.log

        # wusa.exe returns immediately. Loop until install complete.
        do {
            Write-UpliftMessage "." -NoNewline
            Start-Sleep -Seconds 3
        } until (Get-HotFix -Id KB2693643 -ErrorAction SilentlyContinue)
        Write-UpliftMessage "."
        Write-UpliftMessage "$(Get-Date)"
    }

    # The latest versions of the RSAT automatically enable all RSAT features
    If ((Get-WindowsOptionalFeature -Online -FeatureName `
        RSATClient-Roles-AD-Powershell -ErrorAction SilentlyContinue).State `
        -eq 'Enabled') {

        Write-UpliftMessage 'RSAT AD PowerShell already enabled'

    } Else {

        Write-UpliftMessage 'Enabling RSAT AD PowerShell'

        if ([System.Environment]::OsVersion.Version.Build -ge 18362) {
            Get-WindowsCapability -Online |
                Where-Object Name -Match 'Rsat.ActiveDirectory'|
                    ForEach-Object -Process {Add-WindowsCapability -Online -Name $PSItem.Name}
        }else{
            Enable-WindowsOptionalFeature -Online -FeatureName RSATClient-Roles-AD-Powershell
        }
        

    }


    Write-UpliftMessage 'ActiveDirectory PowerShell module install complete'
    Write-UpliftMessage 'Importing ActiveDirectory module'
    Import-Module ActiveDirectory
    
    # Verify
    If ($Test) {
        Write-UpliftMessage 'Validating AD PowerShell install'
        if (Get-Module -ListAvailable | Where-Object {$_.Name -eq 'ActiveDirectory'}){
            Write-UpliftMessage 'Success AD PowerShell installed'
        }else{
            Write-UpliftMessage 'Failed AD PowerShell did not install'
        }
        
    }
}

Install-ADModule -Test


function Helper-RemoveADComputer
{
    Param(
        [Parameter(Mandatory=$True)]
        $computerName,
        
        [Parameter(Mandatory=$True)]
        $domainJoinUserCreds,

        [Parameter(Mandatory=$True)]
        $domainIpAddr 
    )

    $computer = $null

    

    try {
        Write-UpliftMessage "Fetching computer from Active Directory: $computerName"

        $computer = get-adcomputer $computerName `
                        -ErrorAction SilentlyContinue `
                        -Credential $domainJoinUserCreds `
                        -Server $domainIpAddr
    } catch {

        Write-UpliftMessage "There was an error while fetching computer from Active Directory:[$computerName]"
        Write-UpliftMessage "Mostlikely, computer $computerName has never been added to Active Directory yet"

        Write-UpliftMessage $_
        Write-UpliftMessage $_.Exception

        $computer = $null
    }

    if($null -ne $computer ) {
        Write-UpliftMessage "Removing computer from Active Directory: $computerName"
        
        Remove-ADComputer -identity $computerName `
                            -Confirm:$false  `
                            -Credential $domainJoinUserCreds `
                            -Server $domainIpAddr

        Write-UpliftMessage "Removed computer from Active Directory: $computerName"

    } else {
        Write-UpliftMessage "No need to remove computer $computerName from Active Directory"
    }
}

Write-UpliftMessage "Joining current computer to domain..."

if((Get-CimInstance -Class Win32_ComputerSystem).PartOfDomain) {
    Write-UpliftMessage "This computer, $computerName, is already part of domain. No domain join or reboot is required"
}
else {

    Write-UpliftMessage "ipconfig /flushdns"
    ipconfig /flushdns 

    Write-UpliftMessage "pinging dc: $domainIpAddr"
    ping $domainIpAddr

    # TODO, add error handling if dc isn't pingable

    Write-UpliftMessage "Deleting old computer from the domain..."
    Helper-RemoveADComputer $computerName $domainJoinUserCreds $domainIpAddr

    Write-UpliftMessage "Joining computer to the domain..."

    try {
        if($computerName -ne $env:computername) {
            Write-UpliftMessage "Joining computer with name [$($env:computername)] as [$computerName] to domain:[$domainName]"

            Add-Computer -DomainName $domainName `
                        -NewName $computerName `
                        -Credential $domainJoinUserCreds
        } else {
            Write-UpliftMessage "Joining computer [$computerName] to domain [$domainName]"
            
            Add-Computer -DomainName $domainName `
                        -Credential $domainJoinUserCreds
        } 
    } catch {
        $errorMessage = $_.ToString()

        Write-UpliftMessage "Error while adding ccomputer [$computerName] to domain [$domainName]"
        Write-UpliftMessage $errorMessage 
        
        if($errorMessage.Contains("0x21c4") -eq $true) {
            Write-UpliftMessage "!!! - Mostlikely, this image wasn't sysprep-ed: DC and client VMs have the same SID and won't even be joined. Run provision with syspreped image to join VMs to domain."
        }

        throw $_
    }

    Write-UpliftMessage "Joining completed, a reboot is required"
}

exit 0
