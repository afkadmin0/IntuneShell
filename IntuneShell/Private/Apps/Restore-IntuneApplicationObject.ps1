function Restore-IntuneApplicationObject
{
    <#
    .SYNOPSIS
        Creates an app from a backup item, uploads its .intunewin when one is supplied (Win32 only) and assigns it. Outputs the new app ID.
    .DESCRIPTION
        Apps that need installer content but have none (no package, or a type other than Win32) are still
        created, but not assigned, because Intune refuses to assign an app that is not published.
        If the content upload fails, the half-created app is deleted again.
        App relationships (dependencies / supersedence) are not restored: they reference app IDs of the source.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Item,
        [Parameter(Mandatory)][string]$Name,
        $Package,
        [switch]$SkipAssignments
    )

    $body = ConvertTo-IntuneGraphObject -InputObject $Item.Policy
    Remove-IntuneProperty -InputObject $body -Name 'id', 'createdDateTime', 'lastModifiedDateTime', 'uploadState', 'publishingState', 'isAssigned',
        'dependentAppCount', 'supersedingAppCount', 'supersededAppCount', 'committedContentVersion', 'size', 'supportsScopeTags', 'assignments', 'relationships'
    $body['displayName'] = $Name

    # Newer Win32 apps carry their detection / requirement logic in 'rules'; sending the legacy lists as well is rejected.
    if ($body['rules'] -and @($body['rules']).Count -gt 0)
    {
        [void]$body.Remove('detectionRules')
        [void]$body.Remove('requirementRules')
    }

    $odataType = [string]$body['@odata.type']
    $isWin32 = $odataType -eq '#microsoft.graph.win32LobApp'
    $needsContent = $odataType -match 'LobApp$|MobileMSI$|AppX$|DmgApp$|PkgApp$'

    $created = Invoke-IntuneGraphRequest -Method POST -Path 'deviceAppManagement/mobileApps' -Body $body
    $newId = [string]$created['id']

    $hasContent = -not $needsContent
    if ($isWin32 -and $Package)
    {
        try
        {
            Import-IntuneApplicationContent -AppId $newId -PackagePath $Package.Path | Out-Null
            $hasContent = $true
        }
        catch
        {
            $uploadError = $_.Exception.Message
            try { Invoke-IntuneGraphRequest -Method DELETE -Path "deviceAppManagement/mobileApps/$newId" | Out-Null }
            catch { Write-Warning "The incomplete app '$Name' ($newId) could not be removed after the failed upload; delete it manually." }
            throw "Uploading '$($Package.FileName)' failed: $uploadError"
        }
    }
    elseif ($needsContent)
    {
        $why = if ($isWin32) { 'no .intunewin package was found' } else { 'installer content of this app type cannot be restored' }
        Write-Warning "'$Name' was created without content ($why). Upload the content in Intune before assigning it."
    }

    if (-not $SkipAssignments)
    {
        if ($hasContent)
        {
            foreach ($assignment in @($Item.Assignments)) { if ($assignment -and -not $assignment['@odata.type']) { $assignment['@odata.type'] = '#microsoft.graph.mobileAppAssignment' } }
            Set-IntuneObjectAssignment -AssignPath "deviceAppManagement/mobileApps/$newId/assign" -BodyProperty 'mobileAppAssignments' `
                -Name $Name -Assignment $Item.Assignments -GroupMap $Item.AssignmentGroups
        }
        elseif (@($Item.Assignments).Count -gt 0)
        {
            Write-Warning "'$Name' was not assigned because it has no content yet."
        }
    }

    if ($Item.Envelope['relationships'] -and @($Item.Envelope['relationships']).Count -gt 0)
    {
        Write-Warning "'$Name' had app dependencies/supersedence in the backup; those are not restored and must be re-created manually."
    }

    $newId
}
