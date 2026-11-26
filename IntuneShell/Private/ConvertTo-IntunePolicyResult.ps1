function ConvertTo-IntunePolicyResult
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        $Policy,
        [Parameter(Mandatory)][string]$GroupId,
        [Parameter(Mandatory)][string]$PolicyType,
        [string]$Name,
        [string]$Category,
        [string]$Platform
    )

    process
    {

        $isRaw = $Policy -is [System.Collections.IDictionary]
        $assignments = if ($isRaw) 
        { 
            $Policy['assignments'] 
        } 
        else 
        {
            $Policy.Assignments 
        }
        $policyId = if ($isRaw) 
        {
            $Policy['id']
        }
        else
        { 
            $Policy.Id 
        }

        foreach ($assignment in @($assignments))
        {
            $target = if ($isRaw) 
            {
                $assignment['target'] 
            }
            else { $assignment.Target }
            if (-not $target)
            {
                continue 
            }

            $props = if ($isRaw)
            {
                $target 
            }
            else
            { 
                $target.AdditionalProperties 
            }
            $odata = $props['@odata.type']
            $tGroup = $props['groupId']
            if (-not $tGroup -and -not $isRaw -and $target.PSObject.Properties['GroupId']) 
            { 
                $tGroup = $target.GroupId 
            }

            if ($tGroup -ne $GroupId)
            { 
                continue 
            }

            $mode = if ($odata -match 'exclusionGroupAssignmentTarget')
            { 
                'Exclude' 
            }
            else
            { 
                'Include' 
            }

            [pscustomobject]@{
                PolicyName     = $Name
                PolicyType     = $PolicyType
                Category       = $Category
                Platform       = $Platform
                AssignmentType = $mode
                PolicyId       = $policyId
                GroupId        = $GroupId
            }
        }
    }
}
