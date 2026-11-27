function Import-IntuneBackupItem
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [string[]]$Type
    )

    $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)

    if (Test-Path -LiteralPath $resolved -PathType Container)
    {
        $files = @(Get-ChildItem -LiteralPath $resolved -Filter '*.json' -File -Recurse | Sort-Object FullName)
    }
    elseif (Test-Path -LiteralPath $resolved -PathType Leaf)
    {
        if ($resolved -like '*.zip') { throw "'$Path' is a zip archive. Extract it first, then point the command at the extracted folder." }
        $files = @(Get-Item -LiteralPath $resolved)
    }
    else
    {
        throw "Path '$Path' was not found."
    }

    foreach ($file in $files)
    {
        try
        {
            $json = [System.IO.File]::ReadAllText($file.FullName) | ConvertFrom-Json
        }
        catch
        {
            Write-Warning "Skipping '$($file.FullName)': not valid JSON."
            continue
        }

        if (-not $json -or $json -isnot [System.Management.Automation.PSCustomObject] -or $json.PSObject.Properties.Name -notcontains '_backupMeta')
        {
            Write-Verbose "Skipping '$($file.FullName)': not an IntuneShell backup file."
            continue
        }

        $envelope = ConvertTo-IntuneGraphObject -InputObject $json
        $meta = $envelope['_backupMeta']

        if ($Type -and $meta['type'] -notin $Type) { continue }
        if (-not $envelope['policy'])
        {
            Write-Warning "Skipping '$($file.FullName)': no 'policy' section."
            continue
        }

        [pscustomobject]@{
            PSTypeName       = 'IntuneShell.BackupItem'
            File             = $file.FullName
            Type             = $meta['type']
            Category         = $meta['category']
            Name             = $meta['name']
            SourceId         = $meta['sourceId']
            Policy           = $envelope['policy']
            Assignments      = if ($envelope['assignments']) { $envelope['assignments'] } else { @() }
            AssignmentGroups = $envelope['_assignmentGroups']
            Envelope         = $envelope
        }
    }
}
