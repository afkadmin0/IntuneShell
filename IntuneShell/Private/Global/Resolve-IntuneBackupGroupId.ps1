function Resolve-IntuneBackupGroupId
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Id,
        [string]$Name
    )

    if (-not $script:IntuneLookupCache) { $script:IntuneLookupCache = @{} }
    $context = Get-MgContext -ErrorAction SilentlyContinue
    $key = '{0}|groupId|{1}|{2}' -f $context.TenantId, $Id, $Name
    if ($script:IntuneLookupCache.ContainsKey($key)) { return $script:IntuneLookupCache[$key] }

    $resolved = $null
    try
    {
        $group = Invoke-IntuneGraphRequest -Path ('https://graph.microsoft.com/v1.0/groups/{0}?$select=id' -f $Id)
        if ($group -and $group['id']) { $resolved = [string]$group['id'] }
    }
    catch
    {
        Write-Verbose "Group '$Id' was not found by ID: $($_.Exception.Message)"
    }

    if (-not $resolved -and $Name)
    {
        $escaped = $Name.Replace("'", "''")
        $filter = [Uri]::EscapeDataString("displayName eq '$escaped'")
        $found = @(Invoke-IntuneGraphPaged -Path ('groups?$filter={0}&$select=id,displayName' -f $filter))

        if ($found.Count -eq 1) { $resolved = [string]$found[0]['id'] }
        elseif ($found.Count -gt 1) { Write-Warning "Multiple groups named '$Name' exist; the assignment for it cannot be mapped." }
    }

    $script:IntuneLookupCache[$key] = $resolved
    $resolved
}
