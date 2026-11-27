function Get-IntuneConfigurationPolicyCategory
{
    # Maps a configurationPolicies templateFamily to the backup scope (EndpointSecurity or SettingsCatalog) and a category / folder name.
    [CmdletBinding()]
    param([AllowNull()][AllowEmptyString()][string]$TemplateFamily)

    $endpointSecurity = @{
        endpointSecurityAntivirus                    = 'Antivirus'
        endpointSecurityDiskEncryption               = 'DiskEncryption'
        endpointSecurityFirewall                     = 'Firewall'
        endpointSecurityEndpointDetectionAndResponse = 'EndpointDetectionAndResponse'
        endpointSecurityAttackSurfaceReduction       = 'AttackSurfaceReduction'
        endpointSecurityAccountProtection            = 'AccountProtection'
        endpointSecurityApplicationControl           = 'ApplicationControl'
        endpointSecurityEndpointPrivilegeManagement  = 'EndpointPrivilegeManagement'
        baseline                                     = 'SecurityBaselines'
    }

    if (-not $TemplateFamily -or $TemplateFamily -eq 'none')
    {
        return [pscustomobject]@{ Scope = 'SettingsCatalog'; Category = 'SettingsCatalog' }
    }

    if ($endpointSecurity.ContainsKey($TemplateFamily))
    {
        return [pscustomobject]@{ Scope = 'EndpointSecurity'; Category = $endpointSecurity[$TemplateFamily] }
    }

    # A family added to Intune later: still keep endpoint security families together, and never lose a policy.
    if ($TemplateFamily -like 'endpointSecurity*')
    {
        return [pscustomobject]@{ Scope = 'EndpointSecurity'; Category = $TemplateFamily.Substring('endpointSecurity'.Length) }
    }

    [pscustomobject]@{ Scope = 'SettingsCatalog'; Category = $TemplateFamily.Substring(0, 1).ToUpperInvariant() + $TemplateFamily.Substring(1) }
}
