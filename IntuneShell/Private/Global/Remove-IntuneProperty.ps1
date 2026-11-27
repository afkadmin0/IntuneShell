function Remove-IntuneProperty
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowNull()][AllowEmptyCollection()]$InputObject,
        [Parameter(Mandatory)][string[]]$Name,
        [switch]$Recurse
    )

    if ($InputObject -is [System.Collections.IDictionary])
    {
        foreach ($key in @($InputObject.Keys))
        {
            if ($key -in $Name -or $key -like '*@odata.context')
            {
                $InputObject.Remove($key)
                continue
            }
            if ($Recurse) { Remove-IntuneProperty -InputObject $InputObject[$key] -Name $Name -Recurse }
        }
    }
    elseif ($Recurse -and $InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string])
    {
        foreach ($element in $InputObject) { Remove-IntuneProperty -InputObject $element -Name $Name -Recurse }
    }
}
