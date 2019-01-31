# fail on errors and include uplift helpers
$ErrorActionPreference = "Stop"

Import-Module Uplift.Core

# include shared helpers from uplift.vagrant.sharepoint handler
. "c:/windows/temp/uplift.vagrant.sharepoint/shared/sp.helpers.ps1"

Write-UpliftMessage "Running SharePoint pre-setup1 tuning..."
Write-UpliftEnv

# all this happens due to spoiled IIS installation after sysprep
# prereq/sp bin get IIS configured, but sysprep kills it
# we make some patches, and then uninstall IIS, and then run reboot
# once done, we bring Web-Server feature back and all works well

# patch IIS config
# https://forums.iis.net/t/1160389.aspx
Write-UpliftMessage "Fixing IIS config after sysprep"
Write-UpliftMessage " - details: https://forums.iis.net/t/1160389.aspx"

Repair-UpliftIISApplicationHostFile

# uninstall web server feature
Write-UpliftMessage "Uninstalling Web-Server feature"
Uninstall-WindowsFeature Web-Server | Out-Null

exit 0