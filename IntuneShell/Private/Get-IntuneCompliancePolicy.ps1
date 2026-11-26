function Get-IntuneCompliancePolicy
{
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$GroupId)

    Get-MgDeviceManagementDeviceCompliancePolicy -All -ExpandProperty 'assignments' -ErrorAction Stop |
    ForEach-Object {
        $odata = $_.AdditionalProperties['@odata.type'] -replace '^#microsoft\.graph\.', ''
        ConvertTo-IntunePolicyResult -Policy $_ -GroupId $GroupId -PolicyType 'Compliance' -Name $_.DisplayName -Category 'Compliance' -Platform $odata
    }
}
