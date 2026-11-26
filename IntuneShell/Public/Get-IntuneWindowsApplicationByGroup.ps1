function Get-IntuneWindowsApplicationByGroup
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('GroupName', 'GroupId', 'Id')]
        [string]$Group,

        [ValidateSet('All', 'Include', 'Exclude')]
        [string]$AssignmentType = 'All',

        [ValidateSet('Win32', 'MSI', 'Modern', 'Store', 'Microsoft365')]
        [string[]]$Type = @('Win32', 'MSI', 'Modern', 'Store', 'Microsoft365')
    )

    begin
    {
        Confirm-GraphConnection -Scopes 'DeviceManagementApps.Read.All', 'Group.Read.All'
    }

    process
    {
        $resolved = Resolve-IntuneGroup -Group $Group
        Write-Verbose "Resolved group '$($resolved.DisplayName)' ($($resolved.Id))"

        $groupNames = @{ $resolved.Id = $resolved.DisplayName }

        Get-IntuneWindowsApp -Type $Type -ExpandAssignments |
        ConvertTo-IntuneAppAssignmentResult -GroupNames $groupNames -GroupId $resolved.Id |
        Where-Object { $AssignmentType -eq 'All' -or $_.AssignmentType -eq $AssignmentType } |
        Sort-Object AssignmentType, AppName
    }
}
