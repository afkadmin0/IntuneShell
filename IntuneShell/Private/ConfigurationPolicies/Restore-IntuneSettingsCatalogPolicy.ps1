function Restore-IntuneSettingsCatalogPolicy
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Item,
        [Parameter(Mandatory)][string]$Name,
        [switch]$SkipAssignments
    )

    $body = ConvertTo-IntuneGraphObject -InputObject $Item.Policy
    Remove-IntuneProperty -InputObject $body -Name 'id', 'createdDateTime', 'lastModifiedDateTime', 'settingCount', 'creationSource', 'isAssigned', 'version'
    $body['name'] = $Name

    $created = Invoke-IntuneGraphRequest -Method POST -Path 'deviceManagement/configurationPolicies' -Body $body
    $newId = [string]$created['id']

    if (-not $SkipAssignments)
    {
        Set-IntuneObjectAssignment -AssignPath "deviceManagement/configurationPolicies/$newId/assign" -BodyProperty 'assignments' `
            -Name $Name -Assignment $Item.Assignments -GroupMap $Item.AssignmentGroups
    }

    $newId
}
