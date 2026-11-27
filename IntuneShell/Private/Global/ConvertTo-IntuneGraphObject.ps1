function ConvertTo-IntuneGraphObject
{
    [CmdletBinding()]
    param([Parameter(Position = 0)][AllowNull()]$InputObject)

    if ($null -eq $InputObject) { return $null }
    if ($InputObject -is [string]) { return $InputObject }
    if ($InputObject -is [datetime]) { return $InputObject.ToString('o') }
    if ($InputObject -is [datetimeoffset]) { return $InputObject.ToString('o') }
    if ($InputObject -is [guid] -or $InputObject -is [enum]) { return $InputObject.ToString() }

    if ($InputObject -is [System.Collections.IDictionary])
    {
        $copy = [ordered]@{}
        foreach ($key in $InputObject.Keys)
        {
            $copy[[string]$key] = ConvertTo-IntuneGraphObject -InputObject $InputObject[$key]
        }
        return $copy
    }

    if ($InputObject -is [System.Collections.IEnumerable])
    {
        $items = @(foreach ($element in $InputObject) { ConvertTo-IntuneGraphObject -InputObject $element })
        return , $items
    }

    if ($InputObject -is [ValueType]) { return $InputObject }

    $copy = [ordered]@{}
    foreach ($property in $InputObject.PSObject.Properties)
    {
        $copy[$property.Name] = ConvertTo-IntuneGraphObject -InputObject $property.Value
    }
    $copy
}
