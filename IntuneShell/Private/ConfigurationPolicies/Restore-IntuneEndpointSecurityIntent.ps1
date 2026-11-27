function Restore-IntuneEndpointSecurityIntent
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Item,
        [Parameter(Mandatory)][string]$Name,
        [switch]$SkipAssignments
    )

    $policy = ConvertTo-IntuneGraphObject -InputObject $Item.Policy
    $templateId = [string]$policy['templateId']
    if (-not $templateId) { throw "The backup has no templateId, so the profile cannot be re-created from its template." }

    $settings = $policy['settings']
    Remove-IntuneProperty -InputObject $settings -Name '@odata.context' -Recurse

    $body = [ordered]@{
        displayName   = $Name
        settingsDelta = $settings
    }
    if ($policy['description']) { $body['description'] = $policy['description'] }
    if ($policy['roleScopeTagIds']) { $body['roleScopeTagIds'] = $policy['roleScopeTagIds'] }

    $created = Invoke-IntuneGraphRequest -Method POST -Path "deviceManagement/templates/$templateId/createInstance" -Body $body
    $newId = [string]$created['id']

    if (-not $SkipAssignments)
    {
        Set-IntuneObjectAssignment -AssignPath "deviceManagement/intents/$newId/assign" -BodyProperty 'assignments' `
            -Name $Name -Assignment $Item.Assignments -GroupMap $Item.AssignmentGroups
    }

    $newId
}
