function Export-IntuneApplicationBackup
{
    <#
    .SYNOPSIS
        Backs up app definitions (all app types): properties, assignments, relationships and icon.
    .DESCRIPTION
        Intune does not let an admin download an uploaded .intunewin (Graph does not expose the encryption
        key), so the package itself cannot be exported from the service. When -PackagePath points at a
        folder holding the original .intunewin files, the one belonging to each Win32 app is copied into
        the app's backup folder so a restore can upload it again.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [string]$Name = '*',
        [string]$PackagePath,
        [switch]$SkipAssignments
    )

    $packages = @()
    if ($PackagePath) { $packages = @(Read-IntuneWinPackage -Path $PackagePath) }

    $uri = 'deviceAppManagement/mobileApps'
    if (-not $SkipAssignments) { $uri += '?$expand=assignments' }

    foreach ($app in @(Invoke-IntuneGraphPaged -Beta -Path $uri))
    {
        $appName = [string]$app['displayName']
        if ($appName -notlike $Name) { continue }

        $id = [string]$app['id']
        $odataType = [string]$app['@odata.type']

        try
        {
            $object = ConvertTo-IntuneGraphObject -InputObject $app

            $assignments = @()
            if ($object['assignments']) { $assignments = @($object['assignments']) }
            [void]$object.Remove('assignments')

            $relationships = @()
            try { $relationships = @(Invoke-IntuneGraphPaged -Beta -Path "deviceAppManagement/mobileApps/$id/relationships") }
            catch { Write-Verbose "Relationships of '$appName' could not be read: $($_.Exception.Message)" }

            $short = if ($id.Length -ge 8) { $id.Substring(0, 8) } else { $id }
            $directory = Join-Path (Join-Path $Path 'Apps') ('{0} ({1})' -f (ConvertTo-IntuneSafeFileName -Name $appName), $short)

            $file = Export-IntuneBackupItem -Directory $directory -Type 'Application' -Name $appName -Object $object `
                -Assignment $assignments -Extra @{ relationships = $relationships }

            $message = $null
            if ($odataType -eq '#microsoft.graph.win32LobApp')
            {
                $package = if ($packages.Count -gt 0) { Find-IntuneWinPackage -App $object -Package $packages } else { $null }
                if ($package)
                {
                    Copy-Item -LiteralPath $package.Path -Destination (Join-Path $directory $package.FileName) -Force
                    $message = "Package '$($package.FileName)' copied."
                }
                elseif ($PackagePath) { $message = "Definition only: no matching .intunewin ('$($object['fileName'])') was found in the package path." }
                else { $message = 'Definition only: the .intunewin cannot be downloaded from Intune. Use -ApplicationPackagePath to include your own copy.' }
            }
            elseif ($odataType -match 'LobApp$|MobileMSI$|AppX$|DmgApp$|PkgApp$')
            {
                $message = 'Definition only: the installer content of this app type is not backed up.'
            }

            New-IntuneOperationResult -Type 'Application' -Name $appName -SourceId $id -Status 'Exported' -Message $message -Path $file.FullName
        }
        catch
        {
            Write-Warning "Failed to back up app '$appName': $($_.Exception.Message)"
            New-IntuneOperationResult -Type 'Application' -Name $appName -SourceId $id -Status 'Failed' -Message $_.Exception.Message
        }
    }
}
