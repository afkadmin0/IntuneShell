function Read-IntuneWinPackage
{
    <#
    .SYNOPSIS
        Reads the metadata (Detection.xml) of one .intunewin file, or of every .intunewin in a folder (recursively).
    .DESCRIPTION
        A .intunewin is a zip with Metadata/Detection.xml (setup file, sizes and the encryption info) and the
        encrypted payload under Contents/. The payload is not extracted; it is streamed straight from the zip
        when it is uploaded.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop

    $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    if (Test-Path -LiteralPath $resolved -PathType Container)
    {
        $files = @(Get-ChildItem -LiteralPath $resolved -Filter '*.intunewin' -File -Recurse)
    }
    elseif (Test-Path -LiteralPath $resolved -PathType Leaf)
    {
        $files = @(Get-Item -LiteralPath $resolved)
    }
    else
    {
        throw "Package path '$Path' was not found."
    }

    foreach ($file in $files)
    {
        $zip = $null
        try
        {
            $zip = [System.IO.Compression.ZipFile]::OpenRead($file.FullName)

            $detectionEntry = $zip.Entries | Where-Object { $_.FullName.Replace('\', '/') -like '*/Metadata/Detection.xml' } | Select-Object -First 1
            if (-not $detectionEntry) { throw 'Metadata/Detection.xml was not found; this does not look like a .intunewin file.' }

            $reader = New-Object System.IO.StreamReader($detectionEntry.Open())
            try { $xml = [xml]$reader.ReadToEnd() } finally { $reader.Dispose() }

            $info = $xml.ApplicationInfo
            $encryption = $info.EncryptionInfo
            if (-not $info -or -not $encryption) { throw 'Detection.xml has no encryption info.' }

            $contents = @($zip.Entries | Where-Object { $_.FullName.Replace('\', '/') -like '*/Contents/*' -and $_.Length -gt 0 })
            $content = $contents | Where-Object { $_.Name -eq [string]$info.FileName } | Select-Object -First 1
            if (-not $content) { $content = $contents | Select-Object -First 1 }
            if (-not $content) { throw 'The package has no Contents/ payload.' }

            [pscustomobject]@{
                PSTypeName       = 'IntuneShell.IntuneWinPackage'
                Path             = $file.FullName
                FileName         = $file.Name
                SetupFile        = [string]$info.SetupFile
                UnencryptedSize  = [int64]$info.UnencryptedContentSize
                EncryptedSize    = [int64]$content.Length
                ContentEntryName = $content.FullName
                EncryptionInfo   = [ordered]@{
                    encryptionKey        = [string]$encryption.EncryptionKey
                    macKey               = [string]$encryption.MacKey
                    initializationVector = [string]$encryption.InitializationVector
                    mac                  = [string]$encryption.Mac
                    profileIdentifier    = [string]$encryption.ProfileIdentifier
                    fileDigest           = [string]$encryption.FileDigest
                    fileDigestAlgorithm  = [string]$encryption.FileDigestAlgorithm
                }
            }
        }
        catch
        {
            Write-Warning "Skipping '$($file.FullName)': $($_.Exception.Message)"
        }
        finally
        {
            if ($zip) { $zip.Dispose() }
        }
    }
}
