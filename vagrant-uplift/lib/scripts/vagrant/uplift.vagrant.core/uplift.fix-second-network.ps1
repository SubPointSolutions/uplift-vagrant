param ([String] $ip, [String] $dns)

# fail on errors and include uplift helpers
$ErrorActionPreference = "Stop"

Import-Module Uplift.Core

Write-UpliftMessage "Fixing up network settings..."
Write-UpliftEnv

# if (Test-Path C:\Users\vagrant\enable-winrm-after-customization.bat) {
#   Write-UpliftMessage "Nothing to do in vCloud."
#   exit 0
# }
# if (! (Test-Path 'C:\Program Files\VMware\VMware Tools')) {
#   Write-UpliftMessage "Nothing to do for other providers than VMware."
#   exit 0
# }

$subnet = $ip -replace "\.\d+$", ""

Write-UpliftMessage " - ip    : $ip"
Write-UpliftMessage " - subnet: $subnet"

$name = (Get-NetIPAddress -AddressFamily IPv4 `
   | Where-Object -FilterScript { ($_.IPAddress).StartsWith($subnet) } `
   ).InterfaceAlias

if (!$name) {
  $name = (Get-NetIPAddress -AddressFamily IPv4 `
     | Where-Object -FilterScript { ($_.IPAddress).StartsWith("169.254.") } `
     ).InterfaceAlias
}

if ($name) {
  Write-UpliftMessage "Set IP address to $ip of interface $name"
  & netsh.exe int ip set address "$name" static $ip 255.255.255.0 "$subnet.1"

  Confirm-UpliftExitCode $LASTEXITCODE "Cannot set IP address to $ip of interface $name" @(0,1)

  if ($dns) {
    Write-UpliftMessage "Set DNS server address to $dns of interface $name"
    & netsh.exe interface ipv4 add dnsserver "$name" address=$dns index=1

    Confirm-UpliftExitCode $LASTEXITCODE "Cannot set DNS server address to $dns of interface $name" @(0,1)
  }
} else {

  Write-UpliftMessage "Running ipconfig /all"
  ipconfig /all
  Confirm-UpliftExitCode $LASTEXITCODE "Cannot run ipconfig"

  $errorMessage = "Could not find a interface with subnet $subnet.xx"

  Write-UpliftMessage $errorMessage
  throw $errorMessage
}

exit 0