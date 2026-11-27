function Restore-IntuneGroupPolicyConfiguration
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Item,
        [Parameter(Mandatory)][string]$Name,
        [switch]$SkipAssignments
    )

    $policy = ConvertTo-IntuneGraphObject -InputObject $Item.Policy

    $body = [ordered]@{ displayName = $Name }
    if ($policy['description']) { $body['description'] = $policy['description'] }
    if ($policy['roleScopeTagIds']) { $body['roleScopeTagIds'] = $policy['roleScopeTagIds'] }

    $created = Invoke-IntuneGraphRequest -Method POST -Path 'deviceManagement/groupPolicyConfigurations' -Body $body
    $newId = [string]$created['id']

    $definitionBase = 'https://graph.microsoft.com/beta/deviceManagement/groupPolicyDefinitions'
    $failures = New-Object System.Collections.Generic.List[string]
    $values = @($policy['definitionValues'])

    foreach ($value in $values)
    {
        if (-not $value) { continue }
        $definition = $value['definition']
        $label = if ($definition -and $definition['displayName']) { [string]$definition['displayName'] } else { 'unknown setting' }

        try
        {
            $definitionId = if ($definition) { [string]$definition['id'] } else { '' }
            if (-not $definitionId) { throw 'the backup has no definition ID' }

            # Settings from an imported ADMX file: find the matching definition (and presentations) in this tenant.
            $targetPresentations = $null
            if ($definition['definitionFile'])
            {
                $definitionId = [string](Resolve-IntuneAdmxDefinition -Definition $definition)['id']
                $targetPresentations = @(Invoke-IntuneGraphPaged -Beta -Path "deviceManagement/groupPolicyDefinitions/$definitionId/presentations")
            }
            $seenPresentations = @{}

            $entry = [ordered]@{
                enabled                 = [bool]$value['enabled']
                'definition@odata.bind' = "$definitionBase('$definitionId')"
            }
            if ($value['configurationType']) { $entry['configurationType'] = $value['configurationType'] }

            $presentationValues = New-Object System.Collections.Generic.List[object]
            foreach ($presentationValue in @($value['presentationValues']))
            {
                if (-not $presentationValue) { continue }
                $copy = ConvertTo-IntuneGraphObject -InputObject $presentationValue
                $presentationId = [string]$presentationValue['presentation']['id']

                if ($null -ne $targetPresentations)
                {
                    # New definition, new presentation IDs: match on label and type, the n-th time that pair occurs.
                    $presentationLabel = [string]$presentationValue['presentation']['label']
                    $presentationType = [string]$presentationValue['presentation']['type']
                    $pairKey = "$presentationLabel|$presentationType"
                    $occurrence = [int]$seenPresentations[$pairKey]
                    $seenPresentations[$pairKey] = $occurrence + 1

                    $sameLabel = @($targetPresentations | Where-Object {
                            [string]$_['label'] -ceq $presentationLabel -and (-not $presentationType -or [string]$_['@odata.type'] -eq $presentationType)
                        })
                    if ($sameLabel.Count -le $occurrence) { throw "presentation '$presentationLabel' was not found in the imported ADMX definition" }
                    $presentationId = [string]$sameLabel[$occurrence]['id']
                }

                Remove-IntuneProperty -InputObject $copy -Name 'id', 'createdDateTime', 'lastModifiedDateTime', 'presentation'
                $copy['presentation@odata.bind'] = "$definitionBase('$definitionId')/presentations('$presentationId')"
                $presentationValues.Add($copy)
            }
            $entry['presentationValues'] = $presentationValues.ToArray()

            Invoke-IntuneGraphRequest -Method POST -Path "deviceManagement/groupPolicyConfigurations/$newId/definitionValues" -Body $entry | Out-Null
        }
        catch
        {
            $failures.Add("$label ($($_.Exception.Message))")
        }
    }

    if ($failures.Count -gt 0)
    {
        Write-Warning "'$Name' was created but $($failures.Count) of $($values.Count) setting(s) could not be restored:`n  - $($failures -join "`n  - ")"
    }

    if (-not $SkipAssignments)
    {
        Set-IntuneObjectAssignment -AssignPath "deviceManagement/groupPolicyConfigurations/$newId/assign" -BodyProperty 'assignments' `
            -Name $Name -Assignment $Item.Assignments -GroupMap $Item.AssignmentGroups
    }

    $newId
}
