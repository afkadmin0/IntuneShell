function Import-IntuneApplicationContent
{
    <#
    .SYNOPSIS
        Uploads a .intunewin to an existing Win32 app using the documented Graph upload flow and commits it.
    .DESCRIPTION
        1. create a content version and a content file entry   2. wait for the Azure Storage SAS URI
        3. stream the encrypted payload from the zip to Azure in blocks (renewing the SAS URI when needed)
        4. commit the block list   5. commit the file with the encryption info from Detection.xml
        6. set committedContentVersion on the app. Outputs the content version ID.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$AppId,
        [Parameter(Mandatory)][string]$PackagePath,
        [ValidateRange(1, 100)][int]$ChunkSizeMB = 6
    )

    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop

    $package = @(Read-IntuneWinPackage -Path $PackagePath) | Select-Object -First 1
    if (-not $package) { throw "'$PackagePath' is not a valid .intunewin package." }

    $appPath = "deviceAppManagement/mobileApps/$AppId/microsoft.graph.win32LobApp"

    $version = Invoke-IntuneGraphRequest -Method POST -Path "$appPath/contentVersions" -Body @{}
    $versionId = [string]$version['id']
    $versionPath = "$appPath/contentVersions/$versionId"

    $fileBody = [ordered]@{
        '@odata.type' = '#microsoft.graph.mobileAppContentFile'
        name          = $package.FileName
        size          = $package.UnencryptedSize
        sizeEncrypted = $package.EncryptedSize
        manifest      = $null
        isDependency  = $false
    }
    $file = Invoke-IntuneGraphRequest -Method POST -Path "$versionPath/files" -Body $fileBody
    $filePath = "$versionPath/files/$($file['id'])"

    $file = Wait-IntuneContentFileState -Path $filePath -State 'azureStorageUriRequestSuccess'
    $sasUri = [string]$file['azureStorageUri']
    $sasObtained = Get-Date

    $chunkSize = $ChunkSizeMB * 1MB
    $buffer = New-Object byte[] $chunkSize
    $blockIds = New-Object System.Collections.Generic.List[string]
    $uploaded = 0L

    $zip = [System.IO.Compression.ZipFile]::OpenRead($package.Path)
    $stream = $null
    $previousProgress = $ProgressPreference
    try
    {
        $stream = $zip.GetEntry($package.ContentEntryName).Open()

        while ($true)
        {
            $read = 0
            while ($read -lt $chunkSize)
            {
                $count = $stream.Read($buffer, $read, $chunkSize - $read)
                if ($count -le 0) { break }
                $read += $count
            }
            if ($read -eq 0) { break }

            if (((Get-Date) - $sasObtained).TotalMinutes -ge 5)
            {
                Invoke-IntuneGraphRequest -Method POST -Path "$filePath/renewUpload" -Body @{} | Out-Null
                $file = Wait-IntuneContentFileState -Path $filePath -State 'azureStorageUriRenewalSuccess'
                $sasUri = [string]$file['azureStorageUri']
                $sasObtained = Get-Date
            }

            $block = $buffer
            if ($read -lt $chunkSize)
            {
                $block = New-Object byte[] $read
                [Array]::Copy($buffer, $block, $read)
            }

            $blockId = [Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(('{0:D6}' -f $blockIds.Count)))
            $blockUri = '{0}&comp=block&blockid={1}' -f $sasUri, [Uri]::EscapeDataString($blockId)

            for ($attempt = 1; $attempt -le 3; $attempt++)
            {
                try
                {
                    $ProgressPreference = 'SilentlyContinue'
                    Invoke-WebRequest -Uri $blockUri -Method Put -Body $block -ContentType 'application/octet-stream' `
                        -Headers @{ 'x-ms-blob-type' = 'BlockBlob' } -UseBasicParsing -ErrorAction Stop | Out-Null
                    break
                }
                catch
                {
                    if ($attempt -eq 3) { throw "Uploading block $($blockIds.Count) failed: $($_.Exception.Message)" }
                    Start-Sleep -Seconds (2 * $attempt)
                }
                finally
                {
                    $ProgressPreference = $previousProgress
                }
            }

            $blockIds.Add($blockId)
            $uploaded += $read
            Write-Progress -Activity "Uploading $($package.FileName)" -Status ('{0:N0} of {1:N0} MB' -f ($uploaded / 1MB), ($package.EncryptedSize / 1MB)) `
                -PercentComplete ([math]::Min(100, [int](100 * $uploaded / [math]::Max(1, $package.EncryptedSize))))
        }
    }
    finally
    {
        $ProgressPreference = $previousProgress
        if ($stream) { $stream.Dispose() }
        $zip.Dispose()
        Write-Progress -Activity "Uploading $($package.FileName)" -Completed
    }

    $blockList = '<?xml version="1.0" encoding="utf-8"?><BlockList>' + (($blockIds | ForEach-Object { "<Latest>$_</Latest>" }) -join '') + '</BlockList>'
    try
    {
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri ('{0}&comp=blocklist' -f $sasUri) -Method Put -Body $blockList -ContentType 'application/xml' -UseBasicParsing -ErrorAction Stop | Out-Null
    }
    finally
    {
        $ProgressPreference = $previousProgress
    }

    $encryption = [ordered]@{ '@odata.type' = '#microsoft.graph.fileEncryptionInfo' }
    foreach ($key in $package.EncryptionInfo.Keys) { $encryption[$key] = $package.EncryptionInfo[$key] }

    Invoke-IntuneGraphRequest -Method POST -Path "$filePath/commit" -Body @{ fileEncryptionInfo = $encryption } | Out-Null
    Wait-IntuneContentFileState -Path $filePath -State 'commitFileSuccess' | Out-Null

    Invoke-IntuneGraphRequest -Method PATCH -Path "deviceAppManagement/mobileApps/$AppId" `
        -Body @{ '@odata.type' = '#microsoft.graph.win32LobApp'; committedContentVersion = $versionId } | Out-Null

    $versionId
}
