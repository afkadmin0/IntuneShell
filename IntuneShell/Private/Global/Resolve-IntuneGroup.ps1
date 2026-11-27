function Resolve-IntuneGroup
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Group
    )

    $guid = [guid]::Empty
    if ([guid]::TryParse($Group, [ref]$guid))
    {
        try { return Get-MgGroup -GroupId $guid.Guid -ErrorAction Stop }
        catch { throw "Group with ID '$Group' was not found: $_" }
    }

    $escaped = $Group.Replace("'", "''")
    $found = @(Get-MgGroup -Filter "displayName eq '$escaped'" -ErrorAction Stop)

    if ($found.Count -eq 0) { throw "No group found with display name '$Group'." }
    if ($found.Count -gt 1)
    {
        throw "Multiple groups named '$Group' found (IDs: $($found.Id -join ', ')). Specify the group ID instead."
    }
    $found[0]
}
