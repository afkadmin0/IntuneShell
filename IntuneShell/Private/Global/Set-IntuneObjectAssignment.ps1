function Set-IntuneObjectAssignment
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$AssignPath,

        # Name of the array property /assign expects: assignments, mobileAppAssignments or deviceHealthScriptAssignments.
        [Parameter(Mandatory)][string]$BodyProperty,

        # Display name used in warnings.
        [Parameter(Mandatory)][string]$Name,

        [AllowNull()][AllowEmptyCollection()][object[]]$Assignment,

        [System.Collections.IDictionary]$GroupMap
    )

    $prepared = New-Object System.Collections.Generic.List[object]

    foreach ($source in @($Assignment))
    {
        if (-not $source) { continue }

        $entry = ConvertTo-IntuneGraphObject -InputObject $source
        Remove-IntuneProperty -InputObject $entry -Name 'id', 'source', 'sourceId'

        $target = $entry['target']
        if ($target)
        {
            $groupId = $target['groupId']
            if ($groupId)
            {
                $groupName = if ($GroupMap) { $GroupMap[$groupId] } else { $null }
                $newGroupId = Resolve-IntuneBackupGroupId -Id $groupId -Name $groupName
                if (-not $newGroupId)
                {
                    $label = if ($groupName) { "'$groupName' ($groupId)" } else { $groupId }
                    Write-Warning "'$Name': group $label was not found in this tenant; that assignment was skipped."
                    continue
                }
                $target['groupId'] = $newGroupId
            }

            $filterId = $target['deviceAndAppManagementAssignmentFilterId']
            if ($filterId -and $filterId -ne '00000000-0000-0000-0000-000000000000')
            {
                if (-not $script:IntuneLookupCache) { $script:IntuneLookupCache = @{} }
                $context = Get-MgContext -ErrorAction SilentlyContinue
                $key = '{0}|filter|{1}' -f $context.TenantId, $filterId
                if (-not $script:IntuneLookupCache.ContainsKey($key))
                {
                    try
                    {
                        Invoke-IntuneGraphRequest -Path "deviceManagement/assignmentFilters/$filterId" | Out-Null
                        $script:IntuneLookupCache[$key] = $true
                    }
                    catch { $script:IntuneLookupCache[$key] = $false }
                }
                if (-not $script:IntuneLookupCache[$key])
                {
                    Write-Warning "'$Name': assignment filter $filterId does not exist in this tenant; the assignment was restored without a filter."
                    $target['deviceAndAppManagementAssignmentFilterId'] = $null
                    $target['deviceAndAppManagementAssignmentFilterType'] = 'none'
                }
            }
        }

        $prepared.Add($entry)
    }

    if ($prepared.Count -eq 0) { return }

    try
    {
        Invoke-IntuneGraphRequest -Method POST -Path $AssignPath -Body @{ $BodyProperty = $prepared.ToArray() } | Out-Null
    }
    catch
    {
        Write-Warning "'$Name' was created, but assigning it failed: $($_.Exception.Message)"
    }
}
