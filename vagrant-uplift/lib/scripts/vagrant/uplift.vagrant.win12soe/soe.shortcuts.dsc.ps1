# fail on errors and include uplift helpers
$ErrorActionPreference = "Stop"

Import-Module Uplift.Core

Write-UpliftMessage "Running DSC Configure_Shortcuts..."

Configuration SOE_Shortcuts
{
    Import-DscResource -ModuleName DSCR_Shortcut -ModuleVersion '1.3.7'

    $desktopPath = [Environment]::GetFolderPath("Desktop")

    cShortcut IE_Desktop
    {
        Path      = "$desktopPath\IE.lnk"
        Target    = "C:\Program Files\Internet Explorer\iexplore.exe"
    
    }

    cShortcut PowerShell_ISE_Desktop
    {
        Path      = "$desktopPath\PowerShellISE.lnk"
        Target    = "%windir%\system32\WindowsPowerShell\v1.0\PowerShell_ISE.exe"
        WorkingDirectory = '%HOMEDRIVE%%HOMEPATH%'
    
    }

    cShortcut PowerShell_6_Desktop
    {
        Path      = "$desktopPath\PowerShell6.lnk"
        Target    = "C:\Program Files\PowerShell\6\pwsh.exe"
        Arguments = "-WorkingDirectory ~"
    
    }
}

$configuration = Get-Command SOE_Shortcuts
Start-UpliftDSCConfiguration $configuration $config -ExpectInDesiredState $True

exit 0