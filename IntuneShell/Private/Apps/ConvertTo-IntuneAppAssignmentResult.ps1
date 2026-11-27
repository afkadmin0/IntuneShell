function ConvertTo-IntuneAppAssignmentResult
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        $App,
        [Parameter(Mandatory)][hashtable]$GroupNames,
        [string]$GroupId
    )

    process
    {
        foreach ($assignment in @($App.Assignments))
        {
            if (-not $assignment -or -not $assignment.Target) { continue }

            $target = $assignment.Target
            $props = $target.AdditionalProperties
            $odata = "$($props['@odata.type'])" -replace '^#microsoft\.graph\.', ''
            $targetGroupId = $props['groupId']

            if ($GroupId -and $targetGroupId -ne $GroupId) { continue }

            switch -Regex ($odata)
            {
                'exclusionGroupAssignmentTarget' { $mode = 'Exclude'; $targetType = 'Group' }
                'allDevicesAssignmentTarget' { $mode = 'Include'; $targetType = 'All Devices' }
                'allLicensedUsersAssignmentTarget' { $mode = 'Include'; $targetType = 'All Users' }
                default { $mode = 'Include'; $targetType = 'Group' }
            }

            $groupName = $null
            if ($targetGroupId)
            {
                if (-not $GroupNames.ContainsKey($targetGroupId))
                {
                    try { $GroupNames[$targetGroupId] = (Get-MgGroup -GroupId $targetGroupId -Property DisplayName -ErrorAction Stop).DisplayName }
                    catch { $GroupNames[$targetGroupId] = $null }
                }
                $groupName = $GroupNames[$targetGroupId]
            }

            [pscustomobject]@{
                AppName        = $App.AppName
                AppType        = $App.AppType
                Version        = $App.Version
                Intent         = "$($assignment.Intent)"
                AssignmentType = $mode
                TargetType     = $targetType
                GroupName      = $groupName
                GroupId        = $targetGroupId
                FilterId       = $target.DeviceAndAppManagementAssignmentFilterId
                FilterType     = "$($target.DeviceAndAppManagementAssignmentFilterType)"
                AppId          = $App.AppId
            }
        }
    }
}
