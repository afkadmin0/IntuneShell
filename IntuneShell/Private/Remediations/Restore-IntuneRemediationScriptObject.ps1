function Restore-IntuneRemediationScriptObject
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Item,
        [Parameter(Mandatory)][string]$Name,
        [switch]$SkipAssignments
    )

    $body = ConvertTo-IntuneGraphObject -InputObject $Item.Policy
    Remove-IntuneProperty -InputObject $body -Name 'id', 'createdDateTime', 'lastModifiedDateTime', 'version', 'isGlobalScript', 'highestAvailableVersion'
    $body['displayName'] = $Name

    $created = Invoke-IntuneGraphRequest -Method POST -Path 'deviceManagement/deviceHealthScripts' -Body $body
    $newId = [string]$created['id']

    if (-not $SkipAssignments)
    {
        Set-IntuneObjectAssignment -AssignPath "deviceManagement/deviceHealthScripts/$newId/assign" -BodyProperty 'deviceHealthScriptAssignments' `
            -Name $Name -Assignment $Item.Assignments -GroupMap $Item.AssignmentGroups
    }

    $newId
}
