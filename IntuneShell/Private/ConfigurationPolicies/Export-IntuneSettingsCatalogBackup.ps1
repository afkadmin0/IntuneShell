function Export-IntuneSettingsCatalogBackup
{
    # Backs up configurationPolicies. Endpoint security policies (Antivirus, Disk encryption, Firewall, EDR, Attack surface
    # reduction, Account protection, App Control for Business, ...) are Settings Catalog objects with a template family; they
    # are filed under ConfigurationPolicies\EndpointSecurity\<Category>, everything else under ConfigurationPolicies\SettingsCatalog.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [ValidateSet('All', 'EndpointSecurity', 'SettingsCatalog')]
        [string]$Scope = 'All',
        [switch]$SkipAssignments
    )

    $base = Join-Path $Path 'ConfigurationPolicies'

    foreach ($policy in @(Invoke-IntuneGraphPaged -Beta -Path 'deviceManagement/configurationPolicies'))
    {
        $name = [string]$policy['name']
        $id = [string]$policy['id']

        $template = $policy['templateReference']
        $family = if ($template) { [string]$template['templateFamily'] } else { '' }
        $info = Get-IntuneConfigurationPolicyCategory -TemplateFamily $family
        if ($Scope -ne 'All' -and $info.Scope -ne $Scope) { continue }

        if ($info.Scope -eq 'EndpointSecurity') { $directory = Join-Path (Join-Path $base 'EndpointSecurity') $info.Category }
        elseif ($info.Category -eq 'SettingsCatalog') { $directory = Join-Path $base 'SettingsCatalog' }
        else { $directory = Join-Path (Join-Path $base 'SettingsCatalog') $info.Category }

        try
        {
            $object = ConvertTo-IntuneGraphObject -InputObject $policy

            $settings = @(Invoke-IntuneGraphPaged -Beta -Path "deviceManagement/configurationPolicies/$id/settings")
            $object['settings'] = ConvertTo-IntuneGraphObject -InputObject $settings

            $assignments = @()
            if (-not $SkipAssignments)
            {
                $assignments = @(Invoke-IntuneGraphPaged -Beta -Path "deviceManagement/configurationPolicies/$id/assignments")
            }

            $file = Export-IntuneBackupItem -Directory $directory -Type 'SettingsCatalog' -Category $info.Category -Name $name -Object $object -Assignment $assignments
            New-IntuneOperationResult -Type 'SettingsCatalog' -Category $info.Category -Name $name -SourceId $id -Status 'Exported' -Path $file.FullName
        }
        catch
        {
            Write-Warning "Failed to back up $($info.Category) policy '$name': $($_.Exception.Message)"
            New-IntuneOperationResult -Type 'SettingsCatalog' -Category $info.Category -Name $name -SourceId $id -Status 'Failed' -Message $_.Exception.Message
        }
    }
}
