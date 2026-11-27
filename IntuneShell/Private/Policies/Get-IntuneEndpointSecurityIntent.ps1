function Get-IntuneEndpointSecurityIntent
{
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$GroupId)

    $templates = @{}
    Invoke-IntuneGraphPaged -Path 'deviceManagement/templates' |
    ForEach-Object { $templates[$_['id']] = $_['displayName'] }

    Invoke-IntuneGraphPaged -Path 'deviceManagement/intents?$expand=assignments' |
    ForEach-Object {
        $category = if ($templates.ContainsKey($_['templateId'])) { $templates[$_['templateId']] } else { $_['templateId'] }
        ConvertTo-IntunePolicyResult -Policy $_ -GroupId $GroupId -PolicyType 'Endpoint Security (Template)' -Name $_['displayName'] -Category $category -Platform ''
    }
}
