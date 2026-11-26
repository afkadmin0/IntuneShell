function Get-IntunePolicyByGroup
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('GroupName', 'GroupId', 'Id')]
        [string]$Group,

        [ValidateSet('All', 'Include', 'Exclude')]
        [string]$AssignmentType = 'All'
    )

    begin
    {
        Confirm-GraphConnection
    }

    process
    {
        $resolved = Resolve-IntuneGroup -Group $Group
        Write-Verbose "Resolved group '$($resolved.DisplayName)' ($($resolved.Id))"

        $getters = 'Get-IntuneDeviceConfigurationPolicy',
        'Get-IntuneCompliancePolicy',
        'Get-IntuneSettingsCatalogPolicy',
        'Get-IntuneEndpointSecurityIntent',
        'Get-IntuneGroupPolicyConfiguration',
        'Get-IntuneRemediationScript'

        $results = foreach ($getter in $getters)
        {
            try { & $getter -GroupId $resolved.Id }
            catch { Write-Warning "$getter failed: $($_.Exception.Message)" }
        }

        $results | Where-Object { $AssignmentType -eq 'All' -or $_.AssignmentType -eq $AssignmentType } |
        ForEach-Object {
            $_ | Add-Member -NotePropertyName GroupName -NotePropertyValue $resolved.DisplayName -PassThru
        } |
        Sort-Object AssignmentType, PolicyType, PolicyName
    }
}
