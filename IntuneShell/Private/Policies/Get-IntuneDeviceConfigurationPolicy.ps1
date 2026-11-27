function Get-IntuneDeviceConfigurationPolicy
{
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$GroupId)

    Get-MgDeviceManagementDeviceConfiguration -All -ExpandProperty 'assignments' -ErrorAction Stop |
    ForEach-Object {
        $odata = $_.AdditionalProperties['@odata.type'] -replace '^#microsoft\.graph\.', ''
        ConvertTo-IntunePolicyResult -Policy $_ -GroupId $GroupId -PolicyType 'Device Configuration' -Name $_.DisplayName -Category $odata -Platform $odata
    }
}
