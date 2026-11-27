function Restore-IntuneDeviceConfigurationPolicy
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Item,
        [Parameter(Mandatory)][string]$Name,
        [switch]$SkipAssignments
    )

    $body = ConvertTo-IntuneGraphObject -InputObject $Item.Policy
    Remove-IntuneProperty -InputObject $body -Name 'id', 'createdDateTime', 'lastModifiedDateTime', 'version', 'supportsScopeTags',
    'deviceStatusOverview', 'userStatusOverview', 'deviceStatuses', 'userStatuses', 'groupAssignments', 'assignments'
    $body['displayName'] = $Name

    if (@($body['omaSettings'] | Where-Object { $_ -and $_['isEncrypted'] }).Count -gt 0)
    {
        Write-Warning "'$Name' contains encrypted OMA-URI values that are not in the backup; re-enter them in the restored profile."
    }

    $created = Invoke-IntuneGraphRequest -Method POST -Path 'deviceManagement/deviceConfigurations' -Body $body
    $newId = [string]$created['id']

    if (-not $SkipAssignments)
    {
        Set-IntuneObjectAssignment -AssignPath "deviceManagement/deviceConfigurations/$newId/assign" -BodyProperty 'assignments' `
            -Name $Name -Assignment $Item.Assignments -GroupMap $Item.AssignmentGroups
    }

    $newId
}
