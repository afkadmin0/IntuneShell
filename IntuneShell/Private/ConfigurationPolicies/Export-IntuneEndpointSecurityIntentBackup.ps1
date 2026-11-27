function Export-IntuneEndpointSecurityIntentBackup
{
    # Legacy template-based endpoint security profiles ("intents"), filed per area next to their modern Settings Catalog counterparts.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [switch]$SkipAssignments
    )

    $base = Join-Path (Join-Path $Path 'ConfigurationPolicies') 'EndpointSecurity'

    $intents = @(Invoke-IntuneGraphPaged -Beta -Path 'deviceManagement/intents')
    $categories = if ($intents.Count -gt 0) { Get-IntuneIntentCategoryMap } else { @{} }

    foreach ($intent in $intents)
    {
        $name = [string]$intent['displayName']
        $id = [string]$intent['id']
        $category = $categories[[string]$intent['templateId']]
        if (-not $category) { $category = 'Other' }

        try
        {
            $object = ConvertTo-IntuneGraphObject -InputObject $intent

            $settings = @(Invoke-IntuneGraphPaged -Beta -Path "deviceManagement/intents/$id/settings")
            $object['settings'] = ConvertTo-IntuneGraphObject -InputObject $settings

            $assignments = @()
            if (-not $SkipAssignments)
            {
                $assignments = @(Invoke-IntuneGraphPaged -Beta -Path "deviceManagement/intents/$id/assignments")
            }

            $file = Export-IntuneBackupItem -Directory (Join-Path $base $category) -Type 'EndpointSecurityIntent' -Category $category -Name $name -Object $object -Assignment $assignments
            New-IntuneOperationResult -Type 'EndpointSecurityIntent' -Category $category -Name $name -SourceId $id -Status 'Exported' -Path $file.FullName
        }
        catch
        {
            Write-Warning "Failed to back up endpoint security profile '$name': $($_.Exception.Message)"
            New-IntuneOperationResult -Type 'EndpointSecurityIntent' -Category $category -Name $name -SourceId $id -Status 'Failed' -Message $_.Exception.Message
        }
    }
}
