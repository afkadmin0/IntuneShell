function Get-IntuneGroupDisplayName
{
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Id)

    if (-not $script:IntuneLookupCache) { $script:IntuneLookupCache = @{} }
    $context = Get-MgContext -ErrorAction SilentlyContinue
    $key = '{0}|groupName|{1}' -f $context.TenantId, $Id
    if ($script:IntuneLookupCache.ContainsKey($key)) { return $script:IntuneLookupCache[$key] }

    $name = $null
    try
    {
        $group = Invoke-IntuneGraphRequest -Path ('https://graph.microsoft.com/v1.0/groups/{0}?$select=id,displayName' -f $Id)
        if ($group) { $name = [string]$group['displayName'] }
    }
    catch
    {
        Write-Verbose "Could not read group '$Id': $($_.Exception.Message)"
    }

    $script:IntuneLookupCache[$key] = $name
    $name
}
