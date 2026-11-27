function Restore-IntuneCompliancePolicyObject
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Item,
        [Parameter(Mandatory)][string]$Name,
        [switch]$SkipAssignments
    )

    $body = ConvertTo-IntuneGraphObject -InputObject $Item.Policy
    Remove-IntuneProperty -InputObject $body -Name 'id', 'createdDateTime', 'lastModifiedDateTime', 'version', 'assignments',
    'deviceStatusOverview', 'userStatusOverview', 'deviceStatuses', 'userStatuses', 'deviceSettingStateSummaries'
    $body['displayName'] = $Name

    if (@($body['scheduledActionsForRule']).Count -eq 0 -or -not $body['scheduledActionsForRule'])
    {
        $body['scheduledActionsForRule'] = @(
            [ordered]@{
                ruleName                      = 'PasswordRequired'
                scheduledActionConfigurations = @(
                    [ordered]@{
                        actionType                = 'block'
                        gracePeriodHours          = 0
                        notificationTemplateId    = ''
                        notificationMessageCCList = @()
                    }
                )
            }
        )
    }
    else
    {
        Remove-IntuneProperty -InputObject $body['scheduledActionsForRule'] -Name 'id' -Recurse
    }

    $created = Invoke-IntuneGraphRequest -Method POST -Path 'deviceManagement/deviceCompliancePolicies' -Body $body
    $newId = [string]$created['id']

    if (-not $SkipAssignments)
    {
        Set-IntuneObjectAssignment -AssignPath "deviceManagement/deviceCompliancePolicies/$newId/assign" -BodyProperty 'assignments' -Name $Name -Assignment $Item.Assignments -GroupMap $Item.AssignmentGroups
    }

    $newId
}
