# fail on errors and include uplift helpers
$ErrorActionPreference = "Stop"

function Get-SharePoint2016Edittion($productId) {
    
    # https://social.technet.microsoft.com/wiki/contents/articles/40031.sharepoint-2016-detect-the-installed-edition-with-powershell.aspx

    switch ($productId)
    {
        "5DB351B8-C548-4C3C-BFD1-82308C9A519B" { return "SharePoint 2016 Trail Edition" }
        "4F593424-7178-467A-B612-D02D85C56940" { return "SharePoint 2016 Standard Edition" }
        "716578D2-2029-4FF2-8053-637391A7E683" { return "SharePoint 2016 Enterprise Edition" }
        "435d4d60-f4cf-421d-abc8-129e4b57f7a"  { return "n/a" }
    }

    return $productId
}

Write-Host "Loading SharePoint snapin"
ASNP Microsoft.SharePoint.Powershell

Write-Host "Fetching local farm..."
$farm = Get-SPFarm

Write-Host "Farm version (config db version):"
$farm.BuildVersion

Write-Host "Farm products:"
$farm.Products | % { Write-Host ($_.Guid + " (" + (Get-SharePoint2016Edittion $_.Guid) + ")") }

Write-Host "SharePoint-related products:"
Get-SPProduct -Local `
    | Sort-Object -Property ProductName `
    |  % { Write-Host $_.ProductName }

exit 0
