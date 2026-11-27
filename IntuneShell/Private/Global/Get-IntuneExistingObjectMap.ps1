function Get-IntuneExistingObjectMap
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$CollectionPath,
        [Parameter(Mandatory)][string]$NameProperty
    )

    try
    {
        $objects = @(Invoke-IntuneGraphPaged -Beta -Path ($CollectionPath + '?$select=id,' + $NameProperty))
    }
    catch
    {
        Write-Verbose "'`$select' is not supported on '$CollectionPath'; listing the full objects instead."
        $objects = @(Invoke-IntuneGraphPaged -Beta -Path $CollectionPath)
    }

    $map = New-Object System.Collections.Hashtable ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($object in $objects)
    {
        $name = [string]$object[$NameProperty]
        if (-not $name) { continue }
        if (-not $map.ContainsKey($name)) { $map[$name] = New-Object System.Collections.Generic.List[string] }
        $map[$name].Add([string]$object['id'])
    }

    , $map
}
