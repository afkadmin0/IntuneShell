function Export-IntuneGroupPolicyBackup
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [switch]$SkipAssignments
    )

    $directory = Join-Path (Join-Path $Path 'ConfigurationPolicies') 'AdministrativeTemplates'

    $configurations = @(Invoke-IntuneGraphPaged -Beta -Path 'deviceManagement/groupPolicyConfigurations')

    # Settings that come from an imported ADMX file are tagged with that file, so a restore can re-link them
    # (re-importing an ADMX file creates new definition IDs).
    $customDefinitions = if ($configurations.Count -gt 0) { Get-IntuneUploadedAdmxDefinitionMap } else { @{} }

    foreach ($configuration in $configurations)
    {
        $name = [string]$configuration['displayName']
        $id = [string]$configuration['id']
        $base = "deviceManagement/groupPolicyConfigurations/$id"

        try
        {
            $object = ConvertTo-IntuneGraphObject -InputObject $configuration

            try { $values = @(Invoke-IntuneGraphPaged -Beta -Path ($base + '/definitionValues?$expand=definition')) }
            catch { $values = @(Invoke-IntuneGraphPaged -Beta -Path ($base + '/definitionValues')) }

            $definitionValues = New-Object System.Collections.Generic.List[object]
            foreach ($value in $values)
            {
                $valueId = [string]$value['id']
                $entry = ConvertTo-IntuneGraphObject -InputObject $value

                $definition = $value['definition']
                if (-not $definition) { $definition = Invoke-IntuneGraphRequest -Path "$base/definitionValues/$valueId/definition" }

                # Keep just enough of the ADMX definition to identify it; restore re-links it by ID.
                $slim = [ordered]@{}
                foreach ($key in 'id', 'displayName', 'classType', 'categoryPath', 'policyType', 'version')
                {
                    if ($definition.Contains($key)) { $slim[$key] = $definition[$key] }
                }
                if ($customDefinitions.Contains([string]$definition['id'])) { $slim['definitionFile'] = $customDefinitions[[string]$definition['id']] }
                $entry['definition'] = ConvertTo-IntuneGraphObject -InputObject $slim

                $presentationValues = @(Invoke-IntuneGraphPaged -Beta -Path ($base + "/definitionValues/$valueId/presentationValues" + '?$expand=presentation'))
                $slimValues = New-Object System.Collections.Generic.List[object]
                foreach ($presentationValue in $presentationValues)
                {
                    $copy = ConvertTo-IntuneGraphObject -InputObject $presentationValue
                    $presentation = $presentationValue['presentation']
                    if (-not $presentation)
                    {
                        $presentation = Invoke-IntuneGraphRequest -Path "$base/definitionValues/$valueId/presentationValues/$($presentationValue['id'])/presentation"
                    }
                    $copy['presentation'] = [ordered]@{ id = [string]$presentation['id']; label = [string]$presentation['label']; type = [string]$presentation['@odata.type'] }
                    $slimValues.Add($copy)
                }
                $entry['presentationValues'] = $slimValues.ToArray()

                $definitionValues.Add($entry)
            }
            $object['definitionValues'] = $definitionValues.ToArray()

            $assignments = @()
            if (-not $SkipAssignments)
            {
                $assignments = @(Invoke-IntuneGraphPaged -Beta -Path "$base/assignments")
            }

            $file = Export-IntuneBackupItem -Directory $directory -Type 'GroupPolicyConfiguration' -Name $name -Object $object -Assignment $assignments
            New-IntuneOperationResult -Type 'GroupPolicyConfiguration' -Name $name -SourceId $id -Status 'Exported' -Path $file.FullName
        }
        catch
        {
            Write-Warning "Failed to back up administrative template '$name': $($_.Exception.Message)"
            New-IntuneOperationResult -Type 'GroupPolicyConfiguration' -Name $name -SourceId $id -Status 'Failed' -Message $_.Exception.Message
        }
    }
}
