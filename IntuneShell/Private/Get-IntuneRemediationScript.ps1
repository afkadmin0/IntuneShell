function Get-IntuneRemediationScript
{
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$GroupId)

    Invoke-IntuneGraphPaged -Path 'deviceManagement/deviceHealthScripts?$expand=assignments' |
    ForEach-Object {
        ConvertTo-IntunePolicyResult -Policy $_ -GroupId $GroupId -PolicyType 'Remediation' -Name $_['displayName'] -Category 'Remediation' -Platform 'windows10'
    }
}
