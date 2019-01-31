# fail on errors and include uplift helpers
$ErrorActionPreference = "Stop"

Import-Module Uplift.Core

Write-UpliftMessage "Running windows SOE config..."
Write-UpliftEnv

Write-UpliftMessage "Disabling Firewalls..."
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

Configuration Configure_WinSOE {

    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'

    Import-DscResource -ModuleName 'xActiveDirectory' -ModuleVersion '2.17.0.0'
    Import-DscResource -ModuleName 'xNetworking' -ModuleVersion '5.5.0.0'
    Import-DscResource -ModuleName 'ComputerManagementDsc' -ModuleVersion "6.1.0.0"
     
    Import-DSCResource -Module xSystemSecurity 

    Node localhost
    {
        LocalConfigurationManager
        {
            ConfigurationMode = 'ApplyOnly'
            RebootNodeIfNeeded = $false
            RefreshMode = "Push"
        }

        User Vagrant {
            UserName = "vagrant"
            Disabled = $false
            PasswordChangeRequired = $false
            PasswordNeverExpires = $true
        }

        TimeZone TimeZone
        {
            IsSingleInstance = 'Yes'
            TimeZone         = $Node.TimeZoneName
        }

        WindowsFeature ADDSInstall
        {
            Ensure = "Present"
            Name = "AD-Domain-Services"
        }

        WindowsFeature ADDSRSAT
        {
            Ensure = "Present"
            Name = "RSAT-ADDS-Tools"
        }

        WindowsFeature RSAT
        {
            Ensure = "Present"
            Name = "RSAT"
        }

        Registry WindowsUpdate_NoAutoUpdate
        {
            Ensure      = "Present"  
            Key         = "HKLM:SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
            ValueName   = "NoAutoUpdate"
            ValueData   = 1
            ValueType   = "DWord"
        }

        Registry WindowsUpdate_AUOptions
        {
            Ensure      = "Present"  
            Key         = "HKLM:SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
            ValueName   = "AUOptions"
            ValueData   = 2
            ValueType   = "DWord"
        }

        Registry Windows_RemoteConnections
        {
            Ensure      = "Present"  
            Key         = "HKLM:System\CurrentControlSet\Control\Terminal Server"
            ValueName   = "fDenyTSConnections"
            ValueData   = 0
            ValueType   = "DWord"
        }
       
        xIEEsc Disable_IEEsc
        {
            IsEnabled = $false
            UserRole  = "Administrators"
        }
    }
}


$config = @{
    AllNodes = @(
        @{
            NodeName = 'localhost'
            PSDscAllowPlainTextPassword = $true
            RetryCount = 10
            RetryIntervalSec = 30

            TimeZoneName = ( Get-UpliftEnvVariable "UPLF_SOE_TIME_ZONE_NAME" ""  'AUS Eastern Standard Time' )
        }
    )
}


$configuration = Get-Command Configure_WinSOE
Start-UpliftDSCConfiguration $configuration $config -ExpectInDesiredState $True

exit 0