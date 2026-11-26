function Get-IntuneRemediationByGroup
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

        Get-IntuneRemediationScript -GroupId $resolved.Id |
        Where-Object { $AssignmentType -eq 'All' -or $_.AssignmentType -eq $AssignmentType } |
        ForEach-Object {
            $_ | Add-Member -NotePropertyName GroupName -NotePropertyValue $resolved.DisplayName -PassThru
        } |
        Sort-Object AssignmentType, PolicyName
    }
}
