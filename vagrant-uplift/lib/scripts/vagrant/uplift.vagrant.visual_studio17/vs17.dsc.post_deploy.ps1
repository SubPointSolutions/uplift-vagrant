# fail on errors and include uplift helpers
$ErrorActionPreference = "Stop"

Import-Module Uplift.Core

Write-UpliftMessage "Running Visual Studio post-deploy script..."
Write-UpliftEnv

$productName = Get-UpliftEnvVariable "UPLF_VS_PRODUCT_NAME"

if ($productName.Contains("2015") -eq $true) {

    Write-UpliftMessage "Detected VS 2015 install. Ensuring additional plugins..."

    # ensuring "choco install -y webpicmd" is here
    # it should come with APP image but in case we failed or building on old image, install it in the fly
    Write-UpliftMessage "Ensuring webpicmd install..."

    choco install -y webpicmd --limit-output --acceptlicense --no-progress
    Confirm-UpliftExitCode $LASTEXITCODE "Cannot run choco install -y webpicmd"

    Write-UpliftMessage "Installing Office Development tools via webpicmd"
    # https://github.com/mszcool/devmachinesetup/blob/master/Install-WindowsMachine.ps1

    webpicmd /Install /Products:OfficeToolsForVS2015 /AcceptEula
    Confirm-UpliftExitCode $LASTEXITCODE "Cannot install Office Development tools"

} else {
    Write-UpliftMessage "No post deploy is needed..."
}

Write-UpliftMessage  "Visual Studio post-deploy script completed."

exit 0