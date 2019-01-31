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
Import-Module ActiveDirectory

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