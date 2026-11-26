function Get-IntuneSettingsCatalogPolicy
{
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$GroupId)

    Invoke-IntuneGraphPaged -Path 'deviceManagement/configurationPolicies?$expand=assignments' |
    ForEach-Object {
        $family = $_['templateReference']['templateFamily']
        $isEndpointSecurity = $family -like 'endpointSecurity*'
        $type = if ($isEndpointSecurity) { 'Endpoint Security' } else { 'Settings Catalog' }
        $category = if ($isEndpointSecurity)
        {
            switch ($family)
            {
                'endpointSecurityDiskEncryption' { 'Disk Encryption (BitLocker)' }
                'endpointSecurityAccountProtection' { 'Account Protection' }
                'endpointSecurityFirewall' { 'Firewall' }
                'endpointSecurityAntivirus' { 'Antivirus' }
                'endpointSecurityAttackSurfaceReduction' { 'Attack Surface Reduction' }
                'endpointSecurityEndpointDetectionAndResponse' { 'Endpoint Detection and Response' }
                'endpointSecurityApplicationControl' { 'App Control for Business' }
                default { $family }
            }
        }
        else { 'Settings Catalog' }

        ConvertTo-IntunePolicyResult -Policy $_ -GroupId $GroupId -PolicyType $type -Name $_['name'] -Category $category -Platform "$($_['platforms'])"
    }
}
