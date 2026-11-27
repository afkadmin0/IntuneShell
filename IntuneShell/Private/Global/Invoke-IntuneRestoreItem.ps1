function Invoke-IntuneRestoreItem
{
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]$Item,
        [Parameter(Mandatory)][string]$CollectionPath,
        [Parameter(Mandatory)][string]$NameProperty,
        [Parameter(Mandatory)][scriptblock]$Create,
        [Parameter(Mandatory)][hashtable]$Cache,
        [string]$NamePrefix = '',
        [string]$NameSuffix = '',
        [ValidateSet('Skip', 'Rename', 'Overwrite')]
        [string]$ConflictAction = 'Skip',
        [switch]$SkipAssignments
    )

    $type = $Item.Type
    $targetName = "$NamePrefix$($Item.Name)$NameSuffix"
    $common = @{ Type = $type; Category = $Item.Category; SourceId = $Item.SourceId; Path = $Item.File }

    try
    {
        if (-not $Cache.ContainsKey($CollectionPath))
        {
            $Cache[$CollectionPath] = Get-IntuneExistingObjectMap -CollectionPath $CollectionPath -NameProperty $NameProperty
        }
        $map = $Cache[$CollectionPath]
        $status = 'Created'

        if ($map.ContainsKey($targetName))
        {
            $existingIds = @($map[$targetName])

            switch ($ConflictAction)
            {
                'Skip'
                {
                    return New-IntuneOperationResult @common -Name $targetName -Status 'Skipped' `
                        -Message "An object named '$targetName' already exists ($($existingIds -join ', '))."
                }
                'Rename'
                {
                    $targetName = "$targetName (restored $((Get-Date).ToString('yyyyMMdd-HHmmss')))"
                }
                'Overwrite'
                {
                    if (-not $PSCmdlet.ShouldProcess($targetName, "Delete existing $type ($($existingIds -join ', ')) before restoring"))
                    {
                        return New-IntuneOperationResult @common -Name $targetName -Status 'WhatIf' -Message 'Existing object would be deleted and restored.'
                    }
                    foreach ($existingId in $existingIds)
                    {
                        Invoke-IntuneGraphRequest -Method DELETE -Path "$CollectionPath/$existingId" | Out-Null
                    }
                    [void]$map.Remove($targetName)
                    $status = 'Overwritten'
                }
            }
        }

        if (-not $PSCmdlet.ShouldProcess($targetName, "Restore $type"))
        {
            return New-IntuneOperationResult @common -Name $targetName -Status 'WhatIf'
        }

        $output = @(& $Create $Item $targetName $SkipAssignments.IsPresent)
        $newId = [string]$output[-1]

        if (-not $map.ContainsKey($targetName)) { $map[$targetName] = New-Object System.Collections.Generic.List[string] }
        $map[$targetName].Add($newId)

        New-IntuneOperationResult @common -Name $targetName -Status $status -NewId $newId
    }
    catch
    {
        Write-Warning "Failed to restore $type '$targetName': $($_.Exception.Message)"
        New-IntuneOperationResult @common -Name $targetName -Status 'Failed' -Message $_.Exception.Message
    }
}
