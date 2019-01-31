function Confirm-ExitCode($code, $message)
{
    if ($code -eq 0) {
        Write-Build Green "Exit code is 0, continue..."
    } else {
        $errorMessage = "Exiting with non-zero code [$code] - $message"

        Write-Build Red  $errorMessage
        throw  $errorMessage
    }
}

function New-Folder {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSShouldProcess", "", Scope="Function")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "", Scope="Function")]
    param(
        $folder
    )

    if(!(Test-Path $folder))
    {
        New-Item -ItemType Directory -Force -Path $folder | Out-Null
    }
}


function Invoke-CleanFolder {
    param(
        $path
    )

    Remove-Item "$path/*" `
        -Force `
        -Recurse `
        -ErrorAction SilentlyContinue
}

function Edit-ValueInFile($path, $old, $new) {
    (Get-Content $path).replace( $old, $new ) `
        | Set-Content $path
}
