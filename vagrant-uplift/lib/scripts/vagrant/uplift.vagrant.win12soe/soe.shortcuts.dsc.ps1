# fail on errors and include uplift helpers
$ErrorActionPreference = "Stop"

Import-Module Uplift.Core

Write-UpliftMessage "Running DSC Configure_Shortcuts..."

Configuration SOE_Shortcuts
{
    Import-DscResource -ModuleName DSCR_Shortcut -ModuleVersion '1.3.7'

    $desktopPath = [Environment]::GetFolderPath("CommonDesktopDirectory")

    # common setup - IE, PowerShell ISE, PS6
    cShortcut IE_Desktop
    {
        Path      = "$desktopPath\IE.lnk"
        Target    = "C:\Program Files\Internet Explorer\iexplore.exe"
    }

    cShortcut PowerShell_ISE_Desktop
    {
        Path      = "$desktopPath\PowerShell ISE.lnk"
        Target    = "%windir%\system32\WindowsPowerShell\v1.0\PowerShell_ISE.exe"
        WorkingDirectory = '%HOMEDRIVE%%HOMEPATH%'
        Description  = "IE IE"
    
    }

    cShortcut PowerShell_6_Desktop
    {
        Path      = "$desktopPath\PowerShell6.lnk"
        Target    = "C:\Program Files\PowerShell\6\pwsh.exe"
        Arguments = "-WorkingDirectory ~"
    }

    # system utils
    cShortcut ADUsers
    {
        Path      = "$desktopPath\AD Users and Computers.lnk"
        Target    = "%SystemRoot%\system32\dsa.msc"
        WorkingDirectory = '%HOMEDRIVE%%HOMEPATH%'
    }

    cShortcut ServerManager
    {
        Path      = "$desktopPath\Server Manager.lnk"
        Target    = "%windir%\system32\ServerManager.exe"
        WorkingDirectory = '%windir%\system32'
    }

    cShortcut Services
    {
        Path      = "$desktopPath\Services.lnk"
        Target    = "%windir%\system32\services.msc"
        WorkingDirectory = '%HOMEDRIVE%%HOMEPATH%'
    }

    # VS2017 exists?
    $vs17Path = "C:\Program Files (x86)\Microsoft Visual Studio\2017\Enterprise\Common7\IDE\devenv.exe"
    if( (Test-Path $vs17Path) -eq $True) {
        cShortcut VS2017
        {
            Path      = "$desktopPath\VS 2017.lnk"
            Target    = "$vs17Path"
            WorkingDirectory = "C:\Program Files (x86)\Microsoft Visual Studio\2017\Enterprise\Common7\IDE\"
        }
    }

    # sql management
    $sql16ssms = "C:\Program Files (x86)\Microsoft SQL Server\140\Tools\Binn\ManagementStudio\Ssms.exe"
    if( (Test-Path $sql16ssms) -eq $True) {
        cShortcut SQL16SSMS
        {
            Path      = "$desktopPath\SQL Server Manager.lnk"
            Target    = "$sql16ssms"
        }
    }

    # sharepoint ca
    $sp16centralAdministration = "C:\Program Files\Common Files\microsoft shared\Web Server Extensions\16\BIN\psconfigui.exe"
    if( (Test-Path $sp16centralAdministration) -eq $True) {
        cShortcut SP2016CA
        {
            Path      = "$desktopPath\SharePoint Central Administration.lnk"
            Target    = $sp16centralAdministration
            Arguments = "-cmd showcentraladmin"
        }
    }
}

$configuration = Get-Command SOE_Shortcuts
Start-UpliftDSCConfiguration $configuration $config -ExpectInDesiredState $True

exit 0