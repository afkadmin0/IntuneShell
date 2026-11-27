function Export-IntuneBackupItem
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Directory,
        [Parameter(Mandatory)][string]$Type,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Name,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Object,
        [object[]]$Assignment = @(),
        [System.Collections.IDictionary]$Extra,
        [string]$Category
    )

    $policy = ConvertTo-IntuneGraphObject -InputObject $Object
    $assignments = ConvertTo-IntuneGraphObject -InputObject $Assignment

    $groups = [ordered]@{}
    foreach ($entry in $assignments)
    {
        $target = $entry['target']
        $groupId = if ($target) { $target['groupId'] } else { $null }
        if ($groupId -and -not $groups.Contains($groupId))
        {
            $groups[$groupId] = Get-IntuneGroupDisplayName -Id $groupId
        }
    }

    $module = $MyInvocation.MyCommand.Module
    $context = Get-MgContext -ErrorAction SilentlyContinue
    $sourceId = [string]$policy['id']

    $envelope = [ordered]@{
        _backupMeta       = [ordered]@{
            type          = $Type
            category      = $Category
            name          = $Name
            sourceId      = $sourceId
            tenantId      = $context.TenantId
            backedUpAt    = (Get-Date).ToUniversalTime().ToString('o')
            moduleVersion = if ($module) { $module.Version.ToString() } else { 'unknown' }
        }
        _assignmentGroups = $groups
        assignments       = $assignments
    }

    if ($Extra)
    {
        foreach ($key in $Extra.Keys) { $envelope[[string]$key] = ConvertTo-IntuneGraphObject -InputObject $Extra[$key] }
    }
    $envelope['policy'] = $policy

    [void][System.IO.Directory]::CreateDirectory($Directory)

    $baseName = ConvertTo-IntuneSafeFileName -Name $Name
    $file = Join-Path $Directory "$baseName.json"
    if (Test-Path -LiteralPath $file)
    {
        $short = if ($sourceId.Length -ge 8) { $sourceId.Substring(0, 8) } else { [guid]::NewGuid().ToString('N').Substring(0, 8) }
        $file = Join-Path $Directory "$baseName ($short).json"
    }

    $json = ConvertTo-Json -InputObject $envelope -Depth 100
    [System.IO.File]::WriteAllText($file, $json, (New-Object System.Text.UTF8Encoding($false)))

    Get-Item -LiteralPath $file
}
