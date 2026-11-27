function Get-IntuneGroupPolicyConfiguration
{
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$GroupId)

    Invoke-IntuneGraphPaged -Path 'deviceManagement/groupPolicyConfigurations?$expand=assignments' | ForEach-Object {
        ConvertTo-IntunePolicyResult -Policy $_ -GroupId $GroupId -PolicyType 'Administrative Templates' -Name $_['displayName'] -Category 'Administrative Templates' -Platform 'windows10'
    }
}
