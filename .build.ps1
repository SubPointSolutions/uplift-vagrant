param(
    $buildVersion = $null,

    # QA params
    $QA_FIX = $null
)

$dirPath = $BuildRoot

$gemFolder = "vagrant-uplift"

. "$dirPath/.build-helpers.ps1"

$buildFolder = "build-gem"
$buildOutput = "build-output"

$srcFolder = "$dirPath/$gemFolder"

New-Folder   $buildFolder
New-Folder   $buildOutput

Enter-Build {
    Write-Build Green "Building gem..."

    Remove-Item  "$buildFolder/*" -Force -Recurse
    Remove-Item  "$buildOutput/*" -Force -Recurse
}

task PrepareGem {

    Invoke-CleanFolder $buildFolder

    Copy-Item "$srcFolder/*" "$buildFolder/" -Recurse -Force
    Remove-Item  "$buildFolder/*.gem" -Force
}

task VersionGem {
    $dateStamp = Get-Date -f "yyyyMMdd"
    $timeStamp = Get-Date -f "HHmmss"

    $stamp = "$dateStamp.$timeStamp"

    # repace 0 for 24 hours
    $stamp = $stamp.Replace(".000", ".")
    $stamp = $stamp.Replace(".00", ".")
    $stamp = $stamp.Replace(".0", ".")

    $script:Version = "0.1.$stamp"

    if ($null -ne $buildVersion ) {
        Write-Build Yello " [+] Using version from params: $buildVersion"
        $script:Version = $buildVersion
    }

    $specFile = "$buildFolder/lib/vagrant-uplift/version.rb"
    $gemFile = "$buildFolder/vagrant-uplift.gemspec"

    Write-Build Green " [~] Patching version: $($script:Version)"

    Write-Build Green " - file: $specFile"

    Edit-ValueInFile $specFile '0.1.0' $script:Version
    Edit-ValueInFile $gemFile  '0.1.0' $script:Version
}

task BuildGem {
    Write-Build Green "Building gems..."

    exec {
        Set-Location "$buildFolder"
        pwsh -c "gem build *.gemspec"
    }
}

task CopyGem {
    Write-Build Green "Copying to build folder..."
    exec {
        $gemFile = Get-ChildItem "$buildFolder" -Filter "*.gem" `
            | Select-Object -First 1

        Write-Build Green "Found gem: $gemFile"

        Copy-Item $gemFile.FullName "$buildOutput/latest.gem" -Force
        Copy-Item $gemFile.FullName "$buildOutput/" -Force
    }
}

task InstallGem {

    exec {
        Write-Build Green "Uninstalling gem..."
        vagrant plugin uninstall vagrant-uplift

        $path = "$buildOutput/latest.gem"

        Write-Build Green "Installing latest gem"
        Write-Build Green " - src: $path"

        vagrant plugin install "$path"
        Confirm-ExitCode $LASTEXITCODE  "vagrant plugin install $dirPath/build/latest.gem"
    }
}

task ShowVagrantPlugins {

    exec {
        vagrant plugin list
    }
}

task PublishGem {

    Write-Build Green "Publishing gems..."

    if($null -ne $env:APPVEYOR_REPO_BRANCH) {
        Write-Build Green " [~] Running under APPVEYOR branch: $($env:APPVEYOR_REPO_BRANCH)"

        if($env:APPVEYOR_REPO_BRANCH -ine "beta" -and $env:APPVEYOR_REPO_BRANCH -ine "master") {
            Write-Build Green " skipping publishing for branch: $($env:APPVEYOR_REPO_BRANCH)"
            return;
        }

        $apiKeyFile = " ~/.gem/credentials"

        $apiKeyEnvName = ("SPS_RUBYGEMS_API_KEY_" + $env:APPVEYOR_REPO_BRANCH)
        $apiKeyValue   = (get-item env:$apiKeyEnvName).Value;

        "---" >  $apiKeyFile
        ":rubygems_api_key: $apiKeyEnvName" >>  $apiKeyFile
    }

    exec {
        Set-Location "$buildOutput"
        pwsh -c "gem push latest.gem"
    }
}

# Synopsis: Runs PSScriptAnalyzer
task AnalyzeModule {
    exec {
        # https://github.com/PowerShell/PSScriptAnalyzer

        #$packerScriptsPath  = "packer/scripts"
        $folderPaths = Get-ChildItem . -Recurse `
            | ? { $_.PSIsContainer } `
            | Select-Object FullName -ExpandProperty FullName

        foreach ($folderPath in $folderPaths) {

            $filePaths = (Get-ChildItem -Path $folderPath -Filter *.ps1)

            foreach ($filePathContainer in $filePaths) {
                $filePath = $filePathContainer.FullName
                
                if ($filePath.Contains(".dsc.ps1") -eq $True -and $IsMacOS) {
                    Write-Build Yellow " - skipping DSC validation under macOS"

                    Write-Build Green " - file   : $filePath"
                    Write-Build Green " - QA_FIX : $QA_FIX"

                    Write-Build Green  " - https://github.com/PowerShell/PowerShell/issues/5707"
                    Write-Build Green  " - https://github.com/PowerShell/PowerShell/issues/5970"
                    Write-Build Green  " - https://github.com/PowerShell/MMI/issues/33"

                    continue;
                }

                if ($filePath.Contains(".Tests.ps1") -eq $True -and $IsMacOS) {
                    Write-Build Yellow " - skipping valiation for Pester test files"

                    Write-Build Green " - file   : $filePath"
                    Write-Build Green " - QA_FIX : $QA_FIX"

                    continue;
                }
              
                Write-Build Green " - file   : $filePath"
                Write-Build Green " - QA_FIX : $QA_FIX"

                if ($psFilesCount -eq 0) {
                    continue;
                }

                if ($null -eq $QA_FIX) {
                    pwsh -c Invoke-ScriptAnalyzer -Path $filePath -EnableExit -ReportSummary
                    Confirm-ExitCode $LASTEXITCODE "[~] failed!"
                }
                else {
                    pwsh -c Invoke-ScriptAnalyzer -Path $filePath -EnableExit -ReportSummary -Fix
                }
            }
        }
    }
}

# Synopsis: Executes Appveyor specific setup
task AppveyorPrepare {
    
}

task QA AnalyzeModule

task DefaultBuildGem PrepareGem,
    VersionGem,
    BuildGem,
    CopyGem

task DefaultBuild DefaultBuildGem,
    ShowVagrantPlugins,
    InstallGem,
    ShowVagrantPlugins

task . DefaultBuild

task Release QA, DefaultBuild, PublishGem

task Appveyor AppveyorPrepare,
    DefaultBuildGem,
    PublishGem